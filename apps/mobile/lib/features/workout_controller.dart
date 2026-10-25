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
  Future<void> _pending = Future.value();

  @override
  Future<List<Json>> build() => ref.watch(repositoryProvider).workouts();

  Future<void> _refresh(WorkoutRepository target) async {
    final next = await AsyncValue.guard(target.workouts);
    if (ref.mounted && identical(ref.read(repositoryProvider), target)) {
      state = next;
    }
  }

  Future<void> refresh() => _refresh(repository);

  // Visible exercise editors share a UI command queue. Each command reads fresh
  // state after its predecessor and retains the repository selected at entry.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> start() {
    final target = repository;
    return _enqueue(() async {
      final id = await target.startFoundationWorkout();
      await _refresh(target);
      return id;
    });
  }

  Future<bool> record(
    String sessionId,
    Json exercise,
    Json item,
    Json entry, {
    String? reason,
  }) {
    final target = repository;
    final exerciseId = exercise['session_exercise_id'];
    final setId = item['set_id'];
    final values = copyJson(entry);
    return _enqueue(() async {
      final workout = await target.workout(sessionId);
      require(workout != null, 'Workout not found.');
      final matches = (workout!['exercises'] as List)
          .cast<Json>()
          .where((e) => e['session_exercise_id'] == exerciseId)
          .toList();
      require(matches.length == 1, 'Exercise not found.');
      final currentExercise = matches.single;
      final sets = (currentExercise['sets'] as List)
          .cast<Json>()
          .where((s) => s['set_id'] == setId)
          .toList();
      require(sets.length == 1, 'Set not found.');
      final current = sets.single;
      if (reason != null) {
        require(
          current['observation'] != null,
          'Only recorded sets can be corrected.',
        );
      }
      final status = values['execution_status'] as String;
      final load = (values['load'] as String).trim().replaceAll(',', '.');
      final effort = (values['effort'] as String).trim().replaceAll(',', '.');
      final payload = <String, dynamic>{
        'session_exercise_id': exerciseId,
        'set_id': setId,
        'execution_status': status,
        'actual': status == 'skipped'
            ? null
            : {
                'load': currentExercise['loading_basis'] == 'bodyweight_only'
                    ? null
                    : {
                        'value': load,
                        'unit': values['unit'],
                        'basis': currentExercise['loading_basis'],
                      },
                'reps': int.tryParse((values['reps'] as String).trim()),
                'rep_convention': currentExercise['rep_convention'],
                'effort': effort.isEmpty
                    ? null
                    : {
                        'scale': values['effort_scale'],
                        'value': effort,
                        'source': 'self_reported',
                      },
              },
        'completion_seq': reason == null
            ? completionSequence(workout) + 1
            : current['observation']['completion_seq'],
        'order_source': 'logged',
        'correction_reason': ?reason,
      };
      final saved = await target.commit(
        sessionId,
        reason == null ? 'record_set' : 'correct_set',
        payload,
      );
      await _refresh(target);
      return saved;
    });
  }

  Future<void> finish(String id, {bool abandon = false}) {
    final target = repository;
    return _enqueue(() async {
      await target.commit(
        id,
        abandon ? 'abandon_session' : 'complete_session',
        {},
      );
      await _refresh(target);
    });
  }
}
