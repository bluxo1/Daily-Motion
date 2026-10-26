import 'exercise_history.dart';
import 'workout.dart';

enum MeasuredMetric { load, repetitions }

/// Original decimal/unit, with a finite approximate coordinate for painting.
/// The coordinate is never written back or used as a performance achievement.
class MeasuredLoad {
  final String original;
  final String unit;
  final double coordinate;
  const MeasuredLoad(this.original, this.unit, this.coordinate);
}

class MeasuredPoint {
  final ExerciseKey identity;
  final String workoutId;
  final String exerciseId;
  final String setId;
  final String workoutName;
  final String exerciseName;
  final DateTime startedAt;
  final int exerciseOrdinal;
  final int setOrdinal;
  final String setClass;
  final String purpose;
  final String status;
  final int repetitions;
  final MeasuredLoad? load;
  final String? correctionReason;
  final bool conflict;

  const MeasuredPoint({
    required this.identity,
    required this.workoutId,
    required this.exerciseId,
    required this.setId,
    required this.workoutName,
    required this.exerciseName,
    required this.startedAt,
    required this.exerciseOrdinal,
    required this.setOrdinal,
    required this.setClass,
    required this.purpose,
    required this.status,
    required this.repetitions,
    required this.load,
    required this.correctionReason,
    required this.conflict,
  });

  (String, String, String) get source => (workoutId, exerciseId, setId);
  String originalValue(MeasuredMetric metric) =>
      metric == MeasuredMetric.load ? load!.original : repetitions.toString();
  double coordinate(MeasuredMetric metric) =>
      metric == MeasuredMetric.load ? load!.coordinate : repetitions.toDouble();
}

/// Rebuildable, detached measurements of one existing comparison identity.
/// Lists use workout start / stable workout ID / prescription instance/set order.
class MeasuredProgress {
  final ExerciseKey identity;
  final String name;
  final List<MeasuredPoint> repetitions;
  final Map<String, List<MeasuredPoint>> loads;
  final int unsupported;
  MeasuredProgress(
    this.identity,
    Iterable<MeasuredPoint> points,
    this.unsupported, {
    this.name = '',
  }) : repetitions = List.unmodifiable(points),
       loads = Map.unmodifiable({
         for (final unit in ['kg', 'lb'])
           if (points.any((p) => p.load?.unit == unit))
             unit: List<MeasuredPoint>.unmodifiable(
               points.where((p) => p.load?.unit == unit),
             ),
       });

  List<MeasuredPoint> series(MeasuredMetric metric, String? unit) =>
      metric == MeasuredMetric.repetitions
      ? repetitions
      : loads[unit] ?? const [];

  MeasuredWindow window(
    MeasuredMetric metric, {
    String? unit,
    int page = 0,
    int size = 80,
  }) {
    if (size < 1 || size > 80) throw ArgumentError.value(size, 'size');
    final all = series(metric, unit);
    final pages = (all.length / size).ceil();
    final selectedPage = pages == 0 ? 0 : page.clamp(0, pages - 1);
    final end = (all.length - selectedPage * size).clamp(0, all.length);
    final start = (end - size).clamp(0, end);
    return MeasuredWindow(
      metric,
      List.unmodifiable(all.sublist(start, end)),
      start,
      end,
      all.length,
      selectedPage,
      pages,
    );
  }
}

class MeasuredWindow {
  final MeasuredMetric metric;
  final List<MeasuredPoint> points;
  final int start;
  final int end;
  final int total;
  final int page;
  final int pages;
  const MeasuredWindow(
    this.metric,
    this.points,
    this.start,
    this.end,
    this.total,
    this.page,
    this.pages,
  );

