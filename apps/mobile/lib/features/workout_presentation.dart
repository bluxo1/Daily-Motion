import '../domain/workout.dart';

String loadConvention(Json exercise) => switch (exercise['loading_basis']) {
  'total_external' => 'total external',
  'per_implement' => 'per implement',
  'machine_stack' => 'machine stack',
  'added_bodyweight' => 'added bodyweight',
  'assistance' => 'positive assistance',
  'bodyweight_only' => 'bodyweight only',
  _ => 'unspecified load convention',
};

String exerciseConvention(Json exercise) {
  final reps = switch (exercise['rep_convention']) {
    'bilateral' => 'bilateral reps',
    'per_side' => 'reps per side',
    'alternating_total' => 'alternating total reps',
    _ => 'unspecified rep convention',
  };
  return '${loadConvention(exercise)} · $reps · ${exercise['side'] ?? 'unspecified'}';
}

String performanceSummary(Json values) {
  final load = values['load'] as Json?;
  final effort = values['effort'] as Json?;
  return [
    if (load != null) '${load['value']} ${load['unit']}',
    if (values['reps'] != null) '${values['reps']} reps',
    if (effort != null)
      '${(effort['scale'] as String).toUpperCase()} ${effort['value']}',
  ].join(' · ');
}

String setSummary(Json item) {
  final observation = item['observation'] as Json?;
  if (observation == null) {
    return 'Planned ${performanceSummary(item['planned'] as Json)} · unperformed';
  }
  final actual = observation['actual'] as Json?;
  return '${observation['execution_status']} · '
      '${actual == null ? 'No performance recorded' : performanceSummary(actual)}'
      '${observation['correction_reason'] == null ? '' : ' · corrected: ${observation['correction_reason']}'}';
}

String workoutDate(Json workout) {
  final date = DateTime.parse(workout['started_at'] as String).toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)} UTC';
}

List<Json> historicalWorkouts(List<Json> items) =>
    items.where((w) => w['status'] != 'active').toList()..sort(
      (a, b) =>
          DateTime.parse(b['started_at'] as String)
              .compareTo(DateTime.parse(a['started_at'] as String)),
    );

String recordedCounts(Json workout) {
  final sets = allSets(workout).toList();
  final attempted = sets
      .where(
        (s) => [
          'completed',
          'partial',
          'failed',
        ].contains(s['observation']?['execution_status']),
      )
      .length;
  final skipped = sets
      .where((s) => s['observation']?['execution_status'] == 'skipped')
      .length;
  final pending = sets.where((s) => s['observation'] == null).length;
  return '$attempted attempted sets · $skipped skipped · $pending unperformed';
}
