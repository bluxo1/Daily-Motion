import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/exercise_history_provider.dart';
import 'package:daily_motion/features/measured_progress_provider.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_history_provider_test.dart'
    show HeldWorkouts, LargeProjection, seed;
import 'exercise_history_test.dart' show exercise, workout;
import 'multi_exercise_test.dart' show ownerA, ownerB;
import 'support/owned_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large selected histories cross the worker boundary without losing sources or original decimals', () async {
    final db = TrainingDatabase(NativeDatabase.memory());
    final e = exercise(load: '9999999.999999');
    final source = [
      for (var i = 0; i < 2600; i++) workout('source-$i', [copyJson(e)]),
    ];
    final repo = LargeProjection(db, ownerA, source);
    final c = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final provider = measuredProgressProvider(exerciseKey(e));
    final sub = c.listen(provider, (_, _) {});
    try {
      final model = await c.read(provider.future);
      expect(model.repetitions, hasLength(2600));
      expect(model.repetitions.map((p) => p.source).toSet(), hasLength(2600));
      expect(
        model.loads['kg']!.every((p) => p.load!.original == '9999999.999999'),
        isTrue,
      );
      expect(model.window(MeasuredMetric.repetitions).points, hasLength(80));
      expect(
        model
            .window(MeasuredMetric.repetitions)
            .coordinates
            .every((p) => p.x.isFinite && p.y.isFinite),
        isTrue,
      );
      expect(
        c.read(exerciseHistoryProvider).requireValue.exercises,
        hasLength(1),
      );
    } finally {
      sub.close();
      c.dispose();
      repo.dispose();
      await db.close();
    }
  });

  test('old owner completion cannot republish points after a real file-backed owner switch', () async {
    final directory = Directory.systemTemp.createTempSync('measured-owner-');
    final aDB = TrainingDatabase(
      NativeDatabase(File('${directory.path}/a.sqlite')),
    );
    final bDB = TrainingDatabase(
      NativeDatabase(File('${directory.path}/b.sqlite')),
    );
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
      final aWorkout = (await a.workout(aId))!;
      final identity = exerciseKey(aWorkout['exercises'][0] as Json);
      final provider = measuredProgressProvider(identity);
      final observed = c.listen(provider, (_, _) {});
      expect((await c.read(provider.future)).repetitions.single.workoutId, aId);
      a.hold = true;
      final previous = c.read(workoutsProvider.notifier).refresh();
      await a.entered.future;
      c.updateOverrides([repositoryProvider.overrideWithValue(b)]);
      expect((await c.read(provider.future)).repetitions.single.workoutId, bId);
      a.release.complete();
      await previous;
      expect((await c.read(provider.future)).repetitions.single.workoutId, bId);
      observed.close();
    } finally {
      if (!a.release.isCompleted) a.release.complete();
      c.dispose();
      a.dispose();
      b.dispose();
      await aDB.close();
      await bDB.close();
      await deleteOwnedTemporaryDirectory(directory, 'measured-owner-');
    }
  });

  test(
    'lock and authoritative erasure invalidate a file-backed measured cache',
    () async {
      final directory = Directory.systemTemp.createTempSync('measured-locked-');
      final db = TrainingDatabase(
        NativeDatabase(File('${directory.path}/owner.sqlite')),
      );
      final repo = WorkoutRepository(db, ownerA);
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      try {
        await repo.initialize();
        final id = await seed(repo);
        final w = (await repo.workout(id))!;
        final provider = measuredProgressProvider(
          exerciseKey(w['exercises'][0] as Json),
        );
        final sub = c.listen(provider, (_, _) {});
        expect((await c.read(provider.future)).repetitions, hasLength(1));
        await c.pump();
        await repo.signOut();
        await c.read(workoutsProvider.notifier).refresh();
        await expectLater(
          c.read(provider.future),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(c.read(provider).hasError, isTrue);
        await repo.unlockVerifiedOwner(ownerA);
        await c.read(workoutsProvider.notifier).refresh();
        expect((await c.read(provider.future)).repetitions, hasLength(1));
        await repo.disableRemoteAccount();
        await c.read(workoutsProvider.notifier).refresh();
        await expectLater(
          c.read(provider.future),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(c.read(provider).hasError, isTrue);
        expect(await db.customSelect('SELECT * FROM sessions').get(), isEmpty);
        sub.close();
      } finally {
        c.dispose();
        repo.dispose();
        await db.close();
        await deleteOwnedTemporaryDirectory(directory, 'measured-locked-');
      }
    },
  );
}
