import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_history.dart';
import '../domain/measured_progress.dart';
import '../sync/coordinator.dart';
import 'measured_progress_provider.dart';
import 'sync_provider.dart';
import 'workout_controller.dart';
import 'workout_presentation.dart';

class MeasuredRecordsScreen extends ConsumerStatefulWidget {
  final ExerciseKey identity;
  final ValueChanged<String> onOpenWorkout;
  const MeasuredRecordsScreen({
    super.key,
    required this.identity,
    required this.onOpenWorkout,
  });
  @override
  ConsumerState<MeasuredRecordsScreen> createState() =>
      _MeasuredRecordsScreenState();
}

class _MeasuredRecordsScreenState extends ConsumerState<MeasuredRecordsScreen> {
  String? unit;
  var page = 0;
  @override
  void didUpdateWidget(covariant MeasuredRecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      unit = null;
      page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Measured records')),
      body: SafeArea(
        // The current route must observe disable while Home is offstage too.
        child:
            ref.watch(syncStatusProvider).value?.phase ==
                SyncPhase.accountDisabled
            ? const Center(
                child: Text('This account is unavailable. Return to sign in.'),
              )
            : ref
                  .watch(measuredProgressProvider(widget.identity))
                  .when(
                    skipLoadingOnRefresh: false,
                    skipLoadingOnReload: false,
                    loading: () =>
                        const Center(child: Text('Loading measured records…')),
                    error: (_, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Measured records could not be loaded. Check account access or retry.',
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(workoutsProvider.notifier)
                                  .refresh();
                              if (context.mounted &&
                                  identical(
                                    ref.read(repositoryProvider),
                                    owner,
                                  )) {
                                ref.invalidate(
                                  measuredProgressProvider(widget.identity),
                                );
                              }
                            },
                            child: const Text('Retry measured records'),
                          ),
                        ],
                      ),
                    ),
                    data: (data) {
                      final book = data.records;
                      final units = book.repetitionsAtLoad.keys.toList();
                      final selectedUnit = units.contains(unit)
                          ? unit
                          : units.firstOrNull;
                      final rows =
                          book.repetitionsAtLoad[selectedUnit] ??
                          const <MeasuredRecord>[];
                      final pages = (rows.length / 20).ceil();
                      final selectedPage = pages == 0
                          ? 0
                          : page.clamp(0, pages - 1);
                      final start = selectedPage * 20;
                      final end = (start + 20).clamp(0, rows.length);
                      final weightOnly =
                          widget.identity.basis == 'bodyweight_only';
                      final assist = widget.identity.basis == 'assistance';
                      Widget record(
                        MeasuredRecord entry, {
                        required bool highest,
                      }) {
                        final point = entry.source;
                        final quantity = point.load == null
                            ? 'bodyweight only'
                            : '${point.load!.original} ${point.load!.unit}';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  highest
                                      ? quantity
                                      : '${point.repetitions} reps · $quantity',
                                ),
                                if (highest)
                                  Text(
                                    '${point.repetitions} completed repetitions support this load.',
                                  ),
                                Text(
                                  '${point.workoutName} · ${point.exerciseName}',
                                ),
                                Text(
                                  workoutDate({
                                    'started_at': point.startedAt
                                        .toIso8601String(),
                                  }),
                                ),
                                Text(
                                  'Exercise ${point.exerciseOrdinal + 1}, set ${point.setOrdinal + 1} · ${point.purpose}',
                                ),
                                if (entry.ties > 1)
                                  Text(
                                    '${entry.ties} supporting sets tie; earliest source shown.',
                                  ),
                                if (point.correctionReason != null)
                                  Text('Corrected: ${point.correctionReason}'),
                                if (point.conflict)
                                  const Text(
                                    'Source workout has a synchronization conflict.',
                                  ),
                                TextButton(
                                  onPressed: () {
                                    if (identical(
                                          ref.read(repositoryProvider),
                                          owner,
                                        ) &&
                                        ref
                                                .read(syncStatusProvider)
                                                .value
                                                ?.phase !=
                                            SyncPhase.accountDisabled) {
                                      widget.onOpenWorkout(point.workoutId);
                                    }
                                  },
                                  child: const Text('Open source workout'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        key: ValueKey((
                          widget.identity,
                          selectedUnit,
                          selectedPage,
                        )),
                        padding: const EdgeInsets.all(16),
                        itemCount: end - start + 1,
                        itemBuilder: (_, index) => index > 0
                            ? record(rows[start + index - 1], highest: false)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    data.name.isEmpty
                                        ? 'No recorded history for this exercise.'
                                        : data.name,
                                  ),
                                  Text(
                                    exerciseConvention({
                                      'loading_basis': widget.identity.basis,
                                      'rep_convention': widget.identity.reps,
                                      'side': widget.identity.side,
                                    }),
                                  ),
                                  const Text(
                                    'Current saved completed working sets only. May include pending changes. No estimates or rankings; read load and reps together. Dates are workout starts, not physical set execution times.',
                                  ),
                                  if (data.unsupported > 0)
                                    Text(
                                      '${data.unsupported} unsupported observations are excluded. Check Source history for context.',
                                    ),
                                  if (units.isNotEmpty)
                                    DropdownButtonFormField<String>(
                                      key: ValueKey((
                                        widget.identity,
                                        selectedUnit,
                                      )),
                                      initialValue: selectedUnit,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Record load unit',
                                      ),
                                      items: [
                                        for (final value in units)
                                          DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                      ],
                                      onChanged: (value) => setState(() {
                                        unit = value;
                                        page = 0;
                                      }),
                                    ),
                                  if (assist)
                                    const Text(
                                      'Positive assistance is not lifted load. No highest-load achievement is awarded.',
                                    ),
                                  if (!weightOnly && !assist) ...[
                                    Semantics(
                                      header: true,
                                      child: const Text(
                                        'Highest positive recorded load',
                                      ),
                                    ),
                                    if (book.highestLoads[selectedUnit]
                                        case final entry?)
                                      record(entry, highest: true)
                                    else
                                      const Text(
                                        'No positive external load recorded. Zero remains a recorded value, not a load achievement.',
                                      ),
                                  ],
                                  if (weightOnly) ...[
                                    Semantics(
                                      header: true,
                                      child: const Text(
                                        'Most recorded bodyweight repetitions',
                                      ),
                                    ),
                                    const Text(
                                      'Body mass is not measured or inferred.',
                                    ),
                                    if (book.bodyweightRepetitions
                                        case final entry?)
                                      record(entry, highest: false)
                                    else
                                      const Text(
                                        'No eligible completed working sets.',
                                      ),
                                  ] else ...[
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        assist
                                            ? 'Rep records at fixed positive assistance'
                                            : 'Rep records at each recorded load',
                                      ),
                                    ),
                                    const Text(
                                      'Only exactly equal recorded loads in the same unit are grouped. Original values and conventions are preserved.',
                                    ),
                                    if (rows.isEmpty)
                                      const Text(
                                        'No eligible completed working sets with a recorded load.',
                                      ),
                                    if (rows.isNotEmpty)
                                      Text(
                                        'Load groups ${start + 1}–$end of ${rows.length}',
                                      ),
                                    if (pages > 1)
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed: selectedPage > 0
                                                ? () => setState(
                                                    () =>
                                                        page = selectedPage - 1,
                                                  )
                                                : null,
                                            child: const Text(
                                              'Previous record groups',
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: selectedPage + 1 < pages
                                                ? () => setState(
                                                    () =>
                                                        page = selectedPage + 1,
                                                  )
                                                : null,
                                            child: const Text(
                                              'Next record groups',
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                      );
                    },
                  ),
      ),
    );
  }
}
