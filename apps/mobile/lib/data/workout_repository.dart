import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/workout.dart';
import '../domain/rest_timer.dart';
import '../sync/contract_validation.dart';
import '../sync/transport_contract.dart';
import '../sync/transport_limits.dart';
import 'database.dart';

part 'sync_repository.dart';

class WorkoutRepository {
  final TrainingDatabase db;
  final String ownerId;
  final DateTime Function() now;
  final String Function() newId;
  final RestClock _restClock;
  final _commits = StreamController<void>.broadcast();
  Stream<void> get commits => _commits.stream;
  void dispose() => unawaited(_commits.close());
  void Function(Duration duration)? onLocalCommit;

  WorkoutRepository(
    this.db,
    this.ownerId, {
    DateTime Function()? clock,
    String Function()? idFactory,
    RestClock? restClock,
  }) : now = clock ?? DateTime.now,
       _restClock = restClock ?? WallRestClock(clock ?? DateTime.now),
       newId = idFactory ?? const Uuid().v4;

  Future<void> initialize() => db.transaction(() async {
    require(
      Uuid.isValidUUID(fromString: ownerId),
      'A verified owner UUID is required.',
    );
    final identity = await db
        .customSelect('SELECT * FROM local_identity')
        .getSingleOrNull();
    if (identity == null) {
      await db.customStatement(
        'INSERT INTO local_identity(singleton,owner_id,installation_id) VALUES(1,?,?)',
        [ownerId, newId()],
      );
    } else {
      require(
        identity.read<String>('owner_id') == ownerId,
        'This database belongs to another account.',
      );
      require(
        identity.read<int>('locked') == 0,
        'Sign in to this account to unlock its local data.',
      );
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO sync_metadata(singleton) VALUES(1)',
    );
  });

  Future<void> _guard() async {
    final identity = await db
        .customSelect('SELECT * FROM local_identity')
        .getSingle();
    require(
      identity.read<String>('owner_id') == ownerId &&
          identity.read<int>('locked') == 0,
      'This account is locked.',
    );
    final remote = await db
        .customSelect('SELECT remote_disabled FROM sync_metadata')
        .getSingle();
    require(
      remote.read<int>('remote_disabled') == 0,
      'This account has been disabled remotely.',
    );
  }

  Future<void> signOut() => db.transaction(() async {
    await _guard();
    await db.customStatement(
      'UPDATE local_identity SET locked=1 WHERE singleton=1',
    );
  });

  /// Call only after verifying this exact owner through the identity provider.
  Future<void> unlockVerifiedOwner(String verifiedOwner) =>
      db.transaction(() async {
        final row = await db
            .customSelect('SELECT owner_id FROM local_identity')
            .getSingle();
        require(
          verifiedOwner == ownerId &&
              row.read<String>('owner_id') == verifiedOwner,
          'Identity does not own this database.',
        );
        require(
          !await remoteDisabled(),
          'This account has been disabled remotely.',
        );
        await db.customStatement(
          'UPDATE local_identity SET locked=0 WHERE singleton=1',
        );
      });

