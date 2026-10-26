import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_history.dart';
import '../domain/workout.dart';
import 'workout_controller.dart';

/// One disposable index per owner/projection refresh, shared by all exercise
/// widgets. Large histories are indexed away from the UI isolate.
final exerciseHistoryProvider = FutureProvider<ExerciseHistoryIndex>((
  ref,
) async {
  ref.watch(repositoryProvider);
  final source = ref.watch(workoutsProvider);
  if (source.hasError) {
    Error.throwWithStackTrace(source.error!, source.stackTrace!);
  }
  final workouts = source.isLoading
      ? await ref.watch(workoutsProvider.future)
      : source.requireValue;
  var sets = 0;
  for (final workout in workouts) {
    for (final exercise in (workout['exercises'] as List).cast<Json>()) {
      sets += (exercise['sets'] as List).length;
      if (sets > 2000) return compute(buildExerciseHistory, workouts);
    }
  }
  // An async boundary keeps indexing out of the widget build itself.
  return Future(() => buildExerciseHistory(workouts));
}, retry: (_, _) => null);
