import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_history_test.dart' show exercise, workout;

MeasuredProgress read(List<Json> sources, [Json? selected]) {
  final index = buildExerciseHistory(sources);
  final history = selected == null
      ? index.exercises.single
      : index.byExercise[exerciseKey(selected)]!;
  return buildMeasuredProgress(history);
}

void main() {
  test(
    'source workout chronology is independent of input and correction time',
    () {
      final first = workout('a', [
        exercise(load: '12.500000'),
      ], date: '2026-10-01T12:00:00Z');
      first['exercises'][0]['sets'][0]['observation']['recorded_at'] =
          '2026-12-31T12:00:00Z';
      final last = workout('z', [
        exercise(load: '20'),
      ], date: '2026-10-03T12:00:00Z');
      final before = canonicalJson(first);
      final model = read([
        last,
        first,
        workout('b', [exercise(load: '15')], date: '2026-10-02T12:00:00Z'),
      ]);
      expect(model.repetitions.map((p) => p.workoutId), ['a', 'b', 'z']);
      expect(model.loads['kg']!.map((p) => p.load!.original), [
        '12.500000',
        '15',
        '20',
      ]);
      expect(model.repetitions.first.startedAt, DateTime.utc(2026, 10, 1, 12));
      expect(canonicalJson(first), before);
    },
  );

  test('two sets and repeated instances keep distinct source identities and prescription order', () {
    final a = exercise(load: '5');
    final second = copyJson(a['sets'][0] as Json)..['set_id'] = 'second-set';
    second['observation']['completion_seq'] = 1;
    a['sets'][0]['observation']['completion_seq'] = 2;
    a['sets'].add(second);
    final b = copyJson(a)..['session_exercise_id'] = 'second-instance';
    b['sets'] = [copyJson(second)..['set_id'] = 'third-set'];
    final points = read([
      workout('one', [a, b]),
    ]).repetitions;
    expect(points.map((p) => p.source).toSet(), hasLength(3));
    expect(points.map((p) => (p.exerciseOrdinal, p.setOrdinal)), [
      (0, 0),
      (0, 1),
      (1, 0),
    ]);
    expect(points.map((p) => p.startedAt).toSet(), hasLength(1));
    expect(
      points.every(
        (p) =>
            p.setClass == 'working' &&
            p.status == 'completed' &&
            p.purpose == 'regular',
      ),
      isTrue,
    );
  });

  for (final axis in ['variant', 'basis', 'reps', 'side']) {
    test('$axis separates visually identical names', () {
      final a = exercise();
      final b = exercise(
        variant: axis == 'variant' ? 'another' : 'variant-a',
        basis: axis == 'basis' ? 'per_implement' : 'total_external',
        reps: axis == 'reps' ? 'per_side' : 'bilateral',
        side: axis == 'side' ? 'left' : 'both',
      );
      b['session_exercise_id'] = 'other-instance';
      final model = read([
        workout('one', [a, b]),
      ], a);
      expect(model.repetitions, hasLength(1));
      expect(model.repetitions.single.identity, exerciseKey(a));
      expect(model.repetitions.single.exerciseId, a['session_exercise_id']);
    });
  }

  test(
    'renaming retains comparison identity and actual historical source names',
    () {
      final a = exercise(name: 'Former name');
      final b = exercise(name: 'Current name');
      final model = read([
        workout('a', [a], date: '2026-10-01T12:00:00Z'),
        workout('b', [b]),
      ]);
      expect(model.repetitions.map((p) => p.exerciseName), [
        'Former name',
        'Current name',
      ]);
      expect(model.repetitions.map((p) => p.identity).toSet(), hasLength(1));
    },
  );

  test('original kg and lb form separate load series with no conversion', () {
    final model = read([
      workout('a', [
        exercise(load: '12.500000'),
        exercise(load: '27.5', unit: 'lb'),
      ]),
    ]);
    expect(model.loads.keys, ['kg', 'lb']);
    expect(model.loads['kg']!.single.load!.original, '12.500000');
    expect(model.loads['lb']!.single.load!.coordinate, 27.5);
    expect(model.repetitions, hasLength(2));
  });

  test(
    'zero is actual zero; per-implement and per-side values are never doubled',
    () {
      final e = exercise(
        load: '0.000000',
        basis: 'per_implement',
        reps: 'per_side',
        side: 'left',
      );
      final model = read([
        workout('one', [e]),
      ]);
      expect(model.loads['kg']!.single.coordinate(MeasuredMetric.load), 0);
      expect(
        model.loads['kg']!.single.originalValue(MeasuredMetric.load),
        '0.000000',
      );
      expect(model.repetitions.single.repetitions, 5);
      expect(model.repetitions.single.identity.side, 'left');
    },
  );

  for (final basis in ['bodyweight_only', 'total_external']) {
    test('$basis absent load remains absent, never fabricated zero', () {
      final model = read([
        workout('one', [exercise(basis: basis, load: null)]),
      ]);
      expect(model.loads, isEmpty);
      expect(model.repetitions.single.load, isNull);
      expect(model.repetitions.single.repetitions, 5);
    });
  }

  test(
    'positive assistance remains a separate positive measurement identity',
    () {
      final help = exercise(basis: 'assistance', load: '7');
      final external = exercise(load: '70');
      final model = read([
        workout('one', [help, external]),
      ], help);
      expect(model.loads['kg']!.single.identity.basis, 'assistance');
      expect(model.loads['kg']!.single.load!.coordinate, 7);
    },
  );

  for (final outcome in ['partial', 'failed', 'skipped', 'unperformed']) {
    test('$outcome cannot become a chart measurement', () {
      final model = read([
        workout('one', [exercise(), exercise(status: outcome)]),
      ]);
      expect(model.repetitions, hasLength(1));
      expect(model.loads['kg'], hasLength(1));
    });
  }

  test('active, abandoned and warmup work stays out of measured series', () {
    final model = read([
      workout('active', [exercise()], status: 'active'),
      workout('abandoned', [exercise()], status: 'abandoned'),
      workout('warmup', [exercise(setClass: 'warmup')]),
      workout('performed', [exercise()]),
    ]);
    expect(model.repetitions.map((p) => p.workoutId), ['performed']);
  });

  test('effective corrections replace values, units and reps without mutating old detached points', () {
    final source = workout('one', [exercise(load: '12.500000')]);
    final before = read([source]);
    final obs = source['exercises'][0]['sets'][0]['observation'];
    obs['actual']['load'] = {
      'value': '27.250000',
      'unit': 'lb',
      'basis': 'total_external',
    };
    obs['actual']['reps'] = 8;
    obs['correction_reason'] = 'Historical entry correction';
    final after = read([source]);
    expect(after.loads.keys, ['lb']);
    expect(after.repetitions, hasLength(1));
    expect(after.repetitions.single.repetitions, 8);
    expect(
      after.repetitions.single.correctionReason,
      'Historical entry correction',
    );
    expect(
      after.repetitions.single.startedAt,
      before.repetitions.single.startedAt,
    );
    expect(before.loads['kg']!.single.load!.original, '12.500000');
    expect(before.repetitions.single.repetitions, 5);
    obs['execution_status'] = 'skipped';
    obs['actual'] = null;
    expect(read([source]).repetitions, isEmpty);
  });

  for (final bad in [
    'NaN',
    'Infinity',
    '-1',
    '1e309',
    'wrong',
    1.0,
    true,
    '10000000',
    '1.0000001',
  ]) {
    test('unsupported load $bad is rejected without crashing or becoming zero', () {
      final source = copyJson(workout('one', [exercise()]));
      source['exercises'][0]['sets'][0]['observation']['actual']['load']['value'] =
          bad;
      final model = read([source]);
      expect(model.loads, isEmpty);
      expect(model.repetitions, isEmpty);
      expect(model.unsupported, 1);
    });
  }

  for (final bad in [0, -1, 1000, 1.5, '5', null]) {
    test('unsupported completed reps $bad are not fabricated or truncated', () {
      final source = workout('one', [exercise()]);
      source['exercises'][0]['sets'][0]['observation']['actual']['reps'] = bad;
      expect(read([source]).repetitions, isEmpty);
    });
  }

  test('mismatched actual load and repetition conventions are not plotted', () {
    for (final field in ['basis', 'unit', 'rep_convention']) {
      final source = workout('one', [exercise()]);
      final actual = source['exercises'][0]['sets'][0]['observation']['actual'];
      if (field == 'rep_convention') {
        actual[field] = 'per_side';
      } else {
        actual['load'][field] = field == 'unit' ? 'stone' : 'assistance';
      }
      expect(read([source]).repetitions, isEmpty);
    }
  });

  test('finite boundary values, a single point and repeated coordinates stay bounded', () {
    final model = read([
      workout('one', [exercise(load: '9999999.999999')]),
    ]);
    expect(model.window(MeasuredMetric.load, unit: 'kg').coordinates, [
      (x: 0.5, y: 0.5),
    ]);
    final repeated = read([
      workout('z', [exercise()]),
      workout('a', [exercise()]),
    ]);
    expect(repeated.repetitions.map((p) => p.workoutId), ['a', 'z']);
    expect(repeated.window(MeasuredMetric.load, unit: 'kg').coordinates, [
      (x: 0.5, y: 0.5),
      (x: 0.5, y: 0.5),
    ]);
  });

  test('bounded windows keep older observations accessible and clamp after corrections', () {
    final model = read([
      for (var i = 0; i < 205; i++)
        workout(
          'source-$i',
          [exercise()],
          date: DateTime.utc(
            2026,
            1,
            1,
          ).add(Duration(days: i)).toIso8601String(),
        ),
    ]);
    final newest = model.window(MeasuredMetric.repetitions);
    expect((newest.start, newest.end, newest.total), (125, 205, 205));
    expect(newest.points, hasLength(80));
    final oldest = model.window(MeasuredMetric.repetitions, page: 999);
    expect((oldest.start, oldest.end, oldest.page), (0, 45, 2));
    expect(oldest.points.first.workoutId, 'source-0');
    final reduced = read([
      workout('only', [exercise()]),
    ]).window(MeasuredMetric.repetitions, page: 2);
    expect(reduced.page, 0);
    expect(reduced.points, hasLength(1));
    expect(() => model.repetitions.clear(), throwsUnsupportedError);
  });
}
