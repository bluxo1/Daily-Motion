part of 'workout_repository.dart';

/// Model-level command/lineage invariants are not expressible in the generated
/// structural schema. Match the server without modifying frozen request bytes.
void _validateRoutineOperation(Json operation) {
  validateTransport('RoutineOperation', operation);
  final creation = operation['expected_revision'] == 0;
  if (creation != (operation['command'] == 'create_routine') ||
      creation != (operation['payload']['predecessor_template_id'] == null)) {
    throw const ContractViolation('invalid_routine_history');
  }
}

/// Accepted immutable templates are separate from the editor's local CAS
/// versions. A shadow may advance while the current local plan stays pending.
Json _validatedRoutineRoot(Json value) {
  validateTransport('RoutineProjection', value);
  final root = copyJson(value);
  final templates = (root['templates'] as List).cast<Json>();
  if (root['template_offset'] != 0 || templates.length != root['revision']) {
    throw const ContractViolation('invalid_routine_history');
  }
  final ids = <String>{root['aggregate_id'] as String};
  String? predecessor;
  for (final (index, template) in templates.indexed) {
    if (template['revision'] != index + 1 ||
        template['predecessor_template_id'] != predecessor ||
        !ids.add(template['template_id'] as String)) {
      throw const ContractViolation('invalid_routine_history');
    }
    try {
      RoutinePlan.fromJson(template['prescription'] as Json);
    } on WorkoutValidation {
      throw const ContractViolation('invalid_remote_state');
    }
    predecessor = template['template_id'] as String;
  }
  if (root['current_template_id'] != predecessor) {
    throw const ContractViolation('invalid_routine_history');
  }
  return root;
}

Json _routineAfter(Json? previous, Json operation, int revision) {
  _validateRoutineOperation(operation);
  final expected = operation['expected_revision'] as int;
  final payload = operation['payload'] as Json;
  if ((previous?['revision'] ?? 0) != expected ||
      revision != expected + 1 ||
      (previous != null &&
          previous['aggregate_id'] != operation['aggregate_id']) ||
      payload['predecessor_template_id'] != previous?['current_template_id']) {
    throw const ContractViolation('invalid_routine_history');
  }
  return _validatedRoutineRoot({
    'aggregate_type': 'routine',
    'aggregate_id': operation['aggregate_id'],
    'revision': revision,
    'current_template_id': payload['template_id'],
    'template_offset': 0,
    'templates': [
      ...?previous?['templates'] as List?,
      {
        'template_id': payload['template_id'],
        'predecessor_template_id': payload['predecessor_template_id'],
        'revision': revision,
        'prescription': payload['prescription'],
      },
    ],
  });
}

/// Reassemble an entire checksummed snapshot before installing any root/cursor.
List<Json> _assembleRoutineFragments(List<Json> fragments) {
  final roots = <String, Json>{};
  final templateIds = <String>{};
  for (final fragment in fragments) {
    validateTransport('RoutineProjection', fragment);
    final id = fragment['aggregate_id'] as String;
    var root = roots[id];
    if (root == null) {
      root = copyJson(fragment)..['templates'] = <Json>[];
      roots[id] = root;
    }
    final collected = root['templates'] as List;
    if (fragment['template_offset'] != collected.length ||
        fragment['revision'] != root['revision'] ||
        fragment['current_template_id'] != root['current_template_id']) {
      throw const ContractViolation('invalid_routine_history');
    }
    for (final template in (fragment['templates'] as List).cast<Json>()) {
      if (!templateIds.add(template['template_id'] as String)) {
        throw const ContractViolation('identity_collision');
      }
      collected.add(copyJson(template));
    }
  }
  return [for (final root in roots.values) _validatedRoutineRoot(root)];
}

