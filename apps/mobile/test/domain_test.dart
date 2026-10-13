import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show fixture;

void main() {
  test('canonical UTF-8 serialization matches the Python command fixture', () {
    final digest = sha256
        .convert(utf8.encode(canonicalJson(fixture())))
        .toString();
    expect(
      digest,
      File('../../contracts/fixtures/workout.sha256').readAsStringSync().trim(),
    );
    validateEnvelope(fixture());
  });
  test(
    'pound conversion is decimal-safe and preserves original quantities',
    () {
      expect(canonicalKilograms('100', 'lb'), '45.359237');
      expect(canonicalKilograms('0', 'lb'), '0');
      expect(canonicalKilograms('2.5', 'lb'), '1.133980925');
      expect(canonicalKilograms('60.00', 'kg'), '60.00');
    },
  );

  test('shared fixture starts with unperformed suggestions', () {
    final state = applyOperation(null, fixture())!;
    expect(allSets(state).every((s) => s['observation'] == null), isTrue);
    expect(completionSequence(state), 0);
  });

  test('zero and missing effort retain their meanings', () {
    final exercise = {
      'loading_basis': 'total_external',
      'rep_convention': 'bilateral',
    };
    final observation = {
      'execution_status': 'failed',
      'actual': {
        'load': {'value': '0', 'unit': 'kg', 'basis': 'total_external'},
        'reps': 0,
        'rep_convention': 'bilateral',
        'effort': {'scale': 'rir', 'value': '0', 'source': 'self_reported'},
      },
    };
    validateObservation(observation, exercise);
    observation['execution_status'] = 'completed';
    expect(
      () => validateObservation(observation, exercise),
      throwsA(isA<WorkoutValidation>()),
    );
    observation['execution_status'] = 'skipped';
    expect(
      () => validateObservation(observation, exercise),
      throwsA(isA<WorkoutValidation>()),
    );
  });
}
