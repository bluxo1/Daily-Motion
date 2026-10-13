import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../sync/transport_limits.dart';

typedef Json = Map<String, dynamic>;

const commandByteLimit = transportCommandLimit;

String canonicalJson(Object? value) {
  Object? sort(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sort(item[key])};
    }
    if (item is List) return item.map(sort).toList();
    return item;
  }

  return jsonEncode(sort(value));
}

Json copyJson(Json value) => jsonDecode(jsonEncode(value)) as Json;

/// DateTime.parse normalizes impossible dates; wire instants must not do so.
bool isUtcInstant(Object? value) {
  if (value is! String) return false;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{1,6})?Z$',
  ).firstMatch(value);
  final parsed = DateTime.tryParse(value);
  if (match == null || parsed == null || parsed.year == 0) return false;
  final parts = [
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  ];
  return List.generate(
    6,
    (i) => int.parse(match.group(i + 1)!),
  ).asMap().entries.every((e) => e.value == parts[e.key]);
}

class WorkoutValidation implements Exception {
  final String message;
  const WorkoutValidation(this.message);
  @override
  String toString() => message;
}

void require(bool valid, String message) {
  if (!valid) throw WorkoutValidation(message);
}

final _decimal = RegExp(r'^(0|[1-9]\d{0,6})(\.\d{1,6})?$');

void _keys(
  Json value,
  Set<String> required, [
  Set<String> optional = const {},
]) {
  require(
    required.every(value.containsKey),
    'A required command field is missing.',
  );
  require(
    value.keys.every((key) => required.contains(key) || optional.contains(key)),
    'Unsupported command field.',
  );
}

void validateEnvelope(Json operation) {
  _keys(operation, {
    'mutation_id',
    'installation_id',
    'aggregate_type',
    'aggregate_id',
    'expected_revision',
    'command',
    'occurred_at',
    'recorded_at',
    'payload',
  });
  for (final key in ['mutation_id', 'installation_id', 'aggregate_id']) {
    require(
      operation[key] is String &&
          Uuid.isValidUUID(fromString: operation[key] as String),
      'Use stable UUID identifiers.',
    );
  }
  require(
    operation['aggregate_type'] == 'workout_session',
    'Unsupported aggregate.',
  );
  require(
    operation['expected_revision'] is int &&
        operation['expected_revision'] >= 0,
    'Invalid base revision.',
  );
  for (final key in ['occurred_at', 'recorded_at']) {
    require(isUtcInstant(operation[key]), 'Use UTC timestamps.');
  }
  final payload = operation['payload'] as Json;
  if (operation['command'] == 'create_session') {
    _keys(payload, {'name', 'timezone', 'exercises'});
    require(
      operation['expected_revision'] == 0,
      'Creates must expect revision zero.',
    );
    require(
      ['UTC', 'Asia/Kolkata', 'Asia/Calcutta'].contains(payload['timezone']),
      'This foundation supports UTC and India timezones.',
    );
  } else if (['record_set', 'correct_set'].contains(operation['command'])) {
    _keys(
      payload,
      {
        'session_exercise_id',
        'set_id',
        'execution_status',
        'actual',
        'completion_seq',
      },
      {'order_source', 'correction_reason'},
    );
    require(
      payload['completion_seq'] is int && payload['completion_seq'] > 0,
      'Invalid completion sequence.',
    );
    require(
      payload['order_source'] == null || payload['order_source'] == 'logged',
      'Unsupported order source.',
    );
    for (final key in ['session_exercise_id', 'set_id']) {
      require(
        payload[key] is String &&
            Uuid.isValidUUID(fromString: payload[key] as String),
        'Use stable child UUIDs.',
      );
    }
    if (operation['command'] == 'record_set') {
      require(
        payload['correction_reason'] == null,
        'Use a correction command to change history.',
      );
    }
  } else {
    _keys(payload, {});
  }
}

void validateLoad(Json load, String basis) {
  _keys(load, {'value', 'unit', 'basis'});
  require(
    load['value'] is String && _decimal.hasMatch(load['value']),
    'Enter a non-negative decimal load.',
  );
  require(['kg', 'lb'].contains(load['unit']), 'Choose kg or lb.');
  require(load['basis'] == basis, 'Load must follow the exercise convention.');
}

