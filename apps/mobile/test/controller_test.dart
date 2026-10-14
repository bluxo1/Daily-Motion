import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingReadRepository extends WorkoutRepository {
  bool failRead = false;
  FailingReadRepository(super.db, super.ownerId);
  @override
  Future<List<Json>> workouts() async {
    if (failRead) throw StateError('synthetic read failure');
    return super.workouts();
  }
}

void main() {
  test(
    'a failed screen refresh cannot turn a durable save into an unsaved result',
    () async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final repo = FailingReadRepository(
        db,
        '20000000-0000-4000-8000-000000000001',
      );
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      await container.read(workoutsProvider.future);
      final controller = container.read(workoutsProvider.notifier);
      final id = await controller.start();
      final workout = (await repo.workout(id))!;
      final exercise = (workout['exercises'] as List).first as Json;
      final item = (exercise['sets'] as List).first as Json;
      repo.failRead = true;
      expect(
        await controller.record(id, exercise, item, {
          'load': '60',
          'reps': '5',
          'effort': '',
          'effort_scale': 'rir',
          'unit': 'kg',
          'execution_status': 'completed',
        }),
        isTrue,
      );
      expect(container.read(workoutsProvider).hasError, isTrue);
      expect(
        allSets((await repo.workout(id))!)
            .first['observation']['actual']['reps'],
        5,
      );
      container.dispose();
      await db.close();
    },
  );
}
