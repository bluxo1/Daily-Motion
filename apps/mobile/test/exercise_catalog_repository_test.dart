import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'repository_test.dart' show owner, recordPayload;
import 'support/owned_fixture.dart';

CatalogDefinition customDefinition({
  String? variant,
  String? movement,
  String name = 'Private machine',
  CatalogLoading loading = CatalogLoading.machineStack,
  CatalogEquipment equipment = CatalogEquipment.machine,
  String setup = 'Machine A; seat 3',
}) => CatalogDefinition(
  movementId: movement ?? const Uuid().v4(),
  variantId: variant ?? const Uuid().v4(),
  revision: 1,
  name: name,
  equipment: equipment,
  setup: setup,
  category: MovementCategory.pull,
  loading: loading,
  repetitions: CatalogRepetitions.bilateral,
  side: CatalogSide.both,
  source: CatalogSource.privateCustom,
);

void main() {
  late Directory directory;
  late File file;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('catalog-repo-');
    file = File('${directory.path}/owner.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  });
  tearDown(() async {
    repo.dispose();
    await db.close();
    await deleteOwnedTemporaryDirectory(directory, 'catalog-repo-');
  });
  Future<void> reopen() async {
    repo.dispose();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  }

  Future<int> count() async =>
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM custom_exercise_definitions',
              )
              .getSingle())
          .read<int>('n');
  Future<SavedRoutine> plan(CatalogDefinition d, {String? id}) =>
      repo.saveRoutine(
        id: id ?? repo.newId(),
        expectedRevision: 0,
        plan: RoutinePlan(
          name: 'Catalog plan',
          exercises: [d.prescription(repo.newId), d.prescription(repo.newId)],
        ),
      );

  test('same catalog variant persists across two routines and repeated independent instances', () async {
    final d = curatedExercises.first;
    final a = await plan(d);
    final b = await plan(d);
    await reopen();
    final saved = await repo.routines();
    expect(saved, hasLength(2));
    expect(saved.map((s) => s.id).toSet(), {a.id, b.id});
    final instances = saved.expand((s) => s.plan.exercises).toList();
    expect(
      instances.map((e) => e['session_exercise_id']).toSet(),
      hasLength(4),
    );
    expect(instances.map(exerciseKey).toSet(), {
      exerciseKey(d.prescription(repo.newId)),
    });
    expect(await repo.pendingCount(), 0);
    expect(await repo.workouts(), isEmpty);
  });
  test('private definition create, rename and archive append immutable revisions across reopen', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final renamed = d.displayRevision(name: 'Renamed private machine');
    await repo.saveCustomExercise(definition: renamed, expectedRevision: 1);
    final archived = renamed.displayRevision(
      name: renamed.name,
      archived: true,
    );
    await repo.saveCustomExercise(definition: archived, expectedRevision: 2);
    await reopen();
    expect((await repo.customExercise(d.variantId))!.json, archived.json);
    expect(await count(), 3);
    final history = await db
        .customSelect(
          'SELECT definition FROM custom_exercise_definitions ORDER BY definition_revision',
        )
        .get();
    expect(jsonDecode(history.first.read<String>('definition')), d.json);
    expect(
      filterCatalog(
        await repo.exerciseCatalog(),
        source: CatalogSource.privateCustom,
      ),
      isEmpty,
    );
    expect(
      filterCatalog(
        await repo.exerciseCatalog(),
        source: CatalogSource.privateCustom,
        archived: true,
      ).single.variantId,
      d.variantId,
    );
    expect(await repo.pendingCount(), 0);
  });
  test('material changes cannot overwrite a variant; separate variants retain movement but separate history', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final changed = CatalogDefinition(
      movementId: d.movementId,
      variantId: d.variantId,
      revision: 2,
      name: d.name,
      equipment: CatalogEquipment.cable,
      setup: d.setup,
      category: d.category,
      loading: CatalogLoading.totalExternal,
      repetitions: d.repetitions,
      side: d.side,
      source: d.source,
    );
    await expectLater(
      repo.saveCustomExercise(definition: changed, expectedRevision: 1),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await count(), 1);
    final fork = customDefinition(
      movement: d.movementId,
      name: d.name,
      equipment: CatalogEquipment.cable,
      loading: CatalogLoading.totalExternal,
    );
    await repo.saveCustomExercise(definition: fork, expectedRevision: 0);
    expect(fork.movementId, d.movementId);
    expect(
      exerciseKey(fork.prescription(repo.newId)),
      isNot(exerciseKey(d.prescription(repo.newId))),
    );
  });
  test('renames, archives and new catalog revisions cannot rewrite started or completed workout snapshots', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final saved = await plan(d);
    final id = await repo.startRoutine(
      routineId: saved.id,
      templateId: saved.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    final entry = recordPayload((await repo.workout(id))!);
    entry['actual']['load']['basis'] = d.loading.wire;
    await repo.commit(id, 'record_set', entry);
    await repo.commit(id, 'complete_session', {});
    final frozen = await repo.prepareHead(id);
    final before = (await repo.workout(id))!;
    final renamed = d.displayRevision(
      name: 'Different display name',
      archived: true,
    );
    await repo.saveCustomExercise(definition: renamed, expectedRevision: 1);
    await reopen();
    expect(await repo.workout(id), before);
    expect(await repo.prepareHead(id), frozen);
    expect((await repo.routine(saved.id))!.plan.json, saved.plan.json);
    final index = buildExerciseHistory(await repo.workouts());
    expect(index.exercises, hasLength(1));
    expect(index.exercises.single.key, exerciseKey(d.prescription(repo.newId)));
    expect(index.exercises.single.latestRecorded.exercise['name'], d.name);
    final measured = buildMeasuredProgress(index.exercises.single);
    expect(measured.repetitions, hasLength(1));
    expect(measured.loads['kg']!.single.load!.original, '60');
    expect(measured.repetitions.single.workoutId, id);
  });
  test('exact response-loss retries and concurrent saves create one definition revision', () async {
    final d = customDefinition();
    final writes = await Future.wait([
      for (var i = 0; i < 4; i++)
        repo.saveCustomExercise(definition: d, expectedRevision: 0),
    ]);
    expect(writes.every((v) => v.revision == 1), isTrue);
    expect(await count(), 1);
    await reopen();
    expect(
      (await repo.saveCustomExercise(definition: d, expectedRevision: 0)).json,
      d.json,
    );
    final renamed = d.displayRevision(name: 'Another name');
    await repo.saveCustomExercise(definition: renamed, expectedRevision: 1);
    await expectLater(
      repo.saveCustomExercise(definition: d, expectedRevision: 0),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await count(), 2);
  });
  test('failed append rolls back and same definition can be retried without duplication', () async {
    final d = customDefinition();
    await db.customStatement(
      "CREATE TRIGGER fail_custom BEFORE INSERT ON custom_exercise_definitions BEGIN SELECT RAISE(ABORT,'private storage detail'); END",
    );
    await expectLater(
      repo.saveCustomExercise(definition: d, expectedRevision: 0),
      throwsA(anything),
    );
    expect(await count(), 0);
    await db.customStatement('DROP TRIGGER fail_custom');
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    expect(await count(), 1);
    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.data.values.single, 'ok');
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('wrong owner cannot read edit or erase private definitions and FK rejects cross-owner rows', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final wrong = WorkoutRepository(db, '20000000-0000-4000-8000-000000000002');
    try {
      await expectLater(
        wrong.exerciseCatalog(),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        wrong.customExercise(d.variantId),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        wrong.saveCustomExercise(definition: d, expectedRevision: 0),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(wrong.disableRemoteAccount(), throwsA(anything));
      await expectLater(
        db.customStatement(
          'INSERT INTO custom_exercise_definitions VALUES(?,?,1,?)',
          [wrong.ownerId, d.variantId, canonicalJson(d.json)],
        ),
        throwsA(anything),
      );
      expect(await count(), 1);
    } finally {
      wrong.dispose();
    }
  });
  test('sign-out locks private catalog without deleting it; disable erases all private revisions', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    await repo.signOut();
    await expectLater(
      repo.exerciseCatalog(),
      throwsA(isA<WorkoutValidation>()),
    );
    await expectLater(
      repo.saveCustomExercise(
        definition: d.displayRevision(name: 'Blocked'),
        expectedRevision: 1,
      ),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await count(), 1);
    await repo.unlockVerifiedOwner(owner);
    expect((await repo.customExercise(d.variantId))!.name, d.name);
    await repo.signOut();
    await repo.disableRemoteAccount();
    expect(await count(), 0);
    await expectLater(
      repo.exerciseCatalog(),
      throwsA(isA<WorkoutValidation>()),
    );
    await expectLater(
      repo.unlockVerifiedOwner(owner),
      throwsA(isA<WorkoutValidation>()),
    );
  });
  test(
    'curated identities cannot be impersonated by private definitions',
    () async {
      final d = customDefinition(variant: curatedExercises.first.variantId);
      await expectLater(
        repo.saveCustomExercise(definition: d, expectedRevision: 0),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(await count(), 0);
    },
  );
  test(
    'corrupt private definition fails safely without including stored content',
    () async {
      final d = customDefinition();
      await repo.saveCustomExercise(definition: d, expectedRevision: 0);
      await db.customStatement(
        'UPDATE custom_exercise_definitions SET definition=?',
        ['{"private":"do not display"}'],
      );
      await expectLater(
        repo.exerciseCatalog(),
        throwsA(
          isA<WorkoutValidation>().having(
            (e) => e.message,
            'sanitized',
            isNot(contains('do not display')),
          ),
        ),
      );
    },
  );
  test('curated display revision preserves historical names and one comparable measured series', () async {
    final d = curatedExercises.first;
    final initial = await plan(d);
    final first = await repo.startRoutine(
      routineId: initial.id,
      templateId: initial.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    await repo.commit(
      first,
      'record_set',
      recordPayload((await repo.workout(first))!),
    );
    await repo.commit(first, 'complete_session', {});
    final historyBefore = (await repo.workout(first))!;
    final frozen = await repo.prepareHead(first);
    final renamed = d.displayRevision(name: 'Updated curated display');
    final edited = await repo.saveRoutine(
      id: initial.id,
      expectedRevision: 1,
      plan: RoutinePlan(
        name: 'Next plan',
        exercises: [renamed.prescription(repo.newId)],
      ),
    );
    final second = await repo.startRoutine(
      routineId: edited.id,
      templateId: edited.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    await repo.commit(
      second,
      'record_set',
      recordPayload((await repo.workout(second))!, reps: 8),
    );
    await repo.commit(second, 'complete_session', {});
    await reopen();
    expect(await repo.workout(first), historyBefore);
    expect(await repo.prepareHead(first), frozen);
    final index = buildExerciseHistory(await repo.workouts());
    expect(index.exercises, hasLength(1));
    expect(index.exercises.single.names, {d.name, renamed.name});
    final measured = buildMeasuredProgress(index.exercises.single);
    expect(measured.repetitions, hasLength(2));
    expect(measured.repetitions.map((p) => p.workoutId).toSet(), {
      first,
      second,
    });
    expect(measured.repetitions.map((p) => p.repetitions).toSet(), {5, 8});
    expect(await count(), 0);
  });
  test('separate owner files never share private definitions even for the same supplied variant identity', () async {
    final d = customDefinition(name: 'Private owner A');
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final otherDb = TrainingDatabase.open(
      File('${directory.path}/other.sqlite'),
    );
    final other = WorkoutRepository(
      otherDb,
      '20000000-0000-4000-8000-000000000002',
    );
    try {
      await other.initialize();
      expect(await other.customExercise(d.variantId), isNull);
      final own = customDefinition(
        variant: d.variantId,
        name: 'Private owner B',
      );
      await other.saveCustomExercise(definition: own, expectedRevision: 0);
      expect((await repo.customExercise(d.variantId))!.name, d.name);
      expect((await other.customExercise(d.variantId))!.name, own.name);
      await other.signOut();
      await expectLater(
        other.exerciseCatalog(),
        throwsA(isA<WorkoutValidation>()),
      );
      expect((await repo.customExercise(d.variantId))!.name, d.name);
    } finally {
      other.dispose();
      await otherDb.close();
    }
  });
  test('simultaneous distinct display edits use CAS without silently overwriting either input', () async {
    final d = customDefinition();
    await repo.saveCustomExercise(definition: d, expectedRevision: 0);
    final results = await Future.wait([
      for (final name in ['Editor A', 'Editor B'])
        repo
            .saveCustomExercise(
              definition: d.displayRevision(name: name),
              expectedRevision: 1,
            )
            .then<Object>((v) => v, onError: (Object error) => error),
    ]);
    expect(results.whereType<CatalogDefinition>(), hasLength(1));
    expect(results.whereType<WorkoutValidation>(), hasLength(1));
    expect(await count(), 2);
    expect((await repo.customExercise(d.variantId))!.revision, 2);
  });
}
