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