  Future<Json?> _read(String id) async {
    final session = await db
        .customSelect(
          'SELECT * FROM sessions WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (session == null) return null;
    final exercises = await db
        .customSelect(
          'SELECT * FROM exercises WHERE session_id=? ORDER BY ordinal',
          variables: [Variable(id)],
        )
        .get();
    final sets = <String, List<QueryRow>>{};
    for (final row in exercises) {
      final exerciseId = row.read<String>('id');
      sets[exerciseId] = await db
          .customSelect(
            'SELECT * FROM workout_sets WHERE exercise_id=? ORDER BY ordinal',
            variables: [Variable(exerciseId)],
          )
          .get();
    }
    return _decodeProjection(session, exercises, sets);
  }

  Json _decodeProjection(
    QueryRow session,
    List<QueryRow> rows,
    Map<String, List<QueryRow>> sets,
  ) {
    final state = jsonDecode(session.read<String>('metadata')) as Json;
    final exercises = <Json>[];
    for (final row in rows) {
      final exercise = jsonDecode(row.read<String>('definition')) as Json;
      exercise['sets'] = [
        for (final item in sets[row.read<String>('id')] ?? <QueryRow>[])
          {
            ...jsonDecode(item.read<String>('prescription')) as Json,
            'observation': item.readNullable<String>('observation') == null
                ? null
                : jsonDecode(item.read<String>('observation')),
          },
      ];
      exercises.add(exercise);
    }
    return {
      ...state,
      'exercises': exercises,
      'local_seq': session.read<int>('local_seq'),
      'conflict': session.read<int>('has_conflict') == 1,
    };
  }

  Future<List<Json>> workouts() => db.transaction(() async {
    await _guard();
    // One consistent snapshot with bounded database round trips, not one series
    // of isolate queries per historical session on every set acknowledgement.
    final sessions = await db
        .customSelect('SELECT * FROM sessions ORDER BY rowid DESC')
        .get();
    final exercises = <String, List<QueryRow>>{};
    for (final row
        in await db
            .customSelect('SELECT * FROM exercises ORDER BY ordinal')
            .get()) {
      exercises.putIfAbsent(row.read<String>('session_id'), () => []).add(row);
    }
    final sets = <String, List<QueryRow>>{};
    for (final row
        in await db
            .customSelect('SELECT * FROM workout_sets ORDER BY ordinal')
            .get()) {
      sets.putIfAbsent(row.read<String>('exercise_id'), () => []).add(row);
    }
    return [
      for (final session in sessions)
        _decodeProjection(
          session,
          exercises[session.read<String>('id')] ?? [],
          sets,
        ),
    ];
  });

  Future<Json?> workout(String id) => db.transaction(() async {
    await _guard();
    return _read(id);
  });

  Future<void> _write(Json state, int sequence) async {
    final meta = Map<String, dynamic>.from(state)
      ..remove('exercises')
      ..remove('local_seq')
      ..remove('conflict');
    final id = state['aggregate_id'] as String;
    await db.customStatement(
      'INSERT INTO sessions(id,metadata,local_seq) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET metadata=excluded.metadata,local_seq=excluded.local_seq',
      [id, canonicalJson(meta), sequence],
    );
    final exercises = (state['exercises'] as List).cast<Json>();
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      final definition = Map<String, dynamic>.from(exercise)..remove('sets');
      await db.customStatement(
        'INSERT INTO exercises(id,session_id,ordinal,definition) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET definition=excluded.definition,ordinal=excluded.ordinal',
        [exercise['session_exercise_id'], id, i, canonicalJson(definition)],
      );
      final sets = (exercise['sets'] as List).cast<Json>();
      for (var j = 0; j < sets.length; j++) {
        final item = sets[j];
        final plan = Map<String, dynamic>.from(item)..remove('observation');
        await db.customStatement(
          'INSERT INTO workout_sets(id,exercise_id,ordinal,prescription,observation) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET observation=excluded.observation',
          [
            item['set_id'],
            exercise['session_exercise_id'],
            j,
            canonicalJson(plan),
            item['observation'] == null
                ? null
                : canonicalJson(item['observation']),
          ],
        );
      }
    }
  }

  Future<String> startFoundationWorkout() async {
    final id = newId();
    final exerciseId = newId();
    await commit(id, 'create_session', {
      'name': 'Upper body',
      'timezone': 'Asia/Kolkata',
      'exercises': [
        {
          'session_exercise_id': exerciseId,
          'variant_id': '10000000-0000-4000-8000-000000000005',
          'name': 'Barbell bench press',
          'loading_basis': 'total_external',
          'rep_convention': 'bilateral',
          'side': 'both',
          'sets': [
            for (var i = 0; i < 3; i++)
              {
                'set_id': newId(),
                'set_class': 'working',
                'set_purpose': 'regular',
                'planned': {
                  'reps': 5,
                  'load': {
                    'value': '60',
                    'unit': 'kg',
                    'basis': 'total_external',
                  },
                  'rest_seconds': 120,
                },
              },
          ],
        },
      ],
    });
    return id;
  }