extension RoutineSynchronization on WorkoutRepository {
  Future<void> _guardRoutineIdentity(
    String value,
    String routine, {
    required bool root,
  }) async {
    final collision = await db
        .customSelect(
          'SELECT 1 AS used FROM sessions WHERE id=? '
          'UNION ALL SELECT 1 FROM exercises WHERE id=? '
          'UNION ALL SELECT 1 FROM workout_sets WHERE id=? '
          'UNION ALL SELECT 1 FROM retired_ids WHERE id=? '
          'UNION ALL SELECT 1 FROM workout_templates WHERE owner_id=? AND id=? ${root ? '' : 'AND routine_id!=?'} '
          'UNION ALL SELECT 1 FROM routine_cloud_templates WHERE owner_id=? AND template_id=? ${root ? '' : 'AND routine_id!=?'} '
          '${root ? '' : 'UNION ALL SELECT 1 FROM routines WHERE owner_id=? AND id=? '}LIMIT 1',
          variables: [
            Variable(value),
            Variable(value),
            Variable(value),
            Variable(value),
            Variable(ownerId),
            Variable(value),
            if (!root) Variable(routine),
            Variable(ownerId),
            Variable(value),
            if (!root) Variable(routine),
            if (!root) ...[Variable(ownerId), Variable(value)],
          ],
        )
        .getSingleOrNull();
    if (collision != null) throw const ContractViolation('identity_collision');
  }

  Future<void> _guardWorkoutRoutineIdentities(Iterable<String> values) async {
    for (final value in values) {
      final collision = await db
          .customSelect(
            'SELECT 1 AS used FROM routines WHERE owner_id=? AND id=? '
            'UNION ALL SELECT 1 FROM workout_templates WHERE owner_id=? AND id=? '
            'UNION ALL SELECT 1 FROM routine_cloud_templates WHERE owner_id=? AND template_id=? LIMIT 1',
            variables: [
              Variable(ownerId),
              Variable(value),
              Variable(ownerId),
              Variable(value),
              Variable(ownerId),
              Variable(value),
            ],
          )
          .getSingleOrNull();
      if (collision != null) {
        throw const ContractViolation('identity_collision');
      }
    }
  }

  Future<QueryRow?> _routineSyncRow(String id) => db
      .customSelect(
        'SELECT * FROM routine_sync_state WHERE owner_id=? AND routine_id=?',
        variables: [Variable(ownerId), Variable(id)],
      )
      .getSingleOrNull();

  Future<int> _routineUndelivered(String? id) async =>
      (await db
              .customSelect(
                "SELECT count(*) AS n FROM routine_mutations WHERE owner_id=? AND state!='acknowledged' "
                '${id == null ? '' : 'AND routine_id=?'}',
                variables: [Variable(ownerId), if (id != null) Variable(id)],
              )
              .getSingle())
          .read<int>('n');

  Future<int> routinePendingCount() => db.transaction(() async {
    await _guard();
    return _routineUndelivered(null);
  });

  Future<int> routineAttentionCount() => db.transaction(() async {
    await _guard();
    return (await db
            .customSelect(
              'SELECT count(*) AS n FROM routine_sync_state WHERE owner_id=? AND has_conflict=1',
              variables: [Variable(ownerId)],
            )
            .getSingle())
        .read<int>('n');
  });

