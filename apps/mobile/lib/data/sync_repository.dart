part of 'workout_repository.dart';

/// All synchronization installations use the same SQLite connection and short
/// transactions as local commands. No transaction spans a network request.
extension SynchronizationRepository on WorkoutRepository {
  Future<Json> syncMetadata() => db.transaction(() async {
    await _guard();
    final row = await db
        .customSelect('SELECT * FROM sync_metadata')
        .getSingle();
    final identity = await db
        .customSelect('SELECT * FROM local_identity')
        .getSingle();
    return {
      ...row.data,
      'cursor': identity.readNullable<String>('cursor'),
      'installation_id': identity.read<String>('installation_id'),
    };
  });

  Future<List<String>> pendingRoots() => db.transaction(() async {
    await _guard();
    return [
      for (final row
          in await db
              .customSelect(
                "SELECT session_id FROM outbox WHERE state='pending' GROUP BY session_id ORDER BY min(rowid)",
              )
              .get())
        row.read<String>('session_id'),
    ];
  });

  Future<int> attentionCount() => db.transaction(() async {
    await _guard();
    // Historical evidence itself is durable attention. Deriving this from the
    // committed receipt avoids a second flag or a later upload attempt, while
    // leaving the pending command, working branch and acknowledgement untouched.
    return (await db.customSelect(
      '''SELECT (SELECT count(*) FROM sessions WHERE has_conflict=1) +
                (SELECT count(DISTINCT o.session_id) FROM outbox o
                 WHERE o.state='pending' AND
                   (o.last_error IN ('timeline_reconciliation_required','recovery_metadata_unverified')
                    OR EXISTS(SELECT 1 FROM historical_receipts h
                              WHERE h.mutation_id=o.mutation_id))) AS count''',
    ).getSingle()).read<int>('count');
  });

  Future<bool> remoteDisabled() async {
    final identity = await db
        .customSelect('SELECT owner_id FROM local_identity')
        .getSingle();
    if (identity.read<String>('owner_id') != ownerId) {
      throw const ContractViolation('wrong_owner');
    }
    return (await db
                .customSelect('SELECT remote_disabled FROM sync_metadata')
                .getSingle())
            .read<int>('remote_disabled') ==
        1;
  }

  Future<void> markAttempts(List<String> mutations) => db.transaction(() async {
    await _guard();
    for (final id in mutations) {
      final row = await db
          .customSelect(
            'SELECT frozen_body FROM outbox WHERE mutation_id=?',
            variables: [Variable(id)],
          )
          .getSingle();
      final frozen = row.read<String>('frozen_body');
      final operation = jsonDecode(frozen) as Json;
      validateTransport(
        operation['schema_version'] == 2 ? 'OperationV2' : 'Operation',
        operation,
      );
      validateEnvelope(_withoutRecoveryFields(operation));
      await db.customStatement(
        'UPDATE outbox SET attempt_count=attempt_count+1,request_digest=? WHERE mutation_id=?',
        [sha256.convert(utf8.encode(frozen)).toString(), id],
      );
    }
  });

  Future<void> recordSyncFailure(String code, {DateTime? nextAttempt}) =>
      db.transaction(() async {
        await _guard();
        await db.customStatement(
          'UPDATE sync_metadata SET last_error=?,retry_attempt=retry_attempt+1,next_attempt=?',
          [code, nextAttempt?.toUtc().toIso8601String()],
        );
      });

  Future<void> clearSyncFailure() => db.transaction(() async {
    await _guard();
    await db.customStatement(
      'UPDATE sync_metadata SET last_error=NULL,retry_attempt=0,next_attempt=NULL',
    );
  });

  Future<void> markOversized(String id) => db.transaction(() async {
    await _guard();
    await db.customStatement(
      "UPDATE outbox SET state='rejected',last_error='command_capacity' WHERE mutation_id=?",
      [id],
    );
    await db.customStatement(
      'UPDATE sessions SET has_conflict=1 WHERE id=(SELECT session_id FROM outbox WHERE mutation_id=?)',
      [id],
    );
  });

