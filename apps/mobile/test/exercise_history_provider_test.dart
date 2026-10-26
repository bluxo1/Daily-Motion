import 'dart:async';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/exercise_history_provider.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_history_test.dart' show exercise, workout;
import 'multi_exercise_test.dart' show ownerA, ownerB;
import 'repository_test.dart' show recordPayload;

class HeldWorkouts extends WorkoutRepository {
  HeldWorkouts(super.db, super.ownerId);
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Json>> workouts() async {
    final source = await super.workouts();
    if (hold) {
      entered.complete();
      await release.future;
    }
    return source;
  }
}

class LargeProjection extends WorkoutRepository {
  final List<Json> source;
  LargeProjection(super.db, super.ownerId, this.source);
  @override
  Future<List<Json>> workouts() async => source;
}

Future<String> seed(WorkoutRepository repo) async {
  final id = await repo.startFoundationWorkout();
  await repo.commit(id, 'record_set', recordPayload((await repo.workout(id))!));
  await repo.commit(id, 'complete_session', {});
  return id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('an old owner read cannot publish history after the repository owner changes', () async {
    final aDB = TrainingDatabase(NativeDatabase.memory());
    final bDB = TrainingDatabase(NativeDatabase.memory());
    final a = HeldWorkouts(aDB, ownerA);
    final b = WorkoutRepository(bDB, ownerB);
    final c = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(a)],
    );
    try {
      await a.initialize();
      await b.initialize();
      final aId = await seed(a);
      final bId = await seed(b);
      // Match a mounted screen: Riverpod pauses unlistened provider dependency
      // subscriptions. Keep the index observed across repository transitions.
      c.listen(exerciseHistoryProvider, (_, _) {});
      final initial = await c.read(exerciseHistoryProvider.future);
      expect(
        initial.exercises.single.visits.single.workout['aggregate_id'],
        aId,
      );
      a.hold = true;
      final old = c.read(workoutsProvider.notifier).refresh();
      await a.entered.future;
      c.updateOverrides([repositoryProvider.overrideWithValue(b)]);
      final current = await c.read(exerciseHistoryProvider.future);
      expect(
        current.exercises.single.visits.single.workout['aggregate_id'],
        bId,
      );
      a.release.complete();
      await old;
      expect(
        (await c.read(exerciseHistoryProvider.future))
            .exercises
            .single
            .visits
            .single
            .workout['aggregate_id'],
        bId,
      );
      expect(await a.workout(aId), isNotNull);
    } finally {
      if (!a.release.isCompleted) a.release.complete();
      c.dispose();
      a.dispose();
      b.dispose();
      await aDB.close();
      await bDB.close();
    }
  });

  test('sign-out lock and authoritative account disable never retain a usable history index', () async {
    final db = TrainingDatabase(NativeDatabase.memory());
    final repo = WorkoutRepository(db, ownerA);
    final c = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    try {
      await repo.initialize();
      await seed(repo);
      c.listen(exerciseHistoryProvider, (_, _) {});
      expect(
        (await c.read(exerciseHistoryProvider.future)).exercises,
        hasLength(1),
      );
      await repo.signOut();
      await c.read(workoutsProvider.notifier).refresh();
      await expectLater(
        c.read(exerciseHistoryProvider.future),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(c.read(exerciseHistoryProvider).hasError, isTrue);
      await repo.unlockVerifiedOwner(ownerA);
      await c.read(workoutsProvider.notifier).refresh();
      expect(
        (await c.read(exerciseHistoryProvider.future)).exercises,
        hasLength(1),
      );
      await repo.disableRemoteAccount();
      await c.read(workoutsProvider.notifier).refresh();
      await expectLater(
        c.read(exerciseHistoryProvider.future),
        throwsA(isA<WorkoutValidation>()),
      );
      expect(c.read(exerciseHistoryProvider).hasError, isTrue);
      expect(
        (await db
                .customSelect('SELECT count(*) AS n FROM sessions')
                .getSingle())
            .read<int>('n'),
        0,
      );
    } finally {
      c.dispose();
      repo.dispose();
      await db.close();
    }
  });

  test('large histories pass through the real isolate builder without losing repeated instances or sources', () async {
    final db = TrainingDatabase(NativeDatabase.memory());
    final source = [
      for (var i = 0; i < 350; i++)
        workout('root-$i', [
          for (var j = 0; j < 7; j++) exercise(variant: 'variant-$j'),
        ]),
    ];
    final repo = LargeProjection(db, ownerA, source);
    final c = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    try {
      c.listen(exerciseHistoryProvider, (_, _) {});
      final before = copyJson(source.first);
      final index = await c.read(exerciseHistoryProvider.future);
      expect(index.exercises, hasLength(7));
      expect(index.exercises.every((e) => e.visits.length == 350), isTrue);
      expect(source.first, before);
      expect(
        index.exercises.first.visits.expand((v) => v.completedWorking),
        hasLength(350),
      );
    } finally {
      c.dispose();
      repo.dispose();
      await db.close();
    }
  });
}
