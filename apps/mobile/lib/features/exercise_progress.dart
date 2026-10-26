import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_history.dart';
import '../domain/workout.dart';
import 'exercise_history_provider.dart';
import 'workout_presentation.dart';

void openExerciseHistory(
  BuildContext context,
  ExerciseKey identity,
  ValueChanged<String> onOpenWorkout,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) =>
        ExerciseHistoryScreen(identity: identity, onOpenWorkout: onOpenWorkout),
  ),
);

class HistoryReadError extends ConsumerWidget {
  const HistoryReadError({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Exercise history could not be loaded. Check account access or retry.',
      ),
      TextButton(
        onPressed: () => ref.invalidate(exerciseHistoryProvider),
        child: const Text('Retry exercise history'),
      ),
    ],
  );
}

class ExerciseProgress extends ConsumerStatefulWidget {
  final ValueChanged<String> onOpenWorkout;
  const ExerciseProgress({super.key, required this.onOpenWorkout});
  @override
  ConsumerState<ExerciseProgress> createState() => _ExerciseProgressState();
}

class _ExerciseProgressState extends ConsumerState<ExerciseProgress> {
  var search = '';
  var limit = 30;
  @override
  Widget build(BuildContext context) => ref
      .watch(exerciseHistoryProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Text('Loading exercise history…'),
        error: (_, _) => const HistoryReadError(),
        data: (index) {
          final exercises = index.exercises
              .where(
                (e) => e.names.any(
                  (n) => n.toLowerCase().contains(search.toLowerCase().trim()),
                ),
              )
              .toList();
          final nameCounts = <String, int>{};
          for (final e in index.exercises) {
            nameCounts.update(e.name, (n) => n + 1, ifAbsent: () => 1);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Exercise history',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Recorded observations, grouped by variant and measurement convention. No scores or predictions.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('exercise-search'),
                decoration: const InputDecoration(
                  labelText: 'Find an exercise',
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                onChanged: (value) => setState(() {
                  search = value;
                  limit = 30;
                }),
              ),
              const SizedBox(height: 12),
              if (index.byExercise.isEmpty)
                const Text(
                  'Record work and finish or abandon a workout to browse its exercises. Planned sets are not performed history.',
                )
              else if (exercises.isEmpty)
                const Text('No recorded exercise matches this search.'),
              for (final history in exercises.take(limit))
                Card(
                  key: ValueKey(history.key),
                  child: ListTile(
                    title: Text(history.name),
                    subtitle: Text(
                      '${exerciseConvention(history.latestRecorded.exercise)}\n'
                      '${history.recordedWorkouts} recorded workouts · latest ${workoutDate(history.latestRecorded.workout)}'
                      '${nameCounts[history.name]! > 1 ? '\nVariant ${history.key.variant}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openExerciseHistory(
                      context,
                      history.key,
                      widget.onOpenWorkout,
                    ),
                  ),
                ),
              if (exercises.length > limit)
                OutlinedButton(
                  onPressed: () => setState(() => limit += 30),
                  child: const Text('Show more exercises'),
                ),
            ],
          );
        },
      );
}