  void _ownerContext(Json response) {
    if (response['schema_version'] != 1) {
      throw const ContractViolation('upgrade_required');
    }
    if (response['owner_id'] != ownerId) {
      throw const ContractViolation('wrong_owner');
    }
  }

  Future<void> installAcknowledgements(
    PushResponseDto response,
    List<String> sent,
  ) => db.transaction(() async {
    await _guard();
    _ownerContext(response.json);
    final metadata = await syncMetadata();
    if (metadata['generation'] != null &&
        metadata['generation'] != response.generation) {
      throw const ContractViolation('bootstrap_required');
    }
    if (response.erasureEpoch != metadata['erasure_epoch']) {
      throw const ContractViolation('bootstrap_required');
    }
    final results = response.results.cast<Json>();
    if (results.length != sent.length ||
        results.map((r) => r['mutation_id']).toSet().length != sent.length ||
        results.any((r) => !sent.contains(r['mutation_id']))) {
      throw const ContractViolation();
    }
    for (final result in results) {
      await _installAck(result);
    }
  });

  Future<void> _installAck(Json result) async {
    await _requireLegacySync();
    final row = await db
        .customSelect(
          'SELECT * FROM outbox WHERE mutation_id=?',
          variables: [Variable(result['mutation_id'] as String)],
        )
        .getSingleOrNull();
    if (row == null ||
        row.read<String>('session_id') != result['aggregate_id']) {
      throw const ContractViolation();
    }
    final id = row.read<String>('session_id');
    final retired = await db
        .customSelect(
          'SELECT id FROM retired_ids WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (retired != null) {
      return; // A historical receipt is not evidence of a live entity.
    }
    final frozen = row.readNullable<String>('frozen_body');
    if (frozen == null) throw const ContractViolation();
    final op = jsonDecode(frozen) as Json;
    if (['accepted', 'duplicate'].contains(result['status'])) {
      final revision = result['accepted_revision'] as int;
      if (revision != op['expected_revision'] + 1) {
        throw const ContractViolation();
      }
      if (row.readNullable<int>('accepted_revision') != null &&
          row.read<int>('accepted_revision') != revision) {
        throw const ContractViolation();
      }
      await db.customStatement(
        "UPDATE outbox SET state='acknowledged',accepted_revision=?,last_error=NULL WHERE mutation_id=?",
        [revision, result['mutation_id']],
      );
      final shadow = await db
          .customSelect(
            'SELECT * FROM shadows WHERE session_id=?',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (shadow == null || shadow.read<int>('revision') < revision) {
        if ((shadow?.read<int>('revision') ?? 0) != op['expected_revision']) {
          throw const ContractViolation('bootstrap_required');
        }
        final previous = shadow?.readNullable<String>('projection');
        final projection = applyRemoteOperation(
          previous == null ? null : jsonDecode(previous) as Json,
          op,
          transportSchemas,
          revision: revision,
        );
        await db.customStatement(
          'INSERT INTO shadows(session_id,revision,projection) VALUES(?,?,?) ON CONFLICT(session_id) DO UPDATE SET revision=excluded.revision,projection=excluded.projection',
          [id, revision, projection == null ? null : canonicalJson(projection)],
        );
      }
      final pending = await db
          .customSelect(
            "SELECT mutation_id FROM outbox WHERE session_id=? AND state!='acknowledged' LIMIT 1",
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (pending == null) {
        final latest = await db
            .customSelect(
              'SELECT revision FROM shadows WHERE session_id=?',
              variables: [Variable(id)],
            )
            .getSingle();
        if (latest.read<int>('revision') == revision) {
          final working = await _read(id);
          if (working != null) {
            working['revision'] = revision;
            await _write(working, working['local_seq'] as int);
          }
          await db.customStatement(
            'UPDATE sessions SET branch_base=NULL,has_conflict=0 WHERE id=?',
            [id],
          );
        }
      }
    } else {
      if (row.read<String>('state') == 'acknowledged') {
        throw const ContractViolation();
      }
      if (result['status'] == 'conflict' &&
          (result['expected_revision'] != op['expected_revision'] ||
              result['current_revision'] == op['expected_revision'])) {
        throw const ContractViolation();
      }
      final code = result['error']['code'] as String;
      if (code == 'retired_id') {
        await _eraseRemote(id, []);
        return;
      }
      await db.customStatement(
        'UPDATE outbox SET state=?,last_error=? WHERE mutation_id=?',
        [result['status'], code, result['mutation_id']],
      );
      await db.customStatement(
        'UPDATE sessions SET has_conflict=1 WHERE id=?',
        [id],
      );
    }
  }

  Future<void> _eraseRemote(String id, List<String> wireIds) async {
    final ids = <String>{id, ...wireIds};
    final working = await _read(id);
    if (working != null) {
      for (final exercise in working['exercises'] as List) {
        ids.add(exercise['session_exercise_id'] as String);
        ids.addAll(
          (exercise['sets'] as List).map((s) => s['set_id'] as String),
        );
      }
    }
    for (final value in ids) {
      await db.customStatement(
        'INSERT OR IGNORE INTO retired_ids(id) VALUES(?)',
        [value],
      );
    }
    // Privacy erasure overrides correction and pending-branch retention.
    await db.customStatement(
      "UPDATE outbox SET state='rejected',last_error='retired_id',request_digest=coalesce(request_digest,''),operation='{}',frozen_body=NULL WHERE session_id=?",
      [id],
    );
    await db.customStatement('DELETE FROM sessions WHERE id=?', [id]);
    await db.customStatement('DELETE FROM shadows WHERE session_id=?', [id]);
    await db.customStatement('DELETE FROM bootstrap_pages');
    await db.customStatement('DELETE FROM bootstrap_stage');
  }

  Future<void> disableRemoteAccount() => db.transaction(() async {
    // Owner may already be locally locked. Never transfer or unlock this database.
    final identity = await db
        .customSelect('SELECT owner_id FROM local_identity')
        .getSingle();
    if (identity.read<String>('owner_id') != ownerId) {
      throw const ContractViolation('wrong_owner');
    }
    for (final table in [
      'routine_starts',
      'routines', // Cascades to all immutable template payloads.
      'sessions',
      'shadows',
      'outbox',
      'bootstrap_pages',
      'bootstrap_stage',
      'historical_receipts',
    ]) {
      await db.customStatement('DELETE FROM $table');
    }
    await db.customStatement(
      "UPDATE sync_metadata SET remote_disabled=1,last_error='account_inactive',next_attempt=NULL",
    );
    await db.customStatement('UPDATE local_identity SET locked=1,cursor=NULL');
    await db.customStatement('UPDATE recovery_state SET current_context=NULL');
  });

  Future<void> installPull(
    PullResponseDto page, {
    required String? requestedCursor,
  }) => db.transaction(() async {
    await _guard();
    await _requireLegacySync();
    _ownerContext(page.json);
    final meta = await syncMetadata();
    if (meta['cursor'] != requestedCursor) {
      throw const ContractViolation('stale_page');
    }
    if (meta['generation'] != null && meta['generation'] != page.generation) {
      throw const ContractViolation('bootstrap_required');
    }
    if (meta['erasure_epoch'] != page.erasureEpoch) {
      throw const ContractViolation('bootstrap_required');
    }
    var position = meta['position'] as int;
    for (final change in page.changes.cast<Json>()) {
      final next = change['position'] as int;
      if (next <= position) throw const ContractViolation('non_monotonic_page');
      if (next != position + 1) {
        throw const ContractViolation('bootstrap_required');
      }
      if (change['redacted'] == true) {
        await _eraseRemote(
          change['aggregate_id'] as String,
          (change['retired_ids'] as List).cast<String>(),
        );
      } else {
        final op = change['operation'] as Json;
        validateTransport('Operation', op);
        final id = op['aggregate_id'] as String;
        final revision = change['revision'] as int;
        if (revision != op['expected_revision'] + 1) {
          throw const ContractViolation();
        }
        final retired = await db
            .customSelect(
              'SELECT id FROM retired_ids WHERE id=?',
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        if (retired == null) {
          final own = await db
              .customSelect(
                'SELECT frozen_body FROM outbox WHERE mutation_id=?',
                variables: [Variable(op['mutation_id'] as String)],
              )
              .getSingleOrNull();
          if (own != null) {
            if (own.readNullable<String>('frozen_body') != canonicalJson(op)) {
              throw const ContractViolation('mutation_digest_mismatch');
            }
            await _installAck({
              'mutation_id': op['mutation_id'],
              'aggregate_id': id,
              'status': 'accepted',
              'accepted_revision': revision,
            });
          }
          final shadow = await db
              .customSelect(
                'SELECT * FROM shadows WHERE session_id=?',
                variables: [Variable(id)],
              )
              .getSingleOrNull();
          if (shadow == null || shadow.read<int>('revision') < revision) {
            if ((shadow?.read<int>('revision') ?? 0) !=
                op['expected_revision']) {
              throw const ContractViolation('bootstrap_required');
            }
            final before = shadow?.readNullable<String>('projection');
            final projection = applyRemoteOperation(
              before == null ? null : jsonDecode(before) as Json,
              op,
              transportSchemas,
              revision: revision,
            );
            if (projection == null) {
              await _eraseRemote(id, []);
            } else {
              await _installConnectedRemote(projection, external: own == null);
            }
          }
        }
      }
      position = next;
    }
    if (page.nextPosition != position || page.hasMore && page.changes.isEmpty) {
      throw const ContractViolation();
    }
    await db.customStatement('UPDATE local_identity SET cursor=?', [
      page.nextCursor,
    ]);
    await db.customStatement(
      'UPDATE sync_metadata SET generation=?,position=?,erasure_epoch=?',
      [page.generation, position, page.erasureEpoch],
    );
  });

  Future<void> _installConnectedRemote(
    Json projection, {
    required bool external,
    bool generationChanged = false,
  }) async {
    validateTransport('RootProjection', projection);
    projection = contractDefaults(
      projection,
      transportSchemas['RootProjection'] as Json,
      transportSchemas,
    ) as Json;
    final unique = <String>{projection['aggregate_id'] as String};
    final completionSequences = <int>{};
    if ((projection['status'] == 'active') !=
        (projection['ended_at'] == null)) {
      throw const ContractViolation('invalid_remote_state');
    }
    for (final exercise in projection['exercises'] as List) {
      if (!unique.add(exercise['session_exercise_id'] as String)) {
        throw const ContractViolation();
      }
      for (final item in exercise['sets'] as List) {
        if (!unique.add(item['set_id'] as String)) {
          throw const ContractViolation();
        }
        final plannedLoad = item['planned']['load'];
        if (plannedLoad != null) {
          try {
            validateLoad(
              plannedLoad as Json,
              exercise['loading_basis'] as String,
            );
          } on WorkoutValidation {
            throw const ContractViolation('invalid_remote_state');
          }
        }
        if (item['observation'] != null) {
          if (!completionSequences.add(
            item['observation']['completion_seq'] as int,
          )) {
            throw const ContractViolation('invalid_remote_state');
          }
          if (item['observation']['set_id'] != item['set_id'] ||
              item['observation']['session_exercise_id'] !=
                  exercise['session_exercise_id']) {
            throw const ContractViolation('observation_identity');
          }
          try {
            validateObservation(item['observation'] as Json, exercise as Json);
          } on WorkoutValidation {
            throw const ContractViolation('invalid_remote_state');
          }
        }
      }
    }
    // Finishing requires attempted work, but a later historical correction may
    // mark every recorded set skipped without reopening the completed workout.
    // The contract above validates correction reasons. Their presence permits
    // corrected history structurally; it does not prove the earlier transition.
    if (projection['status'] == 'completed' &&
        !allSets(projection).any((s) {
          final observation = s['observation'] as Json?;
          return observation != null &&
              (observation['execution_status'] != 'skipped' ||
                  observation['correction_reason'] != null);
        })) {
      throw const ContractViolation('invalid_remote_state');
    }
    final id = projection['aggregate_id'] as String;
    final stamps = [
      projection['started_at'],
      projection['ended_at'],
      for (final item in allSets(projection))
        if (item['observation'] != null) ...[
          item['observation']['occurred_at'],
          item['observation']['recorded_at'],
        ],
    ];
    for (final stamp in stamps) {
      if (stamp != null && !isUtcInstant(stamp)) {
        throw const ContractViolation('invalid_timestamp');
      }
    }
    if (await db
            .customSelect(
              'SELECT id FROM retired_ids WHERE id=?',
              variables: [Variable(id)],
            )
            .getSingleOrNull() !=
        null) {
      throw const ContractViolation('erased_payload');
    }
    for (final value in unique) {
      if (await db
              .customSelect(
                'SELECT id FROM retired_ids WHERE id=?',
                variables: [Variable(value)],
              )
              .getSingleOrNull() !=
          null) {
        throw const ContractViolation('erased_payload');
      }
      final existing = await db
          .customSelect(
            'SELECT session_id AS root FROM exercises WHERE id=? UNION ALL SELECT e.session_id AS root FROM workout_sets s JOIN exercises e ON s.exercise_id=e.id WHERE s.id=? UNION ALL SELECT id AS root FROM sessions WHERE id=?',
            variables: [Variable(value), Variable(value), Variable(value)],
          )
          .get();
      if (existing.any((row) => row.read<String>('root') != id)) {
        throw const ContractViolation('identity_collision');
      }
    }
    final shadow = await db
        .customSelect(
          'SELECT revision,projection FROM shadows WHERE session_id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    for (final exercise in projection['exercises'] as List) {
      final exerciseId = exercise['session_exercise_id'] as String;
      if (await db
              .customSelect(
                'SELECT id FROM workout_sets WHERE id=?',
                variables: [Variable(exerciseId)],
              )
              .getSingleOrNull() !=
          null) {
        throw const ContractViolation('identity_collision');
      }
      for (final item in exercise['sets'] as List) {
        final setId = item['set_id'] as String;
        final row = await db
            .customSelect(
              'SELECT exercise_id FROM workout_sets WHERE id=?',
              variables: [Variable(setId)],
            )
            .getSingleOrNull();
        if (row != null && row.read<String>('exercise_id') != exerciseId) {
          throw const ContractViolation('identity_collision');
        }
        if (await db
                .customSelect(
                  'SELECT id FROM exercises WHERE id=?',
                  variables: [Variable(setId)],
                )
                .getSingleOrNull() !=
            null) {
          throw const ContractViolation('identity_collision');
        }
      }
    }
    // Revisions order roots within one server timeline. A restored generation
    // can reuse or rewind them; retain divergent local work for explicit review.
    final restoredBranch =
        generationChanged &&
        shadow != null &&
        _recoveryProjection(shadow.readNullable<String>('projection')) !=
            _recoveryProjection(canonicalJson(projection));
    if (shadow != null &&
        shadow.read<int>('revision') >= projection['revision'] &&
        !restoredBranch) {
      return;
    }
    await db.customStatement(
      'INSERT INTO shadows(session_id,revision,projection) VALUES(?,?,?) ON CONFLICT(session_id) DO UPDATE SET revision=excluded.revision,projection=excluded.projection',
      [id, projection['revision'], canonicalJson(projection)],
    );
    final pending = await db
        .customSelect(
          "SELECT mutation_id FROM outbox WHERE session_id=? AND state!='acknowledged' LIMIT 1",
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    final drafts = await db
        .customSelect(
          'SELECT d.set_id FROM drafts d JOIN workout_sets s ON d.set_id=s.id JOIN exercises e ON s.exercise_id=e.id WHERE e.session_id=? LIMIT 1',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    final previous = await _read(id);
    if (pending != null ||
        drafts != null ||
        previous?['conflict'] == true ||
        restoredBranch) {
      if (external) {
        await db.customStatement(
          'UPDATE sessions SET has_conflict=1,branch_base=coalesce(branch_base,?) WHERE id=?',
          [shadow?.read<int>('revision') ?? 0, id],
        );
        if (generationChanged) await _pauseRestoredBranch(id);
      }
    } else {
      await _write(projection, (previous?['local_seq'] as int? ?? 0) + 1);
    }
  }

  Future<void> _pauseRestoredBranch(String id) async {
    // This private session marker is excluded from rendered/domain projections.
    // It remains until explicit branch resolution; historical receipts stay intact.
    await db.customStatement(
      "UPDATE sessions SET metadata=json_set(metadata,'\$._restore_conflict',1) WHERE id=?",
      [id],
    );
    await db.customStatement(
      "UPDATE outbox SET state='conflict',last_error='restore_conflict' WHERE session_id=? AND state='pending'",
      [id],
    );
  }

  String _recoveryProjection(String? encoded) {
    if (encoded == null) return canonicalJson(null);
    final normalized = contractDefaults(
      jsonDecode(encoded),
      transportSchemas['RootProjection'] as Json,
      transportSchemas,
    ) as Json;
    for (final item in allSets(normalized)) {
      final observation = item['observation'] as Json?;
      // This optional nullable field has no exported schema default.
      observation?.putIfAbsent('correction_reason', () => null);
    }
    return canonicalJson(normalized);
  }

  Future<BootstrapManifestDto?> stagedBootstrap() => db.transaction(() async {
    await _guard();
    final row = await db
        .customSelect('SELECT manifest FROM bootstrap_stage')
        .getSingleOrNull();
    return row == null
        ? null
        : BootstrapManifestDto.fromJson(
            jsonDecode(row.read<String>('manifest')) as Json,
          );
  });

  Future<void> discardBootstrap() => db.transaction(() async {
    await _guard();
    await db.customStatement('DELETE FROM bootstrap_pages');
    await db.customStatement('DELETE FROM bootstrap_stage');
  });

  Future<void> stageBootstrap(BootstrapManifestDto manifest) =>
      db.transaction(() async {
        await _guard();
        await _requireLegacySync();
        _ownerContext(manifest.json);
        final meta = await syncMetadata();
        if (manifest.installationId != meta['installation_id'] ||
            manifest.checksums.length != manifest.pageCount ||
            manifest.erasureEpoch < (meta['erasure_epoch'] as int)) {
          throw const ContractViolation();
        }
        await discardBootstrap();
        await db.customStatement(
          'INSERT INTO bootstrap_stage(singleton,manifest) VALUES(1,?)',
          [canonicalJson(manifest.json)],
        );
      });

  Future<Set<int>> stagedPageIndices() async => {
    for (final row
        in await db
            .customSelect('SELECT page_index FROM bootstrap_pages')
            .get())
      row.read<int>('page_index'),
  };

  Future<void> stageBootstrapPage(int index, SnapshotPageDto page) =>
      db.transaction(() async {
        await _guard();
        await _requireLegacySync();
        final manifest = await stagedBootstrap();
        if (manifest == null || index < 0 || index >= manifest.pageCount) {
          throw const ContractViolation();
        }
        final bytes = utf8.encode(canonicalJson(page.json));
        if (bytes.length > transportPageLimit ||
            sha256.convert(bytes).toString() != manifest.checksums[index]) {
          throw const ContractViolation('snapshot_checksum');
        }
        final otherBytes =
            (await db
                    .customSelect(
                      'SELECT coalesce(sum(length(CAST(body AS BLOB))),0) AS size FROM bootstrap_pages WHERE page_index != ?',
                      variables: [Variable(index)],
                    )
                    .getSingle())
                .read<int>('size');
        if (otherBytes + bytes.length > transportSnapshotLimit) {
          throw const ContractViolation('snapshot_capacity');
        }
        await db.customStatement(
          'INSERT INTO bootstrap_pages(page_index,body) VALUES(?,?) ON CONFLICT(page_index) DO UPDATE SET body=excluded.body',
          [index, canonicalJson(page.json)],
        );
      });

  Future<void> activateBootstrap(
    MeResponseDto current,
  ) => db.transaction(() async {
    await _guard();
    await _requireLegacySync();
    _ownerContext(current.json);
    final manifest = await stagedBootstrap();
    final meta = await syncMetadata();
    final generationChanged =
        meta['generation'] != null &&
        meta['generation'] != manifest?.generation;
    if (manifest == null ||
        manifest.position > current.position ||
        manifest.position < current.minimumPosition ||
        current.minimumPosition > current.position ||
        manifest.generation != current.generation ||
        manifest.erasureEpoch != current.erasureEpoch ||
        manifest.erasureEpoch < (meta['erasure_epoch'] as int) ||
        !isUtcInstant(manifest.expiresAt) ||
        !DateTime.parse(manifest.expiresAt).isAfter(now().toUtc())) {
      throw const ContractViolation('snapshot_expired');
    }
    final rows = await db
        .customSelect('SELECT * FROM bootstrap_pages ORDER BY page_index')
        .get();
    if (rows.length != manifest.pageCount) {
      throw const ContractViolation('snapshot_incomplete');
    }
    final roots = <Json>[];
    final retired = <String>{};
    var size = 0;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].read<int>('page_index') != i) throw const ContractViolation();
      final page = SnapshotPageDto.fromJson(
        jsonDecode(rows[i].read<String>('body')) as Json,
      );
      final bytes = utf8.encode(canonicalJson(page.json));
      if (sha256.convert(bytes).toString() != manifest.checksums[i]) {
        throw const ContractViolation('snapshot_checksum');
      }
      size += bytes.length;
      roots.addAll(page.roots.cast<Json>());
      retired.addAll(page.retiredIds.cast<String>());
    }
    if (size > transportSnapshotLimit) {
      throw const ContractViolation('snapshot_capacity');
    }
    final seen = <String>{};
    final allIds = <String>{};
    for (final root in roots) {
      if (!seen.add(root['aggregate_id'] as String)) {
        throw const ContractViolation();
      }
      final identifiers = [
        root['aggregate_id'] as String,
        for (final exercise in root['exercises'] as List)
          exercise['session_exercise_id'] as String,
        for (final item in allSets(root)) item['set_id'] as String,
      ];
      for (final id in identifiers) {
        if (!allIds.add(id) || retired.contains(id)) {
          throw const ContractViolation('identity_collision');
        }
      }
    }
    // Find a local root even when the server retires one of its child identities.
    for (final row in await db.customSelect('SELECT id FROM sessions').get()) {
      final id = row.read<String>('id');
      final state = (await _read(id))!;
      final ids = {
        id,
        for (final e in state['exercises'] as List)
          e['session_exercise_id'] as String,
        for (final s in allSets(state)) s['set_id'] as String,
      };
      if (ids.any(retired.contains)) await _eraseRemote(id, retired.toList());
    }
    for (final id in retired) {
      await db.customStatement(
        'INSERT OR IGNORE INTO retired_ids(id) VALUES(?)',
        [id],
      );
    }
    for (final root in roots) {
      await _installConnectedRemote(
        root,
        external: true,
        generationChanged: generationChanged,
      );
    }
    for (final row
        in await db.customSelect('SELECT session_id FROM shadows').get()) {
      final id = row.read<String>('session_id');
      if (seen.contains(id)) continue;
      final pending = await db
          .customSelect(
            "SELECT mutation_id FROM outbox WHERE session_id=? AND state!='acknowledged' AND last_error IS NOT 'retired_id' LIMIT 1",
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (pending != null || generationChanged) {
        await db.customStatement(
          'UPDATE sessions SET has_conflict=1,branch_base=coalesce(branch_base,(SELECT revision FROM shadows WHERE session_id=?)) WHERE id=?',
          [id, id],
        );
        if (generationChanged) await _pauseRestoredBranch(id);
      } else {
        await db.customStatement('DELETE FROM sessions WHERE id=?', [id]);
      }
      await db.customStatement('DELETE FROM shadows WHERE session_id=?', [id]);
    }
    await db.customStatement('UPDATE local_identity SET cursor=?', [
      manifest.cursor,
    ]);
    await db.customStatement(
      'UPDATE sync_metadata SET generation=?,position=?,erasure_epoch=?',
      [manifest.generation, manifest.position, manifest.erasureEpoch],
    );
    await discardBootstrap();
  });
}
