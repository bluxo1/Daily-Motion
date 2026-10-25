import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as native;
import 'package:uuid/uuid.dart';

import 'repository_test.dart' show fixture, owner, recordPayload;
import 'support/sync_server.dart';
import 'support/owned_fixture.dart';
import 'history_read_test.dart' show CountReads;

import 'package:daily_motion/sync/coordinator.dart';

const routineId = '60000000-0000-4000-8000-000000000001';
const attemptId = '70000000-0000-4000-8000-000000000001';
const otherOwner = '20000000-0000-4000-8000-000000000002';

/// Build the actual pre-change SQL layout, including a pending frozen create.
/// The fixture is byte-identical to main's schema.drift at e3104b5.
void seedSchemaFour(File file) {
  final raw = native.sqlite3.open(file.path);
  try {
    raw.execute(File('test/support/schema_v4.sql').readAsStringSync());
    final operation = fixture();
    final state = applyOperation(null, operation)!;
    final metadata = copyJson(state)..remove('exercises');
    raw.execute(
      'INSERT INTO local_identity(singleton,owner_id,installation_id) VALUES(1,?,?)',
      [owner, operation['installation_id']],
    );
    raw.execute('INSERT INTO sync_metadata(singleton) VALUES(1)');
    raw.execute('INSERT INTO recovery_state(singleton) VALUES(1)');
    raw.execute(
      'INSERT INTO sessions(id,metadata,local_seq,branch_base) VALUES(?,?,1,0)',
      [state['aggregate_id'], canonicalJson(metadata)],
    );
    var ordinal = 0;
    for (final exercise in (state['exercises'] as List).cast<Json>()) {
      final definition = copyJson(exercise)..remove('sets');
      raw.execute(
        'INSERT INTO exercises(id,session_id,ordinal,definition) VALUES(?,?,?,?)',
        [
          exercise['session_exercise_id'],
          state['aggregate_id'],
          ordinal++,
          canonicalJson(definition),
        ],
      );
      var setOrdinal = 0;
      for (final item in (exercise['sets'] as List).cast<Json>()) {
        final prescription = copyJson(item)..remove('observation');
        raw.execute(
          'INSERT INTO workout_sets(id,exercise_id,ordinal,prescription) VALUES(?,?,?,?)',
          [
            item['set_id'],
            exercise['session_exercise_id'],
            setOrdinal++,
            canonicalJson(prescription),
          ],
        );
      }
    }
    raw.execute(
      "INSERT INTO outbox(mutation_id,session_id,local_seq,origin_base,operation,frozen_body,state) VALUES(?,?,1,0,?,?,'pending')",
      [
        operation['mutation_id'],
        operation['aggregate_id'],
        canonicalJson(operation),
        canonicalJson(operation),
      ],
    );
    raw.execute('PRAGMA user_version=4');
  } finally {
    raw.close();
  }
}

RoutinePlan routinePlan({String name = 'Upper body', int reps = 5}) {
  final payload = fixture()['payload'] as Json;
  payload['name'] = name;
  for (final item in (payload['exercises'] as List).first['sets'] as List) {
    item['planned']['reps'] = reps;
  }
  return RoutinePlan.fromJson(payload);
}