  Future<bool> commit(String id, String command, Json payload) async {
    final watch = Stopwatch()..start();
    final timing = command == 'record_set' ? await _restClock.sample() : null;
    final result = await db.transaction(() async {
      await _guard();
      require(
        command != 'delete_session',
        'Permanent local erasure is not enabled in the foundation build.',
      );
      require(
        await db
                .customSelect(
                  'SELECT id FROM retired_ids WHERE id=?',
                  variables: [Variable(id)],
                )
                .getSingleOrNull() ==
            null,
        'This ID has been permanently retired.',
      );
      final previous = await _read(id);
      if (command == 'create_session') {
        final ids = <String>[id];
        for (final raw in payload['exercises'] as List) {
          final exercise = raw as Json;
          ids.add(exercise['session_exercise_id'] as String);
          ids.addAll(
            (exercise['sets'] as List).map((item) => item['set_id'] as String),
          );
        }
        for (final child in ids) {
          final used = await db
              .customSelect(
                'SELECT id FROM sessions WHERE id=? UNION ALL SELECT id FROM exercises WHERE id=? UNION ALL SELECT id FROM workout_sets WHERE id=? UNION ALL SELECT id FROM retired_ids WHERE id=?',
                variables: [
                  Variable(child),
                  Variable(child),
                  Variable(child),
                  Variable(child),
                ],
              )
              .get();
          require(
            used.isEmpty,
            'This workout or child ID is already used or retired.',
          );
        }
        for (final row
            in await db.customSelect('SELECT metadata FROM sessions').get()) {
          require(
            (jsonDecode(row.read<String>('metadata')) as Json)['status'] !=
                'active',
            'Resume or finish the active workout first.',
          );
        }
      }
      if (command == 'record_set' &&
          previous != null &&
          allSets(previous).any(
            (s) => s['set_id'] == payload['set_id'] && s['observation'] != null,
          )) {
        return false;
      }
      final identity = await db
          .customSelect('SELECT installation_id FROM local_identity')
          .getSingle();
      final shadow = await db
          .customSelect(
            'SELECT revision FROM shadows WHERE session_id=?',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      final head = await db
          .customSelect(
            "SELECT * FROM outbox WHERE session_id=? AND state != 'acknowledged' ORDER BY local_seq DESC LIMIT 1",
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      final stamp = now().toUtc().toIso8601String();
      final branchRow = await db
          .customSelect(
            'SELECT branch_base FROM sessions WHERE id=?',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      final branchBase =
          branchRow?.readNullable<int>('branch_base') ??
          shadow?.read<int>('revision') ??
          0;
      final operation = <String, dynamic>{
        'mutation_id': newId(),
        'installation_id': identity.read<String>('installation_id'),
        'aggregate_type': 'workout_session',
        'aggregate_id': id,
        'expected_revision': branchBase,
        'command': command,
        'occurred_at': stamp,
        'recorded_at': stamp,
        'payload': copyJson(payload),
      };
      // Reserve enough room for the largest supported integer revision before accepting locally.
      final bounded = {...operation, 'expected_revision': 9223372036854775807};
      require(
        utf8.encode(canonicalJson(bounded)).length <= commandByteLimit,
        'This edit exceeds the command size limit. Your draft is retained.',
      );
      validateEnvelope(operation);
      try {
        validateTransport('Operation', operation);
      } on ContractViolation {
        throw const WorkoutValidation(
          'This edit does not match the supported workout contract. Your draft is retained.',
        );
      }
      final next = applyOperation(previous, operation)!;
      final sequence = (previous?['local_seq'] as int? ?? 0) + 1;
      await _write(next, sequence);
      await db.customStatement('UPDATE sessions SET branch_base=? WHERE id=?', [
        branchBase,
        id,
      ]);
      await db.customStatement(
        'INSERT INTO outbox(mutation_id,session_id,local_seq,predecessor_id,origin_base,operation,state) VALUES(?,?,?,?,?,?,?)',
        [
          operation['mutation_id'],
          id,
          sequence,
          head?.read<String>('mutation_id'),
          branchBase,
          canonicalJson(operation),
          'pending',
        ],
      );
      if (command == 'record_set' || command == 'correct_set') {
        await db.customStatement(
          'INSERT INTO local_observations(session_id,local_seq,set_id,payload) VALUES(?,?,?,?)',
          [
            id,
            sequence,
            payload['set_id'],
            canonicalJson({
              ...payload,
              'occurred_at': stamp,
              'recorded_at': stamp,
            }),
          ],
        );
        await db.customStatement('DELETE FROM drafts WHERE set_id=?', [
          payload['set_id'],
        ]);
        if (command == 'record_set' &&
            payload['execution_status'] != 'skipped') {
          final item = allSets(next)
              .firstWhere((s) => s['set_id'] == payload['set_id']);
          final rest = item['planned']['rest_seconds'] as int;
          await db.customStatement(
            'INSERT INTO rest_timers(session_id,anchor,deadline,monotonic_us,continuity_id,uncertain) VALUES(?,?,?,?,?,?) ON CONFLICT(session_id) DO UPDATE SET anchor=excluded.anchor,deadline=excluded.deadline,monotonic_us=excluded.monotonic_us,continuity_id=excluded.continuity_id,uncertain=excluded.uncertain',
            [
              id,
              timing!.wall.toUtc().toIso8601String(),
              timing.wall
                  .toUtc()
                  .add(Duration(seconds: rest))
                  .toIso8601String(),
              timing.elapsedUs,
              timing.continuityId,
              timing.elapsedUs == null || timing.continuityId == null ? 1 : 0,
            ],
          );
        }
      }
      if (command == 'complete_session' || command == 'abandon_session') {
        await db.customStatement('DELETE FROM rest_timers WHERE session_id=?', [
          id,
        ]);
      }
      return true;
    });
    watch.stop();
    try {
      onLocalCommit?.call(watch.elapsed);
    } catch (_) {
      /* Observability cannot undo a durable save. */
    }
    if (result && !_commits.isClosed) _commits.add(null);
    return result;
  }

  Future<void> saveDraft(String setId, Json values) => db.transaction(() async {
    await _guard();
    final item = await db
        .customSelect(
          'SELECT observation FROM workout_sets WHERE id=?',
          variables: [Variable(setId)],
        )
        .getSingle();
    if (item.readNullable<String>('observation') != null) return;
    await db.customStatement(
      'INSERT INTO drafts(set_id,values_json) VALUES(?,?) ON CONFLICT(set_id) DO UPDATE SET values_json=excluded.values_json',
      [setId, canonicalJson(values)],
    );
  });

  Future<Json?> draft(String setId) => db.transaction(() async {
    await _guard();
    final row = await db
        .customSelect(
          'SELECT values_json FROM drafts WHERE set_id=?',
          variables: [Variable(setId)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : jsonDecode(row.read<String>('values_json')) as Json;
  });

  Future<DateTime?> timerDeadline(String sessionId) => db.transaction(() async {
    await _guard();
    final row = await db
        .customSelect(
          'SELECT deadline FROM rest_timers WHERE session_id=?',
          variables: [Variable(sessionId)],
        )
        .getSingleOrNull();
    return row == null ? null : DateTime.parse(row.read<String>('deadline'));
  });

  Future<RestDisplay?> restDisplay(String sessionId) async {
    final sample = await _restClock.sample();
    return db.transaction(() async {
      await _guard();
      final row = await db
          .customSelect(
            'SELECT * FROM rest_timers WHERE session_id=?',
            variables: [Variable(sessionId)],
          )
          .getSingleOrNull();
      if (row == null) return null;
      final display = RestAnchor(
        DateTime.parse(row.read<String>('anchor')),
        DateTime.parse(row.read<String>('deadline')),
        elapsedUs: row.readNullable<int>('monotonic_us'),
        continuityId: row.readNullable<String>('continuity_id'),
        uncertain: row.read<int>('uncertain') == 1,
      ).project(sample);
      if (display.uncertain && row.read<int>('uncertain') == 0) {
        await db.customStatement(
          'UPDATE rest_timers SET uncertain=1 WHERE session_id=?',
          [sessionId],
        );
      }
      return display;
    });
  }

  Future<void> cancelTimer(String id) => db.transaction(() async {
    await _guard();
    await db.customStatement('DELETE FROM rest_timers WHERE session_id=?', [
      id,
    ]);
  });

  Future<int> pendingCount() => db.transaction(() async {
    await _guard();
    return (await db
            .customSelect(
              "SELECT count(*) AS count FROM outbox WHERE state != 'acknowledged' AND last_error IS NOT 'retired_id'",
            )
            .getSingle())
        .read<int>('count');
  });

  /// Freezing precedes HTTP. A dependent uses its own predecessor receipt, even after newer pulls.
  Future<String?> prepareHead(String id) => db.transaction(() async {
    await _guard();
    final row = await db
        .customSelect(
          "SELECT * FROM outbox WHERE session_id=? AND state != 'acknowledged' ORDER BY local_seq LIMIT 1",
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (row == null || row.read<String>('state') != 'pending') return null;
    if (row.readNullable<String>('frozen_body') != null) {
      return row.read<String>('frozen_body');
    }
    var revision = row.read<int>('origin_base');
    final predecessor = row.readNullable<String>('predecessor_id');
    if (predecessor != null) {
      final receipt = await db
          .customSelect(
            'SELECT accepted_revision FROM outbox WHERE mutation_id=?',
            variables: [Variable(predecessor)],
          )
          .getSingle();
      if (receipt.readNullable<int>('accepted_revision') == null) return null;
      revision = receipt.read<int>('accepted_revision');
    }
    final op = jsonDecode(row.read<String>('operation')) as Json;
    op['expected_revision'] = revision;
    final frozen = canonicalJson(op);
    await db.customStatement(
      'UPDATE outbox SET frozen_body=? WHERE mutation_id=?',
      [frozen, row.read<String>('mutation_id')],
    );
    return frozen;
  });

  Future<void> acknowledge(Json result) => db.transaction(() async {
    await _guard();
    await _installAck(result);
  });

  Future<void> installRemote(Json projection) => db.transaction(() async {
    await _guard();
    await _installRemote(projection);
  });

  Future<void> _installRemote(Json projection) =>
      _installConnectedRemote(projection, external: true);

  /// Validate every page before one activation transaction; retain branches logged during download.
  Future<void> installBootstrap(
    List<Json> pages,
    List<String> checksums,
    String cursor,
  ) async {
    require(
      pages.length == checksums.length && pages.isNotEmpty,
      'Incomplete snapshot.',
    );
    var size = 0;
    for (var i = 0; i < pages.length; i++) {
      final bytes = utf8.encode(canonicalJson(pages[i]));
      require(
        sha256.convert(bytes).toString() == checksums[i],
        'Snapshot checksum mismatch.',
      );
      size += bytes.length;
    }
    require(size <= transportSnapshotLimit, 'Snapshot capacity exceeded.');
    await db.transaction(() async {
      await _guard();
      final seen = <String>{};
      for (final page in pages) {
        for (final raw in page['roots'] as List) {
          final root = raw as Json;
          require(
            seen.add(root['aggregate_id'] as String),
            'Duplicate snapshot root.',
          );
          await _installRemote(root);
        }
      }
      // Missing clean roots disappear; pending roots and their original bases survive.
      for (final row
          in await db.customSelect('SELECT session_id FROM shadows').get()) {
        final id = row.read<String>('session_id');
        if (seen.contains(id)) continue;
        final pending = await db
            .customSelect(
              "SELECT mutation_id FROM outbox WHERE session_id=? AND state != 'acknowledged' LIMIT 1",
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        await db.customStatement('DELETE FROM shadows WHERE session_id=?', [
          id,
        ]);
        if (pending == null) {
          await db.customStatement('DELETE FROM sessions WHERE id=?', [id]);
        }
      }
      await db.customStatement(
        'UPDATE local_identity SET cursor=? WHERE singleton=1',
        [cursor],
      );
    });
  }
}
