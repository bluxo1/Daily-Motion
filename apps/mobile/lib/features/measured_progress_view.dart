import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_history.dart';
import '../domain/measured_progress.dart';
import 'exercise_history_provider.dart';
import 'measured_progress_provider.dart';
import 'workout_presentation.dart';
import 'workout_controller.dart';

class MeasuredProgressView extends ConsumerStatefulWidget {
  final ExerciseKey identity;
  final ValueChanged<String> onOpenWorkout;
  const MeasuredProgressView({
    super.key,
    required this.identity,
    required this.onOpenWorkout,
  });
  @override
  ConsumerState<MeasuredProgressView> createState() =>
      _MeasuredProgressViewState();
}

class _MeasuredProgressViewState extends ConsumerState<MeasuredProgressView> {
  var metric = MeasuredMetric.load;
  String? unit;
  var page = 0;

  @override
  void didUpdateWidget(covariant MeasuredProgressView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      metric = MeasuredMetric.load;
      unit = null;
      page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(measuredProgressProvider(widget.identity))
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () =>
            const Center(child: Text('Loading measured observations…')),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Measured history could not be loaded. Check account access or retry.',
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(workoutsProvider.notifier).refresh();
                  if (context.mounted) ref.invalidate(exerciseHistoryProvider);
                },
                child: const Text('Retry measured history'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.name.isEmpty) {
            return const Center(
              child: Text('No recorded history for this exercise.'),
            );
          }
          final bodyweight = widget.identity.basis == 'bodyweight_only';
          final selectedMetric = bodyweight
              ? MeasuredMetric.repetitions
              : metric;
          final units = data.loads.keys.toList();
          final selectedUnit = units.contains(unit)
              ? unit
              : (units.isEmpty ? null : units.first);
          final window = data.window(
            selectedMetric,
            unit: selectedUnit,
            page: page,
          );
          final assist = widget.identity.basis == 'assistance';
          final loadLabel = assist ? 'Positive assistance' : 'Recorded load';
          final measurement = selectedMetric == MeasuredMetric.load
              ? '$loadLabel (${selectedUnit ?? 'no recorded unit'})'
              : 'Performed repetitions';
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  key: ValueKey((
                    widget.identity,
                    selectedMetric,
                    selectedUnit,
                    window.page,
                  )),
                  padding: const EdgeInsets.all(16),
                  itemCount: window.points.length + 1,
                  itemBuilder: (context, i) => i == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Measured working sets',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ),
                            Text(data.name),
                            Text(
                              exerciseConvention({
                                'loading_basis': widget.identity.basis,
                                'rep_convention': widget.identity.reps,
                                'side': widget.identity.side,
                              }),
                            ),
                            Text('Variant ${widget.identity.variant}'),
                            const Text(
                              'Only effective completed working sets from completed workouts. No predictions, records or rankings.',
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<MeasuredMetric>(
                              key: ValueKey((widget.identity, selectedMetric)),
                              initialValue: selectedMetric,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Measurement',
                              ),
                              items: [
                                if (!bodyweight)
                                  DropdownMenuItem(
                                    value: MeasuredMetric.load,
                                    child: Text(loadLabel),
                                  ),
                                const DropdownMenuItem(
                                  value: MeasuredMetric.repetitions,
                                  child: Text('Performed repetitions'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    metric = value;
                                    page = 0;
                                  });
                                }
                              },
                            ),
                            if (selectedMetric == MeasuredMetric.load &&
                                units.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                key: ValueKey((units.join('|'), selectedUnit)),
                                initialValue: selectedUnit,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Chart load unit',
                                ),
                                items: [
                                  for (final u in units)
                                    DropdownMenuItem(value: u, child: Text(u)),
                                ],
                                onChanged: (value) => setState(() {
                                  unit = value;
                                  page = 0;
                                }),
                              ),
                              if (unit != null && !units.contains(unit))
                                Text(
                                  'The previous unit has no eligible measurements. Showing $selectedUnit.',
                                ),
                            ],
                            const SizedBox(height: 16),
                            if (bodyweight)
                              const Text(
                                'Bodyweight-only work has no external-load series.',
                              ),
                            if (assist)
                              const Text(
                                'Positive assistance is assistance, not external weight or a strength achievement.',
                              ),
                            if (selectedMetric == MeasuredMetric.repetitions)
                              const Text(
                                'Read each actual load with its repetitions. More reps at another load do not establish a strength record.',
                              ),
                            if (data.unsupported > 0)
                              Text(
                                '${data.unsupported} records have unsupported measurement data. Inspect Source history for context.',
                              ),
                            if (window.points.isEmpty)
                              Text(
                                selectedMetric == MeasuredMetric.load
                                    ? 'No eligible recorded load. Missing load is unknown, not zero. Other outcomes remain in Source history.'
                                    : 'No eligible performed repetitions. Only completed working sets in completed workouts are plotted; other outcomes remain in Source history.',
                              )
                            else ...[
                              Text(
                                measurement,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              MeasuredScatter(
                                window: window,
                                label: measurement,
                              ),
                              Text(
                                window.total == 1
                                    ? 'One observed set. No trajectory is inferred.'
                                    : 'Distinct sets can overlap on the plot. Every plotted observation is listed below.',
                              ),
                              const Text(
                                'Dates are workout start times, not physical set execution times. Plot coordinates are approximate; original values are listed exactly.',
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  'Exact observations',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ],
                        )
                      : _pointRow(window.points[i - 1], selectedMetric),
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
                      onPressed: window.page + 1 >= window.pages
                          ? null
                          : () => setState(() => page = window.page + 1),
                      child: const Text('Older observations'),
                    ),
                    Text(
                      window.total == 0
                          ? 'Observations 0 of 0'
                          : 'Observations ${window.start + 1}–${window.end} of ${window.total}',
                    ),
                    TextButton(
                      onPressed: window.page == 0
                          ? null
                          : () => setState(() => page = window.page - 1),
                      child: const Text('Newer observations'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );

  Widget _pointRow(MeasuredPoint point, MeasuredMetric selectedMetric) {
    final load = point.load;
    final loadText = load == null
        ? (point.identity.basis == 'bodyweight_only'
              ? 'Bodyweight only; no external load'
              : 'No recorded load (unknown)')
        : '${load.original} ${load.unit} · ${loadConvention({'loading_basis': point.identity.basis})}';
    final value = selectedMetric == MeasuredMetric.load
        ? '${load!.original} ${load.unit}'
        : '${point.repetitions} reps';
    final contextText =
        '$loadText; ${point.repetitions} reps · ${point.identity.reps.replaceAll('_', ' ')} · ${point.identity.side}\n'
        '${point.workoutName} · ${point.startedAt.toIso8601String()}\n'
        '${point.exerciseName} · exercise instance ${point.exerciseOrdinal + 1}, set ${point.setOrdinal + 1} · ${point.setClass} · ${point.purpose} · ${point.status}'
        '${point.correctionReason == null ? '' : '\nCorrected: ${point.correctionReason}'}'
        '${point.conflict ? '\nSaved on this device · sync needs review' : ''}';
    return Semantics(
      key: ValueKey(('measured-point', point.source)),
      button: true,
      label: '$value. $contextText. Open source workout.',
      excludeSemantics: true,
      onTap: () => widget.onOpenWorkout(point.workoutId),
      child: Card(
        child: ListTile(
          title: Text(value),
          subtitle: Text(contextText),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => widget.onOpenWorkout(point.workoutId),
        ),
      ),
    );
  }
}