void validateObservation(Json payload, Json exercise) {
  final status = payload['execution_status'];
  require(
    ['completed', 'partial', 'failed', 'skipped'].contains(status),
    'Choose a supported outcome.',
  );
  final actual = payload['actual'] as Json?;
  if (status == 'skipped') {
    require(actual == null, 'Skipped sets have no performed values.');
    return;
  }
  require(actual != null, 'Enter the actual performance.');
  _keys(actual!, {'load', 'reps', 'rep_convention'}, {'effort'});
  final reps = actual['reps'];
  require(
    reps is int && reps >= 0 && reps <= 999,
    'Enter whole reps from 0 to 999.',
  );
  require(
    status == 'failed' || reps > 0,
    'Zero reps requires an explicit failed attempt.',
  );
  require(
    actual['rep_convention'] == exercise['rep_convention'],
    'Reps must follow the exercise convention.',
  );
  final load = actual['load'] as Json?;
  if (exercise['loading_basis'] == 'bodyweight_only') {
    require(load == null, 'Bodyweight-only work has no external load.');
  } else {
    require(load != null, 'Enter the actual load.');
    validateLoad(load!, exercise['loading_basis'] as String);
  }
  final effort = actual['effort'] as Json?;
  if (effort != null) {
    _keys(effort, {'scale', 'value'}, {'source'});
    require(
      effort['value'] is String && _decimal.hasMatch(effort['value']),
      'Enter a valid effort.',
    );
    final value = double.parse(effort['value'] as String);
    require(
      effort['source'] == 'self_reported',
      'Effort must be self-reported.',
    );
    require(
      (effort['scale'] == 'rir' &&
              value >= 0 &&
              value <= 10 &&
              value == value.roundToDouble()) ||
          (effort['scale'] == 'rpe' &&
              value >= 1 &&
              value <= 10 &&
              value * 2 == (value * 2).roundToDouble()),
      'RIR uses whole values 0–10; RPE uses half steps 1–10.',
    );
  }
}

