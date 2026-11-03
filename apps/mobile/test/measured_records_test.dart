import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_history_test.dart' show exercise, workout;

Json source(
  String id, {
  String? load = '20',
  String unit = 'kg',
  int reps = 5,
  String basis = 'total_external',
  String outcome = 'completed',
  String status = 'completed',
  String setClass = 'working',
  String variant = 'variant-a',
  String side = 'both',
  String convention = 'bilateral',
}) {
  final e = exercise(
    load: load,
    unit: unit,
    basis: basis,
    status: outcome,
    variant: variant,
    side: side,
    reps: convention,
  );
  e['sets'][0]['set_class'] = setClass;
  if (e['sets'][0]['observation']?['actual'] != null) {
    e['sets'][0]['observation']['actual']['reps'] = reps;
  }
  return workout(id, [e], status: status)
    ..['revision'] = 3
    ..['local_seq'] = 7;
}

MeasuredProgress model(List<Json> sources, [Json? selected]) {
  final index = buildExerciseHistory(sources);
  return buildMeasuredProgress(
    selected == null
        ? index.exercises.single
        : index.byExercise[exerciseKey(selected)]!,
  );
}

void main() {
  test(
    'records scan all eligible history rather than the visible chart window',
    () {
      final oldest = source('oldest', load: '999', reps: 30)
        ..['started_at'] = '2020-01-01T12:00:00Z';
      final data = model([
        oldest,
        for (var i = 0; i < 160; i++) source('new-$i', load: '10'),
      ]);
      expect(
        data
            .window(MeasuredMetric.load, unit: 'kg')
            .points
            .every((p) => p.workoutId != 'oldest'),
        isTrue,
      );
      expect(data.records.highestLoads['kg']!.source.workoutId, 'oldest');
    },
  );
  test(
    'decimal-equal loads group exactly with deterministic distinct tie sources',
    () {
      final data = model([
        source('c', load: '20', reps: 10),
        source('a', load: '20.000000'),
        source('b', load: '20.0', reps: 10),
      ]);
      final records = data.records;
      expect(records.highestLoads['kg']!.source.workoutId, 'a');
      expect(records.highestLoads['kg']!.source.load!.original, '20.000000');
      expect(records.highestLoads['kg']!.ties, 3);
      expect(records.repetitionsAtLoad['kg'], hasLength(1));
      final reps = records.repetitionsAtLoad['kg']!.single;
      expect(reps.source.workoutId, 'b');
      expect(reps.source.repetitions, 10);
      expect(reps.source.load!.original, '20.0');
      expect(reps.ties, 2);
      expect(reps.source.sourceRevision, 3);
      expect(reps.source.localSequence, 7);
      expect(reps.source.source, (
        'b',
        'instance-variant-a-both',
        'set-variant-a-both',
      ));
    },
  );

  test(
    'records use exact original decimals rather than painting coordinates',
    () {
      final data = model([
        source('low', load: '9999999.999998'),
        source('high', load: '9999999.999999'),
      ]);
      MeasuredPoint distorted(MeasuredPoint p) => MeasuredPoint(
        identity: p.identity,
        workoutId: p.workoutId,
        exerciseId: p.exerciseId,
        setId: p.setId,
        workoutName: p.workoutName,
        exerciseName: p.exerciseName,
        startedAt: p.startedAt,
        exerciseOrdinal: p.exerciseOrdinal,
        setOrdinal: p.setOrdinal,
        setClass: p.setClass,
        purpose: p.purpose,
        status: p.status,
        repetitions: p.repetitions,
        load: MeasuredLoad(
          p.load!.original,
          p.load!.unit,
          p.workoutId == 'low' ? 1000 : 0,
        ),
        correctionReason: null,
        conflict: false,
      );
      final result = MeasuredProgress(
        data.identity,
        data.repetitions.map(distorted).toList(),
        0,
      );
      expect(result.records.highestLoads['kg']!.source.workoutId, 'high');
      expect(result.records.repetitionsAtLoad['kg'], hasLength(2));
    },
  );

  test('units are separate and original values do not change', () {
    final a = source('kg', load: '100.0000');
    final b = source('lb', load: '220', unit: 'lb');
    final before = [canonicalJson(a), canonicalJson(b)];
    final book = model([a, b]).records;
    expect(book.highestLoads.keys.toSet(), {'kg', 'lb'});
    expect(book.highestLoads['kg']!.source.load!.original, '100.0000');
    expect(book.highestLoads['lb']!.source.load!.original, '220');
    expect([canonicalJson(a), canonicalJson(b)], before);
    expect(() => book.highestLoads.clear(), throwsUnsupportedError);
    expect(() => book.repetitionsAtLoad['kg']!.clear(), throwsUnsupportedError);
  });

  test(
    'zero is a rep record context but never a positive-load achievement',
    () {
      final book = model([
        source('zero', load: '0.000000', reps: 12),
        source('unknown', load: null, reps: 99),
      ]).records;
      expect(book.highestLoads, isEmpty);
      expect(book.repetitionsAtLoad['kg'], hasLength(1));
      expect(book.repetitionsAtLoad['kg']!.single.source.workoutId, 'zero');
    },
  );

  for (final basis in [
    'total_external',
    'per_implement',
    'machine_stack',
    'added_bodyweight',
  ]) {
    test('$basis supports positive records within its exact identity', () {
      final book = model([
        source('a', basis: basis, load: '0'),
        source('b', basis: basis, load: '1'),
      ]).records;
      expect(book.highestLoads['kg']!.source.workoutId, 'b');
    });
  }

  test(
    'assistance has contextual rep groups and no highest-load achievement',
    () {
      final book = model([
        source('more', basis: 'assistance', load: '100'),
        source('less', basis: 'assistance', load: '10', reps: 9),
      ]).records;
      expect(book.highestLoads, isEmpty);
      expect(book.repetitionsAtLoad['kg'], hasLength(2));
      expect(book.repetitionsAtLoad['kg']!.last.source.repetitions, 9);
    },
  );
  test('bodyweight rep record retains absence of mass and load', () {
    final book = model([
      source('a', basis: 'bodyweight_only', load: null, reps: 8),
      source('b', basis: 'bodyweight_only', load: null, reps: 12),
    ]).records;
    expect(book.highestLoads, isEmpty);
    expect(book.repetitionsAtLoad, isEmpty);
    expect(book.bodyweightRepetitions!.source.workoutId, 'b');
    expect(book.bodyweightRepetitions!.source.load, isNull);
  });

  for (final value in [
    'warmup',
    'failed',
    'partial',
    'skipped',
    'unperformed',
    'active',
    'abandoned',
  ]) {
    test('$value cannot displace an eligible completed working set', () {
      final invalid = source(
        'invalid',
        load: '999',
        reps: 99,
        setClass: value == 'warmup' ? 'warmup' : 'working',
        outcome: ['failed', 'partial', 'skipped', 'unperformed'].contains(value)
            ? value
            : 'completed',
        status: ['active', 'abandoned'].contains(value) ? value : 'completed',
      );
      final book = model([source('valid', load: '10'), invalid]).records;
      expect(book.highestLoads['kg']!.source.workoutId, 'valid');
      expect(book.repetitionsAtLoad['kg'], hasLength(1));
    });
  }
  for (final axis in ['variant', 'basis', 'convention', 'side']) {
    test('$axis never joins another comparison identity', () {
      final valid = source('valid');
      final other = source(
        'other',
        load: '999',
        variant: axis == 'variant' ? 'different' : 'variant-a',
        basis: axis == 'basis' ? 'per_implement' : 'total_external',
        side: axis == 'side' ? 'left' : 'both',
        convention: axis == 'convention' ? 'per_side' : 'bilateral',
      );
      expect(
        model(
          [valid, other],
          valid['exercises'][0] as Json,
        ).records.highestLoads['kg']!.source.workoutId,
        'valid',
      );
    });
  }
  test(
    'correction and removal rebuild records without mutating a detached result',
    () {
      final a = source('a', load: '100', reps: 8);
      final b = source('b', load: '80', reps: 10);
      final old = model([a, b]);
      a['exercises'][0]['sets'][0]['observation']['actual']['load']['value'] =
          '70';
      a['exercises'][0]['sets'][0]['observation']['correction_reason'] =
          'Corrected load';
      final corrected = model([a, b]);
      expect(corrected.records.highestLoads['kg']!.source.workoutId, 'b');
      expect(old.records.highestLoads['kg']!.source.load!.original, '100');
      expect(
        model([a]).records.highestLoads['kg']!.source.load!.original,
        '70',
      );
    },
  );
}