class MeasuredScatter extends StatelessWidget {
  final MeasuredWindow window;
  final String label;
  const MeasuredScatter({super.key, required this.window, required this.label});
  @override
  Widget build(BuildContext context) {
    final ordered = window.points.toList()
      ..sort(
        (a, b) =>
            a.coordinate(window.metric).compareTo(b.coordinate(window.metric)),
      );
    final low = ordered.first.originalValue(window.metric);
    final high = ordered.last.originalValue(window.metric);
    final theme = Theme.of(context);
    String date(MeasuredPoint p) =>
        p.startedAt.toIso8601String().split('T').first;
    return Semantics(
      label:
          '$label scatter plot. ${window.points.length} source observations from ${date(window.points.first)} to ${date(window.points.last)} UTC. Exact values and source links follow.',
      image: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vertical axis: $label'),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // Axis labels may abbreviate visually at large text sizes;
                      // the exact decimal remains in every source row below.
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              high,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              low,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      key: const ValueKey('measured-scatter'),
                      painter: MeasuredScatterPainter(
                        window.coordinates,
                        theme.colorScheme.primary,
                        theme.colorScheme.onSurface,
                        theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(date(window.points.first))),
                Expanded(
                  child: Text(
                    date(window.points.last),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const Text('Horizontal axis: workout start date (UTC)'),
          ],
        ),
      ),
    );
  }
}

class MeasuredScatterPainter extends CustomPainter {
  final List<({double x, double y})> points;
  final Color color;
  final Color axis;
  final Color background;
  MeasuredScatterPainter(this.points, this.color, this.axis, this.background);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16) return;
    final plot = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(plot, Paint()..color = background);
    canvas.drawLine(
      plot.topLeft,
      plot.bottomLeft,
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      plot.bottomLeft,
      plot.bottomRight,
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    for (final point in points) {
      if (!point.x.isFinite || !point.y.isFinite) continue;
      canvas.drawCircle(
        Offset(
          plot.left + point.x.clamp(0, 1) * plot.width,
          plot.bottom - point.y.clamp(0, 1) * plot.height,
        ),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MeasuredScatterPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.axis != axis ||
      oldDelegate.background != background;
}
