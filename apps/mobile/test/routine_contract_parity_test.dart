import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show fixture;
import 'routine_repository_test.dart' show routinePlan;

Json capacitySpec() => jsonDecode(
  File('../../contracts/fixtures/routine_capacity_edge.json')
      .readAsStringSync(),
) as Json;

/// Compact shared fixture specification; its exact canonical operation hash is
/// checked independently by Python, avoiding a second hand-authored contract.
Json capacityOperation(Json spec) {
  final original = fixture();
  final prototype = (original['payload']['exercises'] as List).first as Json;
  var counter = 0;
  String id() =>
      '10000000-0000-4000-8000-${(++counter).toRadixString(16).padLeft(12, '0')}';
  final exercises = <Json>[];
  for (var i = 0; i < (spec['sets_per_exercise'] as List).length; i++) {
    final exercise = copyJson(prototype);
    exercise['session_exercise_id'] = id();
    exercise['name'] = spec['exercise_names'][i];
    exercise['sets'] = [
      for (var n = 0; n < spec['sets_per_exercise'][i]; n++)
        {
          ...copyJson((prototype['sets'] as List).first as Json),
          'set_id': id(),
        },
    ];
    exercises.add(exercise);
  }
  return {
    for (final key in [
      'mutation_id',
      'installation_id',
      'aggregate_id',
      'occurred_at',
      'recorded_at',
    ])
      key: original[key],
    'aggregate_type': 'routine',
    'expected_revision': 0,
    'command': 'create_routine',
    'payload': {
      'template_id': '60000000-0000-4000-8000-000000000001',
      'predecessor_template_id': null,
      'prescription': {
        'name': spec['routine_name'],
        'timezone': original['payload']['timezone'],
        'exercises': exercises,
      },
    },
  };
}

void main() {
  final spec = capacitySpec();
  for (final field in ['session_exercise_id', 'variant_id', 'set_id']) {
    for (final valid in [false, true]) {
      final values =
          spec[valid ? 'valid_planning_uuids' : 'invalid_planning_uuids']
              as List;
      for (final (index, value) in values.indexed) {
        test('native routine planning UUID $field/$valid/$index', () {
          final plan = routinePlan().json;
          final exercise = plan['exercises'][0] as Json;
          (field == 'set_id' ? exercise['sets'][0] as Json : exercise)[field] =
              value;
          if (valid) {
            expect(RoutinePlan.fromJson(plan).json, plan);
          } else {
            expect(
              () => RoutinePlan.fromJson(plan),
              throwsA(isA<WorkoutValidation>()),
            );
          }
        });
      }
    }
  }
  test('shared near-limit routine operation cannot strand an unstartable prescription', () {
    final operation = capacityOperation(spec);
    final bytes = utf8.encode(canonicalJson(operation));
    expect(bytes.length, spec['canonical_operation_bytes']);
    expect(
      sha256.convert(bytes).toString(),
      spec['canonical_operation_sha256'],
    );
    expect(
      () => RoutinePlan.fromJson(operation['payload']['prescription'] as Json),
      throwsA(
        isA<WorkoutValidation>().having(
          (e) => e.toString(),
          'capacity refusal',
          contains('too large to start safely'),
        ),
      ),
    );
  });
  test('same shared prescription below reserved capacity remains usable', () {
    final operation = capacityOperation(spec);
    final sets =
        operation['payload']['prescription']['exercises'][0]['sets'] as List;
    sets.removeRange(sets.length - (spec['pruned_sets'] as int), sets.length);
    expect(
      RoutinePlan.fromJson(operation['payload']['prescription'] as Json).name,
      spec['routine_name'],
    );
  });
  for (final field in ['routine', 'exercise']) {
    for (final (index, value)
        in (spec['blank_names'] as List).cast<String>().indexed) {
      test('routine contract rejects native Dart blank name $field/$index', () {
        final plan = routinePlan().json;
        (field == 'routine' ? plan : plan['exercises'][0] as Json)['name'] =
            value;
        expect(value.trim(), isEmpty);
        expect(
          () => RoutinePlan.fromJson(plan),
          throwsA(isA<WorkoutValidation>()),
        );
      });
    }
    for (final (index, value)
        in (spec['nonblank_names'] as List).cast<String>().indexed) {
      test(
        'routine contract preserves native Dart nonblank name $field/$index',
        () {
          final plan = routinePlan().json;
          (field == 'routine' ? plan : plan['exercises'][0] as Json)['name'] =
              value;
          expect(value.trim(), isNotEmpty);
          expect(RoutinePlan.fromJson(plan).json, plan);
        },
      );
    }
  }
  for (final field in ['set_class', 'set_purpose', 'rest_seconds']) {
    test(
      'routine contract needs explicit $field instead of guessing a workout default',
      () {
        final plan = routinePlan().json;
        final set = plan['exercises'][0]['sets'][0] as Json;
        (field == 'rest_seconds' ? set['planned'] as Json : set).remove(field);
        expect(
          () => RoutinePlan.fromJson(plan),
          throwsA(isA<WorkoutValidation>()),
        );
      },
    );
  }
  for (final field in ['side', 'reps', 'load']) {
    test(
      'routine contract preserves optional omitted $field without normalization',
      () {
        final plan = routinePlan().json;
        final exercise = plan['exercises'][0] as Json;
        (field == 'side' ? exercise : exercise['sets'][0]['planned'] as Json)
            .remove(field);
        expect(RoutinePlan.fromJson(plan).json, plan);
      },
    );
  }
}