  /// Equal dates/values occupy equal coordinates; never jitter or interpolate.
  List<({double x, double y})> get coordinates {
    if (points.isEmpty) return const [];
    var low = points.first.coordinate(metric);
    var high = low;
    for (final point in points) {
      final value = point.coordinate(metric);
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = points.last.startedAt
        .difference(points.first.startedAt)
        .inMicroseconds;
    return [
      for (final point in points)
        (
          x: span == 0
              ? 0.5
              : point.startedAt
                        .difference(points.first.startedAt)
                        .inMicroseconds /
                    span,
          y: high == low
              ? 0.5
              : (point.coordinate(metric) - low) / (high - low),
        ),
    ];
  }
}

MeasuredProgress buildMeasuredProgress(ExerciseHistory history) {
  final points = <MeasuredPoint>[];
  var unsupported = 0;
  final key = history.key;
  if (![
        'total_external',
        'per_implement',
        'machine_stack',
        'added_bodyweight',
        'assistance',
        'bodyweight_only',
      ].contains(key.basis) ||
      !['bilateral', 'per_side', 'alternating_total'].contains(key.reps) ||
      !['left', 'right', 'both', 'unspecified'].contains(key.side) ||
      key.variant.isEmpty) {
    return MeasuredProgress(
      key,
      const [],
      history.visits.fold(0, (n, v) => n + v.completedWorking.length),
      name: history.name,
    );
  }
  for (final visit in history.visits) {
    if (visit.workout['status'] != 'completed') continue;
    for (final occurrence in visit.occurrences) {
      if (exerciseKey(occurrence.exercise) != history.key) continue;
      for (final (ordinal, set) in occurrence.sets.indexed) {
        if (set['set_class'] != 'working' ||
            set['observation']?['execution_status'] != 'completed') {
          continue;
        }
        final actual = set['observation']?['actual'];
        final reps = actual is Json ? actual['reps'] : null;
        if (actual is! Json ||
            reps is! int ||
            reps < 1 ||
            reps > 999 ||
            actual['rep_convention'] != history.key.reps ||
            !isUtcInstant(visit.workout['started_at']) ||
            visit.workout['aggregate_id'] is! String ||
            occurrence.exercise['session_exercise_id'] is! String ||
            set['set_id'] is! String) {
          unsupported++;
          continue;
        }
        MeasuredLoad? load;
        final raw = actual['load'];
        if (raw != null) {
          if (raw is! Json || history.key.basis == 'bodyweight_only') {
            unsupported++;
            continue;
          }
          try {
            validateLoad(raw, history.key.basis);
            final numeric = double.tryParse(raw['value'] as String);
            if (numeric == null || !numeric.isFinite) {
              unsupported++;
              continue;
            }
            load = MeasuredLoad(
              raw['value'] as String,
              raw['unit'] as String,
              numeric,
            );
          } on WorkoutValidation {
            unsupported++;
            continue;
          }
        }
        points.add(
          MeasuredPoint(
            identity: history.key,
            workoutId: visit.workout['aggregate_id'] as String,
            exerciseId: occurrence.exercise['session_exercise_id'] as String,
            setId: set['set_id'] as String,
            workoutName: visit.workout['name'] as String,
            exerciseName: occurrence.exercise['name'] as String,
            startedAt: DateTime.parse(visit.workout['started_at'] as String)
                .toUtc(),
            exerciseOrdinal: occurrence.ordinal,
            setOrdinal: ordinal,
            setClass: 'working',
            purpose: set['set_purpose'] as String,
            status: 'completed',
            repetitions: reps,
            load: load,
            correctionReason:
                set['observation']['correction_reason'] as String?,
            conflict: visit.workout['conflict'] == true,
          ),
        );
      }
    }
  }
  points.sort((a, b) {
    final time = a.startedAt.compareTo(b.startedAt);
    if (time != 0) return time;
    final root = a.workoutId.compareTo(b.workoutId);
    if (root != 0) return root;
    final instance = a.exerciseOrdinal.compareTo(b.exerciseOrdinal);
    return instance != 0 ? instance : a.setOrdinal.compareTo(b.setOrdinal);
  });
  return MeasuredProgress(history.key, points, unsupported, name: history.name);
}