class PreviousPerformance extends ConsumerWidget {
  final Json exercise;
  final String sessionId;
  final ValueChanged<String> onOpenWorkout;
  const PreviousPerformance({
    super.key,
    required this.exercise,
    required this.sessionId,
    required this.onOpenWorkout,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: ref
        .watch(exerciseHistoryProvider)
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Text('Loading previous performance…'),
          error: (_, _) => const HistoryReadError(),
          data: (index) {
            final history = index.byExercise[exerciseKey(exercise)];
            final previous = history?.previous(excludingSession: sessionId);
            if (previous == null) {
              return const Text(
                'No previous comparable completed working sets. Log today’s work below.',
              );
            }
            final sets = previous.completedWorking.toList();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Previous performance · reference only'),
                    if (previous.workout['conflict'] == true)
                      const Text('Saved on this device · sync needs review'),
                    Text(
                      'Most recent completed workout: ${previous.workout['name']} · ${workoutDate(previous.workout)}',
                    ),
                    for (final (occurrence, set) in sets.take(3))
                      Text(
                        'Exercise ${occurrence.ordinal + 1}, set ${occurrence.sets.indexOf(set) + 1} · ${set['set_purpose']}\n${setSummary(set)}',
                      ),
                    if (sets.length > 3)
                      Text(
                        '${sets.length} completed working sets in this workout. Open history for all sets.',
                      ),
                    const Text(
                      'Past observations are not recorded performance today.',
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () => openExerciseHistory(
                            context,
                            history!.key,
                            onOpenWorkout,
                          ),
                          child: const Text('Exercise history'),
                        ),
                        TextButton(
                          onPressed: () => onOpenWorkout(
                            previous.workout['aggregate_id'] as String,
                          ),
                          child: const Text('Source workout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  final ExerciseKey identity;
  final ValueChanged<String> onOpenWorkout;
  const ExerciseHistoryScreen({
    super.key,
    required this.identity,
    required this.onOpenWorkout,
  });
  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends ConsumerState<ExerciseHistoryScreen> {
  var page = 0;
  var oldestFirst = false;
  var completedOnly = false;
  String? unit;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exercise history')),
    body: SafeArea(
      child: ref
          .watch(exerciseHistoryProvider)
          .when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () =>
                const Center(child: Text('Loading exercise history…')),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: HistoryReadError(),
            ),
            data: (index) {
              final history = index.byExercise[widget.identity];
              if (history == null) {
                return const Center(
                  child: Text('No recorded history for this exercise.'),
                );
              }
              final orderedVisits = oldestFirst
                  ? history.visits.reversed.toList()
                  : history.visits;
              final units = history.recordedUnits;
              final selectedUnit = units.contains(unit) ? unit : null;
              bool matchesSet(ExerciseVisit visit, Json set) {
                if (completedOnly &&
                    (visit.workout['status'] != 'completed' ||
                        set['set_class'] != 'working' ||
                        set['observation']?['execution_status'] !=
                            'completed')) {
                  return false;
                }
                return selectedUnit == null ||
                    (set['observation'] != null &&
                        observationUnit(set) == selectedUnit);
              }

              // Filter source workouts before slicing pages, using the same
              // predicate as their rows. Keep all context when filters are off.
              final visits = orderedVisits
                  .where(
                    (visit) =>
                        (!completedOnly && selectedUnit == null) ||
                        visit.occurrences.any(
                          (e) => e.sets.any((s) => matchesSet(visit, s)),
                        ),
                  )
                  .toList();
              final pages = (visits.length / 10).ceil();
              final currentPage = pages == 0 ? 0 : page.clamp(0, pages - 1);
              final selected = visits.skip(currentPage * 10).take(10);
              // Flatten only this page. ListView constructs visible rows lazily.
              final rows = <Widget Function(BuildContext)>[];
              for (final visit in selected) {
                rows.add(
                  (_) => Card(
                    key: ValueKey(
                      'source-workout-${visit.workout['aggregate_id']}',
                    ),
                    child: ListTile(
                      title: Text(
                        '${visit.workout['name']} · ${visit.workout['status']}',
                      ),
                      subtitle: Text(
                        '${workoutDate(visit.workout)}${visit.workout['conflict'] == true ? '\nSaved on this device · sync needs review' : ''}',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => widget.onOpenWorkout(
                        visit.workout['aggregate_id'] as String,
                      ),
                    ),
                  ),
                );
                for (final occurrence in visit.occurrences) {
                  rows.add(
                    (_) => Semantics(
                      header: true,
                      child: Text(
                        '${occurrence.exercise['name']} · exercise instance ${occurrence.ordinal + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                  for (final (ordinal, set) in occurrence.sets.indexed) {
                    final eligible =
                        visit.workout['status'] == 'completed' &&
                        set['set_class'] == 'working' &&
                        set['observation']?['execution_status'] == 'completed';
                    if (!matchesSet(visit, set)) continue;
                    rows.add(
                      (_) => Card(
                        key: ValueKey(
                          '${eligible ? 'performance' : 'observation'}-${visit.workout['aggregate_id']}-${set['set_id']}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Set ${ordinal + 1} · ${set['set_class']} · ${set['set_purpose']}\n${setSummary(set)}',
                          ),
                        ),
                      ),
                    );
                  }
                }
              }
              if (visits.isEmpty) {
                rows.add(
                  (_) => const Text(
                    'No source workouts match these filters. Show all outcomes or choose another recorded unit.',
                  ),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      key: ValueKey((
                        widget.identity,
                        currentPage,
                        oldestFirst,
                        completedOnly,
                        unit,
                      )),
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) => i == 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  history.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(
                                  exerciseConvention(
                                    history.latestRecorded.exercise,
                                  ),
                                ),
                                const Text(
                                  'Recorded values in original units. Workouts are ordered by start time; sets retain prescription order.',
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Oldest workouts first'),
                                  value: oldestFirst,
                                  onChanged: (v) => setState(() {
                                    oldestFirst = v;
                                    page = 0;
                                  }),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Completed working sets only',
                                  ),
                                  value: completedOnly,
                                  onChanged: (v) => setState(() {
                                    completedOnly = v;
                                    page = 0;
                                  }),
                                ),
                                DropdownButtonFormField<String>(
                                  key: ValueKey((
                                    units.join('|'),
                                    selectedUnit,
                                  )),
                                  initialValue: selectedUnit ?? 'all',
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Recorded load unit',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text(
                                        'All original units (individual values)',
                                      ),
                                    ),
                                    for (final u in units)
                                      DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    unit = v == 'all' ? null : v;
                                    page = 0;
                                  }),
                                ),
                                const ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text('How to read these observations'),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        'Read load and reps together. Units are never converted or combined; these are individual measurements, without scores or rankings. Warm-ups, partial/failed attempts, skipped and unperformed sets remain context. Only completed working sets in completed workouts are previous-performance references. Positive assistance is assistance, not added load. No recorded load is not zero load.',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: rows[i - 1](context),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: currentPage == 0
                              ? null
                              : () => setState(() => page = currentPage - 1),
                          child: const Text('Previous page'),
                        ),
                        Text(
                          visits.isEmpty
                              ? 'Workouts 0 of 0'
                              : 'Workouts ${currentPage * 10 + 1}–${(currentPage * 10 + 10).clamp(1, visits.length)} of ${visits.length}',
                        ),
                        TextButton(
                          onPressed: currentPage + 1 >= pages
                              ? null
                              : () => setState(() => page = currentPage + 1),
                          child: const Text('Next page'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    ),
  );
}
