import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_history.dart';
import '../domain/measured_progress.dart';
import 'exercise_history_provider.dart';
import 'workout_controller.dart';

/// Selected-exercise presentation only. Reuse the existing owner projection;
/// release the derived cache when its chart is no longer observed.
final measuredProgressProvider = FutureProvider.autoDispose
    .family<MeasuredProgress, ExerciseKey>((ref, identity) async {
      ref.watch(repositoryProvider);
      final index = await ref.watch(exerciseHistoryProvider.future);
      final history = index.byExercise[identity];
      if (history == null) return MeasuredProgress(identity, const [], 0);
      var sets = 0;
      for (final visit in history.visits) {
        for (final occurrence in visit.occurrences) {
          sets += occurrence.sets.length;
          if (sets > 2000) return compute(buildMeasuredProgress, history);
        }
      }
      return Future(() => buildMeasuredProgress(history));
    }, retry: (_, _) => null);