/// The Phase 0 reducer changes performed observations without changing prescriptions.
Json? applyOperation(Json? previous, Json op, {int? revision}) {
  final command = op['command'];
  final payload = op['payload'] as Json;
  final id = op['aggregate_id'];
  Json state;
  if (command == 'create_session') {
    require(previous == null, 'This workout already exists.');
    require(
      payload['name'] is String &&
          (payload['name'] as String).isNotEmpty &&
          (payload['name'] as String).runes.length <= 120,
      'Name the workout (up to 120 characters).',
    );
    final exercises = payload['exercises'] as List;
    require(
      exercises.isNotEmpty && exercises.length <= 50,
      'Use 1–50 exercises for this spike.',
    );
    final ids = <String>{id as String};
    for (final raw in exercises) {
      final exercise = raw as Json;
      _keys(
        exercise,
        {
          'session_exercise_id',
          'variant_id',
          'name',
          'loading_basis',
          'rep_convention',
          'sets',
        },
        {'side'},
      );
      require(
        Uuid.isValidUUID(
              fromString: exercise['session_exercise_id'] as String,
            ) &&
            Uuid.isValidUUID(fromString: exercise['variant_id'] as String),
        'Use stable exercise UUIDs.',
      );
      require(
        exercise['name'] is String &&
            exercise['name'].isNotEmpty &&
            (exercise['name'] as String).runes.length <= 120,
        'Name the exercise.',
      );
      require(
        [
          'total_external',
          'per_implement',
          'machine_stack',
          'added_bodyweight',
          'assistance',
          'bodyweight_only',
        ].contains(exercise['loading_basis']),
        'Unsupported loading convention.',
      );
      require(
        [
          'bilateral',
          'per_side',
          'alternating_total',
        ].contains(exercise['rep_convention']),
        'Unsupported rep convention.',
      );
      require(
        exercise['side'] == null ||
            ['left', 'right', 'both', 'unspecified'].contains(exercise['side']),
        'Unsupported side.',
      );
      require(
        ids.add(exercise['session_exercise_id'] as String),
        'Child IDs must be distinct.',
      );
      final sets = exercise['sets'] as List;
      require(
        sets.isNotEmpty && sets.length <= 100,
        'Use 1–100 sets per exercise.',
      );
      for (final rawSet in sets) {
        final item = rawSet as Json;
        _keys(item, {'set_id', 'set_class', 'set_purpose', 'planned'});
        require(
          Uuid.isValidUUID(fromString: item['set_id'] as String),
          'Use a stable set UUID.',
        );
        require(
          ids.add(item['set_id'] as String),
          'Child IDs must be distinct.',
        );
        require(
          ['warmup', 'working'].contains(item['set_class']),
          'Choose a set class.',
        );
        require(
          ['regular', 'top', 'backoff'].contains(item['set_purpose']),
          'Choose a set purpose.',
        );
        final planned = item['planned'] as Json;
        _keys(planned, {'rest_seconds'}, {'reps', 'load'});
        if (planned['load'] != null) {
          validateLoad(
            planned['load'] as Json,
            exercise['loading_basis'] as String,
          );
        }
        final reps = planned['reps'];
        require(
          reps == null || (reps is int && reps > 0 && reps <= 999),
          'Planned reps must be positive.',
        );
        final rest = planned['rest_seconds'];
        require(
          rest is int && rest >= 0 && rest <= 3600,
          'Rest target must be 0–3600 seconds.',
        );
      }
    }
    state = {
      ...copyJson(payload),
      'aggregate_id': id,
      'revision': revision ?? 0,
      'status': 'active',
      'started_at': op['occurred_at'],
      'ended_at': null,
    };
    for (final exercise in state['exercises'] as List) {
      for (final item in exercise['sets'] as List) {
        item['observation'] = null;
      }
    }
  } else {
    require(
      previous != null && previous['aggregate_id'] == id,
      'Workout not found.',
    );
    state = copyJson(previous!);
    if (command == 'delete_session') return null;
    if (command == 'record_set' || command == 'correct_set') {
      final exercises = (state['exercises'] as List).cast<Json>();
      final matches = exercises
          .where(
            (e) => e['session_exercise_id'] == payload['session_exercise_id'],
          )
          .toList();
      require(matches.length == 1, 'Exercise not found.');
      final exercise = matches.single;
      final sets = (exercise['sets'] as List).cast<Json>();
      final matchingSets = sets
          .where((s) => s['set_id'] == payload['set_id'])
          .toList();
      require(matchingSets.length == 1, 'Set not found.');
      final item = matchingSets.single;
      final original = item['observation'] as Json?;
      validateObservation(payload, exercise);
      if (command == 'record_set') {
        require(
          state['status'] == 'active' && original == null,
          'This set is already recorded or the workout has finished.',
        );
        require(
          payload['completion_seq'] == completionSequence(state) + 1,
          'Completion sequence must advance once.',
        );
      } else {
        require(original != null, 'Only recorded sets can be corrected.');
        final reason = payload['correction_reason'];
        require(
          reason is String &&
              RegExp(transportNonblankReasonPattern).hasMatch(reason) &&
              reason.runes.length <= 240,
          'Give a correction reason.',
        );
        require(
          payload['completion_seq'] == original!['completion_seq'],
          'Corrections preserve logged order.',
        );
      }
      item['observation'] = {
        ...copyJson(payload),
        'occurred_at': op['occurred_at'],
        'recorded_at': op['recorded_at'],
      };
    } else if (command == 'complete_session' || command == 'abandon_session') {
      require(
        state['status'] == 'active',
        'This workout has already finished.',
      );
      if (command == 'complete_session') {
        require(
          allSets(state).any(
            (s) =>
                s['observation'] != null &&
                s['observation']['execution_status'] != 'skipped',
          ),
          'Record an attempted set before finishing.',
        );
      }
      state['status'] = command == 'complete_session'
          ? 'completed'
          : 'abandoned';
      state['ended_at'] = op['occurred_at'];
    } else {
      throw const WorkoutValidation('Unsupported command.');
    }
    if (revision != null) state['revision'] = revision;
  }
  return state;
}

Iterable<Json> allSets(Json state) sync* {
  for (final exercise in state['exercises'] as List) {
    yield* (exercise['sets'] as List).cast<Json>();
  }
}

int completionSequence(Json state) => allSets(state).fold(0, (value, s) {
  final next = (s['observation'] as Json?)?['completion_seq'] as int? ?? 0;
  return next > value ? next : value;
});

/// Fixed-point conversion preserves the original input; no rounded display round trip.
String canonicalKilograms(String value, String unit) {
  require(
    _decimal.hasMatch(value) && ['kg', 'lb'].contains(unit),
    'Invalid mass.',
  );
  if (unit == 'kg') return value;
  final parts = value.split('.');
  final places = parts.length == 2 ? parts[1].length : 0;
  final integer = BigInt.parse(parts.join());
  final converted = integer * BigInt.from(45359237);
  final scale = places + 8;
  final digits = converted.toString().padLeft(scale + 1, '0');
  final decimal =
      '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  return decimal
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