void main() {
  late Directory directory;
  late File file;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routine-store-');
    file = File('${directory.path}/owner.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  });
  tearDown(() async {
    repo.dispose();
    await db.close();
    final check = TrainingDatabase.open(file);
    expect(
      (await check.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(await check.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await check.close();
    await deleteOwnedTemporaryDirectory(directory, 'routine-store-');
  });
  Future<void> reopen() async {
    repo.dispose();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT count(*) AS n FROM $table').getSingle())
          .read<int>('n');
  Future<SavedRoutine> save({RoutinePlan? plan, int revision = 0}) =>
      repo.saveRoutine(
        id: routineId,
        expectedRevision: revision,
        plan: plan ?? routinePlan(),
      );
  Future<String> start(SavedRoutine saved, {String attempt = attemptId}) =>
      repo.startRoutine(
        routineId: saved.id,
        templateId: saved.templateId,
        attemptId: attempt,
        timezone: 'Asia/Kolkata',
      );

  test(
    'routine start rejects missing and unsupported timezone without writes',
    () async {
      final saved = await save();
      for (final zone in <String?>[
        null,
        '',
        'Mars/Olympus_Mons',
        'UTC+05:30',
        'America/New_York',
      ]) {
        await expectLater(
          repo.startRoutine(
            routineId: saved.id,
            templateId: saved.templateId,
            attemptId: attemptId,
            timezone: zone,
          ),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(await count('sessions'), 0);
        expect(await count('outbox'), 0);
        expect(await count('routine_starts'), 0);
      }
    },
  );

  test(
    'explicit UTC survives routine start, exact retry and SQLite reopening',
    () async {
      final saved = await save();
      final id = await repo.startRoutine(
        routineId: saved.id,
        templateId: saved.templateId,
        attemptId: attemptId,
        timezone: 'UTC',
      );
      final body = await repo.prepareHead(id);
      expect(jsonDecode(body!)['payload']['timezone'], 'UTC');
      await reopen();
      expect((await repo.workout(id))!['timezone'], 'UTC');
      expect(
        await repo.startRoutine(
          routineId: saved.id,
          templateId: saved.templateId,
          attemptId: attemptId,
          timezone: 'UTC',
        ),
        id,
      );
      expect(await repo.prepareHead(id), body);
      await expectLater(
        repo.startRoutine(
          routineId: saved.id,
          templateId: saved.templateId,
          attemptId: attemptId,
          timezone: 'Asia/Kolkata',
        ),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(await count('sessions'), 1);
    },
  );

  test('create, edit and reopen preserve ordered plans and immutable versions', () async {
    final original = await save();
    final changed = original.plan.json;
    final second = copyJson((changed['exercises'] as List).first as Json);
    second['session_exercise_id'] = const Uuid().v4();
    second['variant_id'] = const Uuid().v4();
    second['name'] = 'Second movement';
    for (final item in second['sets'] as List) {
      item['set_id'] = const Uuid().v4();
      item['planned']['load'] = {
        'value': '22.5',
        'unit': 'lb',
        'basis': 'per_implement',
      };
    }
    second['loading_basis'] = 'per_implement';
    changed['exercises'] = [second, ...(changed['exercises'] as List)];
    changed['name'] = 'Reordered';
    final edited = await save(plan: RoutinePlan.fromJson(changed), revision: 1);
    await reopen();
    final loaded = (await repo.routine(routineId))!;
    expect(loaded.localRevision, 2);
    expect(loaded.templateId, edited.templateId);
    expect(loaded.plan.json, changed);
    expect((await repo.routines()).single.id, routineId);
    // Read the complete version set without relying on current-root joins.
    final versions = await db
        .customSelect(
          'SELECT prescription FROM workout_templates ORDER BY local_revision',
        )
        .get();
    expect(
      jsonDecode(versions.first.read<String>('prescription')),
      original.plan.json,
    );
    expect(versions.length, 2);
    expect(await repo.pendingCount(), 0);
    expect(await repo.workouts(), isEmpty);
  });

  test(
    'plan inputs and getters cannot mutate a stored or retained snapshot',
    () async {
      final input = routinePlan().json;
      final plan = RoutinePlan.fromJson(input);
      input['name'] = 'Mutated input';
      plan.json['name'] = 'Mutated getter';
      plan.exercises.first['sets'].clear();
      expect(plan.name, 'Upper body');
      expect(plan.exercises.first['sets'], isNotEmpty);
      final saved = await save(plan: plan);
      saved.plan.json['exercises'].clear();
      expect((await repo.routine(routineId))!.plan.json, routinePlan().json);
    },
  );

  test(
    'a remotely erased workout cannot be recreated by retrying its local start',
    () async {
      final saved = await save();
      final id = await start(saved);
      final server = SyncServer();
      final sync = SyncCoordinator(repo, server);
      try {
        await sync.synchronize(force: true);
        server.erase(id);
        await sync.synchronize(force: true);
        expect(await repo.workout(id), isNull);
        expect(await count('routine_starts'), 1);
        await expectLater(start(saved), throwsA(isA<WorkoutValidation>()));
        expect(await repo.workouts(), isEmpty);
        expect(await repo.pendingCount(), 0);
        expect((await repo.routine(routineId))!.templateId, saved.templateId);
      } finally {
        await sync.close();
      }
    },
  );

  test(
    'real SQLite pager exhaustion cannot acknowledge a partial routine edit',
    () async {
      final original = await save();
      await db.customStatement('CREATE TABLE routine_pressure(value BLOB)');
      await db.customStatement(
        'CREATE TRIGGER routine_full AFTER INSERT ON workout_templates BEGIN INSERT INTO routine_pressure VALUES(zeroblob(1048576)); END',
      );
      final pages =
          (await db.customSelect('PRAGMA page_count').getSingle())
                  .data
                  .values
                  .single
              as int;
      await db.customStatement('PRAGMA max_page_count=$pages');
      await expectLater(
        save(plan: routinePlan(name: 'Unacknowledged'), revision: 1),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('SqliteException(13)'),
            'actual SQLite pager capacity error',
          ),
        ),
      );
      expect((await repo.routine(routineId))!.templateId, original.templateId);
      expect(await count('workout_templates'), 1);
      expect(await count('routine_pressure'), 0);
      await db.customStatement('DROP TRIGGER routine_full');
      await db.customStatement('PRAGMA max_page_count=1073741823');
      await reopen();
      expect((await repo.routine(routineId))!.plan.name, original.plan.name);
      expect(
        (await save(
          plan: routinePlan(name: 'Retried'),
          revision: 1,
        )).localRevision,
        2,
      );
    },
  );

  bool expectedContention(Object e) =>
      e is WorkoutValidation ||
      e.toString().contains('SqliteException(5)') ||
      e.toString().contains('SqliteException(517)');
  test('two SQLite connections preserve CAS and immutable content under contention', () async {
    await save();
    final otherDb = TrainingDatabase.open(file);
    final other = WorkoutRepository(otherDb, owner);
    try {
      await other.initialize();
      final outcomes = await Future.wait([
        repo
            .saveRoutine(
              id: routineId,
              expectedRevision: 1,
              plan: routinePlan(name: 'Connection A'),
            )
            .then<Object>((r) => r, onError: (Object e) => e),
        other
            .saveRoutine(
              id: routineId,
              expectedRevision: 1,
              plan: routinePlan(name: 'Connection B'),
            )
            .then<Object>((r) => r, onError: (Object e) => e),
      ]);
      final committed = outcomes.whereType<SavedRoutine>().length;
      expect(committed, lessThanOrEqualTo(1));
      expect(
        outcomes.every((o) => o is SavedRoutine || expectedContention(o)),
        true,
      );
      expect((await repo.routine(routineId))!.localRevision, 1 + committed);
      expect(await count('workout_templates'), 1 + committed);
      final current = (await repo.routine(routineId))!;
      final retried = await save(
        plan: routinePlan(name: 'Explicit refreshed edit'),
        revision: current.localRevision,
      );
      expect(retried.localRevision, current.localRevision + 1);
      expect(await count('workout_templates'), 2 + committed);
    } finally {
      other.dispose();
      await otherDb.close();
    }
  });

  test('two SQLite connections retry one start identity without duplicate workouts', () async {
    final saved = await save();
    final otherDb = TrainingDatabase.open(file);
    final other = WorkoutRepository(otherDb, owner);
    try {
      await other.initialize();
      final outcomes = await Future.wait([
        start(saved).then<Object>((r) => r, onError: (Object e) => e),
        other
            .startRoutine(
              routineId: routineId,
              templateId: saved.templateId,
              attemptId: attemptId,
              timezone: 'Asia/Kolkata',
            )
            .then<Object>((r) => r, onError: (Object e) => e),
      ]);
      expect(outcomes.every((o) => o is String || expectedContention(o)), true);
      final ids = outcomes.whereType<String>().toSet();
      expect(ids.length, lessThanOrEqualTo(1));
      final id = await start(saved);
      if (ids.isNotEmpty) {
        expect(ids.single, id);
      }
      expect(await count('sessions'), 1);
      expect(await count('outbox'), 1);
      expect(await count('routine_starts'), 1);
      expect(
        allSets((await repo.workout(id))!)
            .every((s) => s['observation'] == null),
        true,
      );
    } finally {
      other.dispose();
      await otherDb.close();
    }
  });

  test('alternate UUID spelling cannot turn a known start retry into another workout', () async {
    final saved = await save();
    const token = '7abc0000-0000-4000-8000-000000000001';
    final id = await start(saved, attempt: token);
    await repo.commit(id, 'abandon_session', {});
    Object? outcome;
    try {
      outcome = await start(saved, attempt: token.toUpperCase());
    } on WorkoutValidation {
      // Rejecting non-canonical input is also safe; it cannot create a session.
    }
    if (outcome != null) expect(outcome, id);
    expect(await count('sessions'), 1);
    expect(await count('routine_starts'), 1);
  });

  test('noncanonical routine or generated template IDs roll back instead of aliasing another identity', () async {
    const alias = '6ABC0000-0000-4000-8000-000000000001';
    await expectLater(
      repo.saveRoutine(id: alias, expectedRevision: 0, plan: routinePlan()),
      throwsA(isA<WorkoutValidation>()),
    );
    final invalidFactory = WorkoutRepository(db, owner, idFactory: () => alias);
    try {
      await expectLater(
        invalidFactory.saveRoutine(
          id: routineId,
          expectedRevision: 0,
          plan: routinePlan(),
        ),
        throwsA(isA<WorkoutValidation>()),
      );
    } finally {
      invalidFactory.dispose();
    }
    expect(await repo.routines(), isEmpty);
    expect(await count('workout_templates'), 0);
  });

  test('start notifications occur only after its outer durable commit and not on replay', () async {
    final saved = await save();
    var acknowledged = 0;
    var notified = 0;
    repo.onLocalCommit = (_) => acknowledged++;
    final subscription = repo.commits.listen((_) => notified++);
    try {
      await db.customStatement(
        "CREATE TRIGGER fail_notify BEFORE INSERT ON routine_starts BEGIN SELECT RAISE(ABORT,'synthetic start receipt failure'); END",
      );
      await expectLater(start(saved), throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      expect(
        acknowledged,
        0,
        reason: 'Inner session work was rolled back by the enclosing start.',
      );
      expect(
        notified,
        0,
        reason: 'No commit notification may describe a rolled-back start.',
      );
      await db.customStatement('DROP TRIGGER fail_notify');
      final id = await start(saved);
      await Future<void>.delayed(Duration.zero);
      expect(acknowledged, 1);
      expect(notified, 1);
      expect(await start(saved), id);
      await Future<void>.delayed(Duration.zero);
      expect(acknowledged, 1);
      expect(notified, 1);
    } finally {
      await subscription.cancel();
    }
  });

  final invalid = <String, void Function(Json)>{
    'warmup backoff': (p) {
      p['exercises'][0]['sets'][0]['set_class'] = 'warmup';
      p['exercises'][0]['sets'][0]['set_purpose'] = 'backoff';
    },
    'blank name': (p) => p['name'] = ' ',
    'long name': (p) => p['name'] = 'x' * 121,
    'no exercises': (p) => p['exercises'] = [],
    'blank exercise': (p) => p['exercises'][0]['name'] = '\t',
    'bad variant': (p) => p['exercises'][0]['variant_id'] = 'unknown',
    'unsupported convention': (p) =>
        p['exercises'][0]['loading_basis'] = 'negative_assistance',
    'no sets': (p) => p['exercises'][0]['sets'] = [],
    'negative reps': (p) =>
        p['exercises'][0]['sets'][0]['planned']['reps'] = -1,
    'fractional reps': (p) =>
        p['exercises'][0]['sets'][0]['planned']['reps'] = 2.5,
    'negative rest': (p) =>
        p['exercises'][0]['sets'][0]['planned']['rest_seconds'] = -1,
    'rest beyond bound': (p) =>
        p['exercises'][0]['sets'][0]['planned']['rest_seconds'] = 3601,
    'wrong load basis': (p) =>
        p['exercises'][0]['sets'][0]['planned']['load']['basis'] = 'assistance',
    'negative load': (p) =>
        p['exercises'][0]['sets'][0]['planned']['load']['value'] = '-1',
    'unsupported rep range': (p) =>
        p['exercises'][0]['sets'][0]['planned']['reps_range'] = [5, 8],
    'performed observation': (p) =>
        p['exercises'][0]['sets'][0]['observation'] = null,
    'duplicate set identity': (p) => p['exercises'][0]['sets'][1]['set_id'] =
        p['exercises'][0]['sets'][0]['set_id'],
  };
  for (final entry in invalid.entries) {
    test(
      'invalid planned content rejects ${entry.key} before persistence',
      () async {
        final payload = routinePlan().json;
        entry.value(payload);
        expect(
          () => RoutinePlan.fromJson(payload),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(await repo.routines(), isEmpty);
        expect(await count('workout_templates'), 0);
      },
    );
  }

  test(
    'oversized otherwise valid plan cannot be saved as an unstartable routine',
    () {
      final payload = routinePlan().json;
      final original = (payload['exercises'] as List).first as Json;
      payload['exercises'] = List.generate(50, (_) {
        final exercise = copyJson(original)
          ..['session_exercise_id'] = const Uuid().v4();
        exercise['sets'] = List.generate(
          100,
          (_) =>
              copyJson((original['sets'] as List).first as Json)
                ..['set_id'] = const Uuid().v4(),
        );
        return exercise;
      });
      expect(
        () => RoutinePlan.fromJson(payload),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );

  test(
    'same save identity/content is idempotent and stale different edits fail',
    () async {
      final first = await save();
      expect((await save()).templateId, first.templateId);
      expect((await save(revision: 1)).templateId, first.templateId);
      final second = await save(
        plan: routinePlan(name: 'Changed'),
        revision: 1,
      );
      expect(
        (await save(plan: second.plan, revision: 1)).templateId,
        second.templateId,
      );
      await expectLater(
        save(plan: routinePlan(name: 'Stale'), revision: 1),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(await count('workout_templates'), 2);
      expect((await repo.routine(routineId))!.plan.name, 'Changed');
    },
  );

  test(
    'concurrent local editors cannot silently overwrite each other',
    () async {
      await save();
      final outcomes = await Future.wait([
        for (final name in ['Editor A', 'Editor B'])
          save(
            plan: routinePlan(name: name),
            revision: 1,
          ).then<Object>((r) => r, onError: (Object e) => e),
      ]);
      expect(outcomes.whereType<SavedRoutine>().length, 1);
      expect(outcomes.whereType<WorkoutValidation>().length, 1);
      expect(await count('workout_templates'), 2);
      expect((await repo.routine(routineId))!.localRevision, 2);
    },
  );

  test(
    'owner separation and local sign-out apply to every routine operation',
    () async {
      final saved = await save();
      final wrong = WorkoutRepository(db, otherOwner);
      addTearDown(wrong.dispose);
      await expectLater(wrong.routines(), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        wrong.routine(routineId),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        wrong.saveRoutine(
          id: routineId,
          expectedRevision: 1,
          plan: routinePlan(name: 'Foreign'),
        ),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        wrong.startRoutine(
          routineId: routineId,
          templateId: saved.templateId,
          attemptId: attemptId,
          timezone: 'Asia/Kolkata',
        ),
        throwsA(isA<WorkoutValidation>()),
      );
      await repo.signOut();
      await expectLater(reopen(), throwsA(isA<WorkoutValidation>()));
      await expectLater(repo.routines(), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.routine(routineId),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(save(revision: 1), throwsA(isA<WorkoutValidation>()));
      await expectLater(start(saved), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.unlockVerifiedOwner(otherOwner),
        throwsA(isA<WorkoutValidation>()),
      );
      await repo.unlockVerifiedOwner(owner);
      expect((await repo.routine(routineId))!.templateId, saved.templateId);
    },
  );

  for (final table in ['workout_templates', 'routines']) {
    test('failed $table write rolls back root and immutable content after reopen', () async {
      final first = await save();
      final event = table == 'routines' ? 'UPDATE' : 'INSERT';
      await db.customStatement(
        "CREATE TRIGGER fail_save BEFORE $event ON $table BEGIN SELECT RAISE(ABORT,'synthetic write failure'); END",
      );
      await expectLater(
        save(plan: routinePlan(name: 'Unsaved'), revision: 1),
        throwsA(anything),
      );
      await reopen();
      expect((await repo.routine(routineId))!.templateId, first.templateId);
      expect(await count('workout_templates'), 1);
      await db.customStatement('DROP TRIGGER fail_save');
      expect(
        (await save(
          plan: routinePlan(name: 'Retry'),
          revision: 1,
        )).localRevision,
        2,
      );
    });
  }

  test(
    'workout start freezes a separate plan and never invents observations',
    () async {
      final saved = await save();
      final id = await start(saved);
      final original = (await repo.workout(id))!;
      expect(allSets(original).every((s) => s['observation'] == null), true);
      expect(
        original['exercises'][0]['variant_id'],
        saved.plan.exercises.first['variant_id'],
      );
      expect(
        original['exercises'][0]['session_exercise_id'],
        isNot(saved.plan.exercises.first['session_exercise_id']),
      );
      await repo.commit(id, 'record_set', recordPayload(original));
      await repo.commit(id, 'complete_session', {});
      final historical = (await repo.workout(id))!;
      final next = await save(
        plan: routinePlan(name: 'Future only', reps: 9),
        revision: 1,
      );
      await reopen();
      expect(await repo.workout(id), historical);
      expect(
        await start(saved),
        id,
        reason:
            'Response loss retry must survive routine edits and completion.',
      );
      final nextId = await start(next, attempt: const Uuid().v4());
      expect(nextId, isNot(id));
      final fresh = (await repo.workout(nextId))!;
      expect(fresh['name'], 'Future only');
      expect(
        allSets(
          fresh,
        ).every((s) => s['observation'] == null && s['planned']['reps'] == 9),
        true,
      );
      expect(
        allSets(fresh)
            .map((s) => s['set_id'])
            .toSet()
            .intersection(allSets(historical).map((s) => s['set_id']).toSet()),
        isEmpty,
      );
    },
  );

  test(
    'concurrent same-attempt starts create exactly one workout and outbox head',
    () async {
      final saved = await save();
      final ids = await Future.wait([start(saved), start(saved)]);
      expect(ids.toSet().length, 1);
      expect(await count('sessions'), 1);
      expect(await count('outbox'), 1);
      expect(await count('routine_starts'), 1);
      await expectLater(
        start(saved, attempt: const Uuid().v4()),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(await count('routine_starts'), 1);
    },
  );

  test(
    'stale template and changed start binding fail without side effects',
    () async {
      final first = await save();
      final next = await save(plan: routinePlan(name: 'New'), revision: 1);
      await expectLater(start(first), throwsA(isA<WorkoutValidation>()));
      expect(await repo.workouts(), isEmpty);
      await start(next);
      await expectLater(start(first), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.startRoutine(
          routineId: routineId,
          templateId: next.templateId,
          attemptId: attemptId,
          timezone: 'UTC',
        ),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(await count('outbox'), 1);
    },
  );

  for (final table in ['outbox', 'routine_starts']) {
    test('failed $table insert rolls back the entire start and can retry once', () async {
      final saved = await save();
      await db.customStatement(
        "CREATE TRIGGER fail_start BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT,'synthetic start failure'); END",
      );
      await expectLater(start(saved), throwsA(anything));
      await reopen();
      for (final target in [
        'sessions',
        'exercises',
        'workout_sets',
        'outbox',
        'routine_starts',
      ]) {
        expect(await count(target), 0, reason: target);
      }
      await db.customStatement('DROP TRIGGER fail_start');
      final id = await start(saved);
      expect(await start(saved), id);
      expect(await count('outbox'), 1);
    });
  }

  test('routine-start workout uses existing synchronization without uploading routines', () async {
    final saved = await save();
    final id = await start(saved);
    final server = SyncServer();
    final sync = SyncCoordinator(repo, server);
    try {
      await sync.synchronize(force: true);
      expect(server.roots[id]!['name'], saved.plan.name);
      expect(await repo.pendingCount(), 0);
      expect(await count('routines'), 1);
      expect(await count('workout_templates'), 1);
    } finally {
      await sync.close();
    }
  });

  test(
    'authoritative account erasure removes routine versions and start bindings',
    () async {
      await start(await save());
      await repo.signOut();
      await repo.disableRemoteAccount();
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, owner);
      expect(await repo.remoteDisabled(), true);
      for (final table in [
        'routines',
        'workout_templates',
        'routine_starts',
        'sessions',
        'outbox',
      ]) {
        expect(await count(table), 0, reason: table);
      }
      await expectLater(repo.routines(), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.unlockVerifiedOwner(owner),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );

  test(
    'exact schema four migrates additively and preserves pending workout bytes',
    () async {
      repo.dispose();
      await db.close();
      file = File('${directory.path}/v4.sqlite');
      seedSchemaFour(file);
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, owner);
      await repo.initialize();
      final legacyId = fixture()['aggregate_id'] as String;
      final frozen = canonicalJson(fixture());
      expect(await repo.prepareHead(legacyId), frozen);
      expect((await repo.workout(legacyId))!['name'], 'Upper body foundation');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        5,
      );
      final saved = await save();
      await reopen();
      expect(await repo.prepareHead(legacyId), frozen);
      expect((await repo.routines()).single.templateId, saved.templateId);
      await expectLater(
        start(saved),
        throwsA(isA<WorkoutValidation>()),
        reason: 'Migration must retain the legacy active-session guard.',
      );
    },
  );

  test(
    'failed final migration DDL rolls back schema, version and pending bytes',
    () async {
      repo.dispose();
      await db.close();
      file = File('${directory.path}/failed-v4.sqlite');
      seedSchemaFour(file);
      final raw = native.sqlite3.open(file.path);
      raw.execute('CREATE INDEX routine_starts ON outbox(state)');
      raw.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, owner);
      await expectLater(repo.initialize(), throwsA(anything));
      repo.dispose();
      await db.close();
      final failed = native.sqlite3.open(file.path);
      try {
        expect(failed.select('PRAGMA user_version').single.values.single, 4);
        expect(
          failed.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('routines','workout_templates','routine_starts')",
          ),
          isEmpty,
        );
        expect(
          failed.select(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='local_identity_owner'",
          ),
          isEmpty,
        );
        expect(
          failed.select('SELECT frozen_body FROM outbox').single['frozen_body'],
          canonicalJson(fixture()),
        );
        failed.execute('DROP INDEX routine_starts');
      } finally {
        failed.close();
      }
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, owner);
      await repo.initialize();
      expect(
        await repo.prepareHead(fixture()['aggregate_id'] as String),
        canonicalJson(fixture()),
      );
      expect(await repo.routines(), isEmpty);
    },
  );

  test(
    'edits during an active workout cannot modify its plan or recorded work',
    () async {
      final saved = await save();
      final id = await start(saved);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      final active = (await repo.workout(id))!;
      await save(plan: routinePlan(name: 'Next time', reps: 12), revision: 1);
      await reopen();
      expect(await repo.workout(id), active);
      expect(allSets(active).first['observation']['actual']['reps'], 5);
      expect(allSets(active).first['planned']['reps'], 5);
      expect(
        (await repo.routine(routineId))!
            .plan
            .exercises
            .first['sets'][0]['planned']['reps'],
        12,
      );
    },
  );

  test(
    'routine listing has bounded database read round trips across 50 roots',
    () async {
      repo.dispose();
      await db.close();
      final counter = CountReads();
      db = TrainingDatabase(
        NativeDatabase.createInBackground(
          file,
          setup: (sqlite) => sqlite.execute(
            'PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;',
          ),
        ).interceptWith(counter),
      );
      repo = WorkoutRepository(db, owner);
      await repo.initialize();
      for (var i = 0; i < 50; i++) {
        await repo.saveRoutine(
          id: repo.newId(),
          expectedRevision: 0,
          plan: routinePlan(name: 'Routine $i'),
        );
      }
      counter.reads = 0;
      final saved = await repo.routines();
      expect(saved.map((r) => r.plan.name), [
        for (var i = 49; i >= 0; i--) 'Routine $i',
      ]);
      expect(
        counter.reads,
        lessThan(12),
        reason: 'Loading a routine list must not issue one isolate query for each root.',
      );
    },
  );

  test('working backoff and ordinary warmup plans remain valid', () async {
    final payload = routinePlan().json;
    payload['exercises'][0]['sets'][0]['set_purpose'] = 'backoff';
    payload['exercises'][0]['sets'][1]['set_class'] = 'warmup';
    final saved = await save(plan: RoutinePlan.fromJson(payload));
    final id = await start(saved);
    expect(allSets((await repo.workout(id))!).first['set_purpose'], 'backoff');
    expect(
      allSets((await repo.workout(id))!).elementAt(1)['set_class'],
      'warmup',
    );
  });

  test('inconsistent local root metadata fails closed without hiding or erasing content', () async {
    final saved = await save();
    await db.customStatement('UPDATE routines SET local_revision=2');
    await expectLater(
      repo.routine(routineId),
      throwsA(isA<WorkoutValidation>()),
    );
    await expectLater(repo.routines(), throwsA(isA<WorkoutValidation>()));
    await expectLater(start(saved), throwsA(isA<WorkoutValidation>()));
    expect(await count('workout_templates'), 1);
    expect(await count('outbox'), 0);
    await db.customStatement('UPDATE routines SET local_revision=1');
    expect((await repo.routine(routineId))!.templateId, saved.templateId);
  });

  test('separate owner files can use the same routine identity without sharing data', () async {
    await save();
    repo.dispose();
    await db.close();
    final firstFile = file;
    file = File('${directory.path}/other.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, otherOwner);
    await repo.initialize();
    expect(await repo.routine(routineId), isNull);
    await save(plan: routinePlan(name: 'Private owner B'));
    expect((await repo.routines()).single.plan.name, 'Private owner B');
    repo.dispose();
    await db.close();
    file = firstFile;
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
    expect((await repo.routines()).single.plan.name, 'Upper body');
    await expectLater(
      db.customStatement(
        'INSERT INTO routines(id,owner_id,local_revision) VALUES(?,?,0)',
        [const Uuid().v4(), otherOwner],
      ),
      throwsA(anything),
    );
  });

  for (final basis in [
    'total_external',
    'per_implement',
    'machine_stack',
    'added_bodyweight',
    'assistance',
    'bodyweight_only',
  ]) {
    test(
      '$basis preserves optional targets and does not fabricate actual values',
      () async {
        final payload = routinePlan().json;
        payload['exercises'][0]['loading_basis'] = basis;
        for (final item in payload['exercises'][0]['sets'] as List) {
          item['planned']['reps'] = null;
          item['planned']['load'] = basis == 'bodyweight_only'
              ? null
              : {'value': '12.500', 'unit': 'lb', 'basis': basis};
        }
        final saved = await save(plan: RoutinePlan.fromJson(payload));
        final id = await start(saved);
        final workout = (await repo.workout(id))!;
        expect(
          allSets(workout).every(
            (s) => s['observation'] == null && s['planned']['reps'] == null,
          ),
          true,
        );
        expect(
          allSets(workout).first['planned']['load'],
          payload['exercises'][0]['sets'][0]['planned']['load'],
        );
        await expectLater(
          repo.commit(id, 'complete_session', {}),
          throwsA(isA<WorkoutValidation>()),
        );
      },
    );
  }
}
