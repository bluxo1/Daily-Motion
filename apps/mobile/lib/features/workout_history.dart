import 'package:flutter/material.dart';

import '../domain/workout.dart';
import 'workout_presentation.dart';

class WorkoutHistory extends StatelessWidget {
  final List<Json> workouts;
  final ValueChanged<String> onOpen;
  const WorkoutHistory({
    super.key,
    required this.workouts,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final history = historicalWorkouts(workouts);
    if (history.isEmpty) {
      return const Text('Your recorded workouts will appear here.');
    }
    return Column(
      children: [
        for (final workout in history)
          Card(
            key: ValueKey('history-${workout['aggregate_id']}'),
            child: ListTile(
              title: Text(workout['name'] as String),
              subtitle: Text(
                '${workout['status']} · ${workoutDate(workout)}\n${recordedCounts(workout)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(workout['aggregate_id'] as String),
            ),
          ),
      ],
    );
  }
}

class ObservedPerformance extends StatelessWidget {
  final List<Json> workouts;
  const ObservedPerformance({super.key, required this.workouts});
  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final workout in historicalWorkouts(workouts))
        if (workout['status'] == 'completed')
          for (final exercise in (workout['exercises'] as List).cast<Json>())
            for (final (index, item)
                in (exercise['sets'] as List).cast<Json>().indexed)
              if (item['set_class'] == 'working' &&
                  item['observation']?['execution_status'] == 'completed')
                (workout, exercise, index, item),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observed performance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Completed working-set observations from completed workouts. Individual entries, without combined scores or rankings.',
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Text(
            'Complete a workout with a completed working set to see observations. Warm-ups and other outcomes remain in History.',
          ),
        for (final (workout, exercise, index, item) in entries)
          Card(
            key: ValueKey(
              'performance-${workout['aggregate_id']}-${item['set_id']}',
            ),
            child: ListTile(
              title: Text(
                '${exercise['name']} · Set ${index + 1}\n${performanceSummary(item['observation']['actual'] as Json)}',
              ),
              subtitle: Text(
                '${exerciseConvention(exercise)}\n${workout['name']} · ${workoutDate(workout)}'
                '${item['observation']['correction_reason'] == null ? '' : '\nCorrected observation'}',
              ),
            ),
          ),
      ],
    );
  }
}
