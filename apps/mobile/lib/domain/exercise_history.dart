import 'workout.dart';

/// The projection contract supplies variant identity, not a separate equipment
/// or setup identity. A name is deliberately absent from this comparison key.
typedef ExerciseKey = ({
  String variant,
  String basis,
  String reps,
  String side,
});

ExerciseKey exerciseKey(Json exercise) => (
  variant: exercise['variant_id'] as String,
  basis: exercise['loading_basis'] as String,
  reps: exercise['rep_convention'] as String,
  side: exercise['side'] as String? ?? 'unspecified',
);

class ExerciseOccurrence {
  final Json workout;
  final Json exercise;
  final int ordinal;
  const ExerciseOccurrence(this.workout, this.exercise, this.ordinal);
  List<Json> get sets => (exercise['sets'] as List).cast<Json>();
  bool get recorded => sets.any((s) => s['observation'] != null);
  Iterable<Json> get completedWorking => sets.where(
    (s) =>
        s['set_class'] == 'working' &&
        s['observation']?['execution_status'] == 'completed',
  );
}

class ExerciseVisit {
  final Json workout;
  final List<ExerciseOccurrence> occurrences;
  ExerciseVisit(this.workout, Iterable<ExerciseOccurrence> occurrences)
    : occurrences = List.unmodifiable(occurrences);
  bool get recorded => occurrences.any((e) => e.recorded);
  Iterable<(ExerciseOccurrence, Json)> get completedWorking sync* {
    if (workout['status'] != 'completed') return;
    for (final occurrence in occurrences) {
      for (final set in occurrence.completedWorking) {
        yield (occurrence, set);
      }
    }
  }
}

class ExerciseHistory {
  final ExerciseKey key;

  /// Newest source workout first, never correction-event time. Repeated
  /// instances stay separate inside their original source workout.
  final List<ExerciseVisit> visits;
  late final ExerciseOccurrence latestRecorded;
  late final String name;
  late final Set<String> names;
  late final int recordedWorkouts;
  late final List<String> recordedUnits;
  late final List<ExerciseVisit> _references;
  ExerciseHistory(this.key, Iterable<ExerciseVisit> visits)
    : visits = List.unmodifiable(visits) {
    // Compute browsing metadata with the index, including on its worker isolate.
    latestRecorded = this.visits
        .expand((v) => v.occurrences)
        .firstWhere((e) => e.recorded);
    name = latestRecorded.exercise['name'] as String;
    names = Set.unmodifiable({
      for (final v in this.visits)
        for (final e in v.occurrences) e.exercise['name'] as String,
    });
    recordedWorkouts = this.visits.where((v) => v.recorded).length;
    recordedUnits = List.unmodifiable(
      {
        for (final v in this.visits)
          for (final e in v.occurrences)
            for (final s in e.sets)
              if (s['observation'] != null) observationUnit(s),
      }.toList()..sort(),
    );
    _references = List.unmodifiable(
      this.visits.where((v) => v.completedWorking.isNotEmpty),
    );
  }

  ExerciseVisit? previous({String? excludingSession}) {
    for (final visit in _references) {
      if (visit.workout['aggregate_id'] != excludingSession) {
        return visit;
      }
    }
    return null;
  }
}

/// A rebuildable read model over the latest effective owner-scoped projection.
/// No outbox or historical-observation log is accumulated into this index.
class ExerciseHistoryIndex {
  final Map<ExerciseKey, ExerciseHistory> byExercise;
  final List<ExerciseHistory> exercises;
  ExerciseHistoryIndex(Map<ExerciseKey, ExerciseHistory> entries)
    : byExercise = Map.unmodifiable(entries),
      exercises = List.unmodifiable(
        entries.values.toList()..sort(
          (a, b) =>
              DateTime.parse(b.latestRecorded.workout['started_at'] as String)
                  .compareTo(
                    DateTime.parse(
                      a.latestRecorded.workout['started_at'] as String,
                    ),
                  ),
        ),
      );
}

ExerciseHistoryIndex buildExerciseHistory(List<Json> workouts) {
  final historical =
      workouts
          .where(
            (w) => w['status'] == 'completed' || w['status'] == 'abandoned',
          )
          .toList()
        ..sort((a, b) {
          final byTime = DateTime.parse(b['started_at'] as String)
              .compareTo(DateTime.parse(a['started_at'] as String));
          return byTime != 0
              ? byTime
              : (a['aggregate_id'] as String).compareTo(
                  b['aggregate_id'] as String,
                );
        });
  final grouped = <ExerciseKey, List<ExerciseVisit>>{};
  for (final workout in historical) {
    final instances = <ExerciseKey, List<ExerciseOccurrence>>{};
    for (final (ordinal, exercise)
        in (workout['exercises'] as List).cast<Json>().indexed) {
      instances
          .putIfAbsent(exerciseKey(exercise), () => [])
          .add(ExerciseOccurrence(workout, exercise, ordinal));
    }
    for (final MapEntry(:key, :value) in instances.entries) {
      grouped.putIfAbsent(key, () => []).add(ExerciseVisit(workout, value));
    }
  }
  return ExerciseHistoryIndex({
    for (final MapEntry(:key, :value) in grouped.entries)
      if (value.any((v) => v.recorded)) key: ExerciseHistory(key, value),
  });
}

/// Preserve original units. These are filters, not conversions or rankings.
String observationUnit(Json set) {
  final actual = set['observation']?['actual'] as Json?;
  return actual?['load']?['unit'] as String? ?? 'no recorded load';
}