  Future<Json?> routineSyncDetails(String id) => db.transaction(() async {
    await _guard();
    final state = await _routineSyncRow(id);
    if (state == null) return null;
    final working = await db
        .customSelect(
          'SELECT r.current_template_id, EXISTS('
          'SELECT 1 FROM routine_cloud_templates c WHERE c.owner_id=r.owner_id '
          'AND c.routine_id=r.id) AS has_cloud_history '
          'FROM routines r WHERE r.owner_id=? AND r.id=?',
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingle();
    final head = await db
        .customSelect(
          "SELECT state,last_error FROM routine_mutations WHERE owner_id=? AND routine_id=? AND state!='acknowledged' ORDER BY local_sequence LIMIT 1",
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingleOrNull();
    final shadow = state.readNullable<String>('server_shadow');
    return {
      ...state.data,
      // A missing current cloud root does not turn retained cloud snapshots
      // into locally authored catalog definitions. This is a derived read only.
      'has_cloud_history': working.read<int>('has_cloud_history') == 1,
      'pending_count': await _routineUndelivered(id),
      'working_template_id': working.readNullable<String>(
        'current_template_id',
      ),
      'accepted_template_id': shadow == null
          ? null
          : (jsonDecode(shadow) as Json)['current_template_id'],
      'mutation_state': head?.read<String>('state'),
      'last_error': head?.readNullable<String>('last_error'),
    };
  });

  Future<List<String>> pendingRoutineRoots() => db.transaction(() async {
    await _guard();
    return [
      for (final row
          in await db
              .customSelect(
                "SELECT routine_id FROM routine_mutations WHERE owner_id=? AND state='pending' "
                'GROUP BY routine_id ORDER BY min(rowid)',
                variables: [Variable(ownerId)],
              )
              .get())
        row.read<String>('routine_id'),
    ];
  });

  Future<String?> prepareRoutineHead(String id) => db.transaction(() async {
    await _guard();
    await _requireLegacySync();
    final state = await _routineSyncRow(id);
    if (state == null || state.read<int>('has_conflict') != 0) return null;
    final row = await db
        .customSelect(
          "SELECT * FROM routine_mutations WHERE owner_id=? AND routine_id=? AND state!='acknowledged' ORDER BY local_sequence LIMIT 1",
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingleOrNull();
    if (row == null || row.read<String>('state') != 'pending') return null;
    final frozen = row.readNullable<String>('frozen_body');
    if (frozen != null) {
      _validateRoutineOperation(jsonDecode(frozen) as Json);
      if (row.readNullable<String>('request_digest') !=
          sha256.convert(utf8.encode(frozen)).toString()) {
        throw const ContractViolation('mutation_digest_mismatch');
      }
      return frozen;
    }
    var revision = row.read<int>('origin_base');
    var templateBase = row.readNullable<String>('base_template_id');
    final predecessor = row.readNullable<String>('predecessor_id');
    if (predecessor != null) {
      final prior = await db
          .customSelect(
            'SELECT * FROM routine_mutations WHERE owner_id=? AND routine_id=? AND mutation_id=?',
            variables: [Variable(ownerId), Variable(id), Variable(predecessor)],
          )
          .getSingle();
      if (prior.read<String>('state') != 'acknowledged') return null;
      revision = prior.read<int>('accepted_revision');
      templateBase = prior.read<String>('template_id');
    }
    final template = await db
        .customSelect(
          'SELECT prescription FROM workout_templates WHERE owner_id=? AND routine_id=? AND id=?',
          variables: [
            Variable(ownerId),
            Variable(id),
            Variable(row.read<String>('template_id')),
          ],
        )
        .getSingle();
    final identity = await syncMetadata();
    final operation = {
      'mutation_id': row.read<String>('mutation_id'),
      'installation_id': identity['installation_id'],
      'aggregate_type': 'routine',
      'aggregate_id': id,
      'expected_revision': revision,
      'command': revision == 0 ? 'create_routine' : 'publish_template',
      'occurred_at': row.read<String>('enqueued_at'),
      'recorded_at': row.read<String>('enqueued_at'),
      'payload': {
        'template_id': row.read<String>('template_id'),
        'predecessor_template_id': templateBase,
        'prescription': jsonDecode(template.read<String>('prescription')),
      },
    };
    _validateRoutineOperation(operation);
    final body = canonicalJson(operation);
    if (utf8.encode(body).length > commandByteLimit) {
      await _markRoutineOversized(row.read<String>('mutation_id'));
      return null;
    }
    await db.customStatement(
      'UPDATE routine_mutations SET frozen_body=?,request_digest=? WHERE mutation_id=? AND owner_id=?',
      [
        body,
        sha256.convert(utf8.encode(body)).toString(),
        row.read<String>('mutation_id'),
        ownerId,
      ],
    );
    return body;
  });

  Future<void> _markRoutineOversized(String mutation) async {
    await db.customStatement(
      "UPDATE routine_mutations SET state='rejected',last_error='command_capacity' WHERE owner_id=? AND mutation_id=?",
      [ownerId, mutation],
    );
    await db.customStatement(
      'UPDATE routine_sync_state SET has_conflict=1 WHERE owner_id=? AND routine_id=(SELECT routine_id FROM routine_mutations WHERE owner_id=? AND mutation_id=?)',
      [ownerId, ownerId, mutation],
    );
  }

  Future<void> markMixedOversized(String mutation) => db.transaction(() async {
    await _guard();
    if (await _isRoutineMutation(mutation)) {
      await _markRoutineOversized(mutation);
    } else {
      await markOversized(mutation);
    }
  });

  Future<bool> _isRoutineMutation(String mutation) async {
    final row = await db
        .customSelect(
          'SELECT mutation_id FROM routine_mutations WHERE owner_id=? AND mutation_id=?',
          variables: [Variable(ownerId), Variable(mutation)],
        )
        .getSingleOrNull();
    if (row == null) return false;
    if (await db
            .customSelect(
              'SELECT mutation_id FROM outbox WHERE mutation_id=?',
              variables: [Variable(mutation)],
            )
            .getSingleOrNull() !=
        null) {
      throw const ContractViolation('identity_collision');
    }
    return true;
  }

  Future<void> markMixedAttempts(List<String> mutations) =>
      db.transaction(() async {
        await _guard();
        await _requireLegacySync();
        for (final mutation in mutations) {
          if (!await _isRoutineMutation(mutation)) {
            await markAttempts([mutation]);
            continue;
          }
          final row = await db
              .customSelect(
                'SELECT frozen_body,request_digest FROM routine_mutations WHERE owner_id=? AND mutation_id=?',
                variables: [Variable(ownerId), Variable(mutation)],
              )
              .getSingle();
          final body = row.read<String>('frozen_body');
          _validateRoutineOperation(jsonDecode(body) as Json);
          if (sha256.convert(utf8.encode(body)).toString() !=
              row.read<String>('request_digest')) {
            throw const ContractViolation('mutation_digest_mismatch');
          }
          await db.customStatement(
            'UPDATE routine_mutations SET attempt_count=attempt_count+1 WHERE owner_id=? AND mutation_id=?',
            [ownerId, mutation],
          );
        }
      });

  Future<void> _installRoutineAck(Json result) async {
    await _requireLegacySync();
    final row = await db
        .customSelect(
          'SELECT * FROM routine_mutations WHERE owner_id=? AND mutation_id=?',
          variables: [
            Variable(ownerId),
            Variable(result['mutation_id'] as String),
          ],
        )
        .getSingle();
    final id = row.read<String>('routine_id');
    final body = row.readNullable<String>('frozen_body');
    if (id != result['aggregate_id'] ||
        body == null ||
        sha256.convert(utf8.encode(body)).toString() !=
            row.readNullable<String>('request_digest')) {
      throw const ContractViolation('mutation_digest_mismatch');
    }
    final operation = jsonDecode(body) as Json;
    _validateRoutineOperation(operation);
    if (['accepted', 'duplicate'].contains(result['status'])) {
      final revision = result['accepted_revision'] as int;
      if (revision != operation['expected_revision'] + 1 ||
          row.readNullable<int>('accepted_revision') != null &&
              row.read<int>('accepted_revision') != revision) {
        throw const ContractViolation();
      }
      final state = (await _routineSyncRow(id))!;
      if (state.read<int>('server_revision') >= revision) {
        final encoded = state.readNullable<String>('server_shadow');
        final shadow = encoded == null
            ? null
            : _validatedRoutineRoot(jsonDecode(encoded) as Json);
        final accepted = {
          ...operation['payload'] as Json,
          'revision': revision,
        };
        if (shadow == null ||
            canonicalJson((shadow['templates'] as List)[revision - 1]) !=
                canonicalJson(accepted)) {
          // An old receipt can acknowledge delivery only if the authoritative
          // immutable history actually contains that exact publication.
          throw const ContractViolation('immutable_template_mismatch');
        }
      }
      await db.customStatement(
        "UPDATE routine_mutations SET state='acknowledged',accepted_revision=?,last_error=NULL WHERE owner_id=? AND mutation_id=?",
        [revision, ownerId, result['mutation_id']],
      );
      if (state.read<int>('server_revision') < revision) {
        final encoded = state.readNullable<String>('server_shadow');
        final root = _routineAfter(
          encoded == null ? null : jsonDecode(encoded) as Json,
          operation,
          revision,
        );
        await _installRoutineShadow(root);
      } else {
        await _adoptRoutineHead(id);
      }
    } else {
      if (row.read<String>('state') == 'acknowledged' ||
          result['status'] == 'conflict' &&
              (result['expected_revision'] != operation['expected_revision'] ||
                  result['current_revision'] ==
                      operation['expected_revision'])) {
        throw const ContractViolation();
      }
      await db.customStatement(
        'UPDATE routine_mutations SET state=?,last_error=? WHERE owner_id=? AND mutation_id=?',
        [
          result['status'],
          result['error']['code'],
          ownerId,
          result['mutation_id'],
        ],
      );
      await db.customStatement(
        'UPDATE routine_sync_state SET has_conflict=1 WHERE owner_id=? AND routine_id=?',
        [ownerId, id],
      );
    }
  }

  Future<void> _installRoutineEcho(Json operation, int revision) async {
    _validateRoutineOperation(operation);
    if (revision != operation['expected_revision'] + 1) {
      throw const ContractViolation();
    }
    final id = operation['aggregate_id'] as String;
    final own = await db
        .customSelect(
          'SELECT frozen_body FROM routine_mutations WHERE owner_id=? AND mutation_id=?',
          variables: [
            Variable(ownerId),
            Variable(operation['mutation_id'] as String),
          ],
        )
        .getSingleOrNull();
    if (own != null) {
      if (own.readNullable<String>('frozen_body') != canonicalJson(operation)) {
        throw const ContractViolation('mutation_digest_mismatch');
      }
      await _installRoutineAck({
        'mutation_id': operation['mutation_id'],
        'aggregate_id': id,
        'status': 'accepted',
        'accepted_revision': revision,
      });
    }
    final state = await _routineSyncRow(id);
    if ((state?.read<int>('server_revision') ?? 0) >= revision) {
      final encoded = state?.readNullable<String>('server_shadow');
      final shadow = encoded == null
          ? null
          : _validatedRoutineRoot(jsonDecode(encoded) as Json);
      final accepted = {...operation['payload'] as Json, 'revision': revision};
      if (shadow == null ||
          canonicalJson((shadow['templates'] as List)[revision - 1]) !=
              canonicalJson(accepted)) {
        // A newer acknowledgement does not authorize discarding a contradictory
        // older feed publication. Reject the entire page before its cursor moves.
        throw const ContractViolation('immutable_template_mismatch');
      }
    } else {
      final encoded = state?.readNullable<String>('server_shadow');
      await _installRoutineShadow(
        _routineAfter(
          encoded == null ? null : jsonDecode(encoded) as Json,
          operation,
          revision,
        ),
      );
    }
  }

  Future<void> _installRoutineShadow(
    Json value, {
    bool generationChanged = false,
  }) async {
    final root = _validatedRoutineRoot(value);
    final id = root['aggregate_id'] as String;
    await _guardRoutineIdentity(id, id, root: true);
    for (final template in (root['templates'] as List).cast<Json>()) {
      await _guardRoutineIdentity(
        template['template_id'] as String,
        id,
        root: false,
      );
    }
    final state = await _routineSyncRow(id);
    final previous = state?.readNullable<String>('server_shadow');
    final previousRoot = previous == null ? null : jsonDecode(previous) as Json;
    if (!generationChanged && state != null) {
      final superseded = state.read<int>('server_revision') > root['revision'];
      if (state.read<int>('server_revision') == root['revision'] &&
          previous != canonicalJson(root)) {
        throw const ContractViolation('invalid_routine_history');
      }
      if (previousRoot != null) {
        final oldTemplates = previousRoot['templates'] as List;
        final nextTemplates = root['templates'] as List;
        if (!superseded && oldTemplates.length > nextTemplates.length) {
          throw const ContractViolation('invalid_routine_history');
        }
        for (
          var i = 0;
          i < oldTemplates.length && i < nextTemplates.length;
          i++
        ) {
          if (canonicalJson(oldTemplates[i]) !=
              canonicalJson(nextTemplates[i])) {
            throw const ContractViolation('immutable_template_mismatch');
          }
        }
      }
      // A push acknowledgement may be ahead of the pull cursor. Keep that
      // newer shadow, but only after checking the older snapshot's immutable
      // prefix; an older revision cannot conceal contradictory accepted data.
      if (superseded) return;
    }
    if (state == null) {
      await db.customStatement(
        'INSERT INTO routines(id,owner_id,local_revision) VALUES(?,?,0)',
        [id, ownerId],
      );
      await db.customStatement(
        'INSERT INTO routine_sync_state(owner_id,routine_id) VALUES(?,?)',
        [ownerId, id],
      );
    }
    for (final template in (root['templates'] as List).cast<Json>()) {
      final encoded = canonicalJson(template);
      final existing = await db
          .customSelect(
            'SELECT routine_id,template_json FROM routine_cloud_templates WHERE owner_id=? AND template_id=?',
            variables: [
              Variable(ownerId),
              Variable(template['template_id'] as String),
            ],
          )
          .getSingleOrNull();
      if (existing != null &&
          (existing.read<String>('routine_id') != id ||
              existing.read<String>('template_json') != encoded)) {
        throw const ContractViolation('immutable_template_mismatch');
      }
      if (existing == null) {
        await db.customStatement(
          'INSERT INTO routine_cloud_templates(owner_id,routine_id,template_id,template_json) VALUES(?,?,?,?)',
          [ownerId, id, template['template_id'], encoded],
        );
      }
    }
    final conflict =
        generationChanged &&
        state != null &&
        (previous != canonicalJson(root) || await _routineUndelivered(id) > 0);
    await db.customStatement(
      'UPDATE routine_sync_state SET server_revision=?,server_shadow=?,has_conflict=max(has_conflict,?) WHERE owner_id=? AND routine_id=?',
      [root['revision'], canonicalJson(root), conflict ? 1 : 0, ownerId, id],
    );
    await _adoptRoutineHead(id);
  }

  Future<void> _adoptRoutineHead(String id) async {
    final state = (await _routineSyncRow(id))!;
    if (state.read<int>('has_conflict') != 0 ||
        await _routineUndelivered(id) != 0) {
      return;
    }
    final encoded = state.readNullable<String>('server_shadow');
    if (encoded == null) return;
    final root = jsonDecode(encoded) as Json;
    final template = (root['templates'] as List).last as Json;
    final plan = RoutinePlan.fromJson(template['prescription'] as Json);
    final current = await db
        .customSelect(
          'SELECT local_revision,current_template_id FROM routines WHERE owner_id=? AND id=?',
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingle();
    final localTemplate = await db
        .customSelect(
          'SELECT routine_id,local_revision,prescription FROM workout_templates WHERE owner_id=? AND id=?',
          variables: [
            Variable(ownerId),
            Variable(template['template_id'] as String),
          ],
        )
        .getSingleOrNull();
    int editorRevision;
    if (localTemplate != null) {
      if (localTemplate.read<String>('routine_id') != id ||
          localTemplate.read<String>('prescription') !=
              canonicalJson(plan.json)) {
        throw const ContractViolation('immutable_template_mismatch');
      }
      editorRevision = localTemplate.read<int>('local_revision');
      if (editorRevision < current.read<int>('local_revision')) {
        await db.customStatement(
          'UPDATE routine_sync_state SET has_conflict=1 WHERE owner_id=? AND routine_id=?',
          [ownerId, id],
        );
        return;
      }
    } else {
      editorRevision =
          (await db
                  .customSelect(
                    'SELECT coalesce(max(local_revision),0)+1 AS n FROM workout_templates WHERE owner_id=? AND routine_id=?',
                    variables: [Variable(ownerId), Variable(id)],
                  )
                  .getSingle())
              .read<int>('n');
      await db.customStatement(
        'INSERT INTO workout_templates(id,owner_id,routine_id,local_revision,prescription) VALUES(?,?,?,?,?)',
        [
          template['template_id'],
          ownerId,
          id,
          editorRevision,
          canonicalJson(plan.json),
        ],
      );
    }
    await db.customStatement(
      'UPDATE routines SET current_template_id=?,local_revision=? WHERE owner_id=? AND id=?',
      [template['template_id'], editorRevision, ownerId, id],
    );
  }

  Future<void> _installMissingRoutines(
    Set<String> seen,
    bool generationChanged,
  ) async {
    for (final state
        in await db
            .customSelect(
              'SELECT routine_id,server_revision FROM routine_sync_state WHERE owner_id=?',
              variables: [Variable(ownerId)],
            )
            .get()) {
      final id = state.read<String>('routine_id');
      if (seen.contains(id)) continue;
      if (state.read<int>('server_revision') > 0 ||
          generationChanged && await _routineUndelivered(id) > 0) {
        // Absence is not erasure. Keep working and immutable history recoverable.
        await db.customStatement(
          'UPDATE routine_sync_state SET server_revision=0,server_shadow=NULL,has_conflict=1 WHERE owner_id=? AND routine_id=?',
          [ownerId, id],
        );
      }
    }
  }
}
