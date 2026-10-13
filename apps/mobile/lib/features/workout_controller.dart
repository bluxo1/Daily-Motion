import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_repository.dart';
import '../domain/workout.dart';

final repositoryProvider = Provider<WorkoutRepository>(
  (ref) => throw StateError('A verified owner repository is required.'),
);
final workoutsProvider = AsyncNotifierProvider<WorkoutController, List<Json>>(
  WorkoutController.new,
);

class WorkoutController extends AsyncNotifier<List<Json>> {
  WorkoutRepository get repository => ref.read(repositoryProvider);

  @override
  Future<List<Json>> build() => repository.workouts();

  Future<void> refresh() async {
    state = await AsyncValue.guard(repository.workouts);
  }

  Future<String> start() async {
    final id = await repository.startFoundationWorkout();
    await refresh();
    return id;
  }

  Future<bool> record(
    String sessionId,
    Json exercise,
    Json item,
    Json entry, {
    String? reason,
  }) async {
    final workout = await repository.workout(sessionId);
    require(workout != null, 'Workout not found.');
    final status = entry['execution_status'] as String;
    final load = (entry['load'] as String).trim().replaceAll(',', '.');
    final effort = (entry['effort'] as String).trim().replaceAll(',', '.');
    final payload = <String, dynamic>{
      'session_exercise_id': exercise['session_exercise_id'],
      'set_id': item['set_id'],
      'execution_status': status,
      'actual': status == 'skipped'
          ? null
          : {
              'load': exercise['loading_basis'] == 'bodyweight_only'
                  ? null
                  : {
                      'value': load,
                      'unit': entry['unit'],
                      'basis': exercise['loading_basis'],
                    },
              'reps': int.tryParse((entry['reps'] as String).trim()),
              'rep_convention': exercise['rep_convention'],
              'effort': effort.isEmpty
                  ? null
                  : {
                      'scale': entry['effort_scale'],
                      'value': effort,
                      'source': 'self_reported',
                    },
            },
      'completion_seq': reason == null
          ? completionSequence(workout!) + 1
          : item['observation']['completion_seq'],
      'order_source': 'logged',
      'correction_reason': ?reason,
    };
    final saved = await repository.commit(
      sessionId,
      reason == null ? 'record_set' : 'correct_set',
      payload,
    );
    await refresh();
    return saved;
  }

  Future<void> finish(String id, {bool abandon = false}) async {
    await repository.commit(
      id,
      abandon ? 'abandon_session' : 'complete_session',
      {},
    );
    await refresh();
  }
}
