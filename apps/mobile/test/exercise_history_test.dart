import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

Json exercise({
  String variant = 'variant-a',
  String name = 'Same name',
  String basis = 'total_external',
  String reps = 'bilateral',
  String? side = 'both',
  String status = 'completed',
  String? load = '0',
  String unit = 'kg',
  String setClass = 'working',
}) => {
  'session_exercise_id': 'instance-$variant-$side',
  'variant_id': variant,
  'name': name,
  'loading_basis': basis,
  'rep_convention': reps,
  'side': side,
  'sets': [
    {
      'set_id': 'set-$variant-$side',
      'set_class': setClass,
      'set_purpose': 'regular',
      'planned': {
        'load': {'value': '99', 'unit': 'kg'},
        'reps': 99,
      },
      'observation': status == 'unperformed'
          ? null
          : {
              'execution_status': status,
              'completion_seq': 1,
              'actual': status == 'skipped'
                  ? null
                  : {
                      'load': load == null
                          ? null
                          : {'value': load, 'unit': unit, 'basis': basis},
                      'reps': 5,
                      'rep_convention': reps,
                      'effort': null,
                    },
            },
    },
  ],
};

Json workout(
  String id,
  List<Json> exercises, {
  String status = 'completed',
  String date = '2026-10-25T12:00:00Z',
}) => {
  'aggregate_id': id,
  'name': 'Workout $id',
  'started_at': date,
  'status': status,
  'exercises': exercises,
};

void main() {
  test('browser recency comes from recorded work rather than a newer unperformed prescription', () {
    final a = exercise(variant: 'a');
    final b = exercise(variant: 'b');
    final index = buildExerciseHistory([
      workout('pending', [exercise(variant: 'a', status: 'unperformed')]),
      workout('b-recorded', [b], date: '2026-10-24T12:00:00Z'),
      workout('a-recorded', [a], date: '2026-10-23T12:00:00Z'),
    ]);
    expect(index.exercises.map((e) => e.key.variant), ['b', 'a']);
    expect(
      index.byExercise[exerciseKey(a)]!.latestRecorded.workout['aggregate_id'],
      'a-recorded',
    );
  });
  for (final field in [
    'variant_id',
    'loading_basis',
    'rep_convention',
    'side',
  ]) {
    test('comparison separates $field even with identical names', () {
      final a = exercise();
      final b = copyJson(a)
        ..[field] = switch (field) {
          'variant_id' => 'variant-b',
          'loading_basis' => 'machine_stack',
          'rep_convention' => 'alternating_total',
          _ => 'left',
        };
      final index = buildExerciseHistory([
        workout('one', [a, b]),
      ]);
      expect(index.exercises, hasLength(2));
      expect(
        index
            .byExercise[exerciseKey(a)]!
            .visits
            .single
            .occurrences
            .single
            .exercise,
        a,
      );
    });
  }
  test('renames keep stable identity and both labels remain searchable', () {
    final old = exercise(name: 'Old name');
    final next = exercise(name: 'New name');
    final history = buildExerciseHistory([
      workout('old', [old], date: '2026-10-24T12:00:00Z'),
      workout('new', [next]),
    ]).exercises.single;
    expect(history.name, 'New name');
    expect(history.names, {'Old name', 'New name'});
    expect(history.recordedWorkouts, 2);
  });
  test('unspecified side never becomes bilateral or left by inference', () {
    final entries = [
      exercise(side: null),
      exercise(side: 'unspecified'),
      exercise(side: 'both'),
      exercise(side: 'left'),
    ];
    final index = buildExerciseHistory([workout('one', entries)]);
    expect(index.exercises, hasLength(3));
    expect(
      index.byExercise[exerciseKey(entries.first)]!.visits.single.occurrences,
      hasLength(2),
    );
  });
  test('repeated instances retain distinct source sets without multiplying workout counts', () {
    final a = exercise();
    final b = copyJson(a)..['session_exercise_id'] = 'second-instance';
    b['sets'][0]['set_id'] = 'second-set';
    final history = buildExerciseHistory([
      workout('one', [a, b]),
    ]).exercises.single;
    expect(history.recordedWorkouts, 1);
    final visit = history.previous()!;
    expect(visit.completedWorking.map((p) => p.$2['set_id']), [
      'set-variant-a-both',
      'second-set',
    ]);
    expect(visit.occurrences.map((e) => e.ordinal), [0, 1]);
  });
  for (final status in ['partial', 'failed', 'skipped', 'unperformed']) {
    test('$status is never a previous completed working result', () {
      final original = workout('old', [
        exercise(),
      ], date: '2026-10-24T12:00:00Z');
      final latest = workout('new', [exercise(status: status)]);
      final h = buildExerciseHistory([latest, original]).exercises.single;
      expect(h.previous()!.workout['aggregate_id'], 'old');
      expect(
        h
            .visits
            .first
            .occurrences
            .single
            .sets
            .single['observation']?['execution_status'],
        status == 'unperformed' ? null : status,
      );
    });
  }
  test('active, abandoned and warmup observations cannot replace the last completed working reference', () {
    final index = buildExerciseHistory([
      workout(
        'active',
        [exercise()],
        status: 'active',
        date: '2026-10-28T12:00:00Z',
      ),
      workout(
        'abandoned',
        [exercise()],
        status: 'abandoned',
        date: '2026-10-27T12:00:00Z',
      ),
      workout('warmup', [
        exercise(setClass: 'warmup'),
      ], date: '2026-10-26T12:00:00Z'),
      workout('complete', [exercise()]),
    ]);
    final h = index.exercises.single;
    expect(h.visits, hasLength(3));
    expect(h.previous()!.workout['aggregate_id'], 'complete');
    expect(h.previous(excludingSession: 'complete'), isNull);
    expect(h.visits.first.workout['status'], 'abandoned');
  });
  test('unperformed prescriptions never create a browse entry', () {
    expect(
      buildExerciseHistory([
        workout('one', [exercise(status: 'unperformed')]),
      ]).exercises,
      isEmpty,
    );
    expect(
      buildExerciseHistory([
        workout('active', [exercise()], status: 'active'),
      ]).exercises,
      isEmpty,
    );
  });
  test('latest effective correction replaces rather than doubles the original value', () {
    final e = exercise();
    final w = workout('one', [e]);
    final original = buildExerciseHistory([w]);
    expect(
      original.exercises.single
          .previous()!
          .completedWorking
          .single
          .$2['observation']['actual']['reps'],
      5,
    );
    final changed = copyJson(w);
    changed['exercises'][0]['sets'][0]['observation']['actual']['reps'] = 8;
    changed['exercises'][0]['sets'][0]['observation']['correction_reason'] =
        'Actual log correction';
    final corrected = buildExerciseHistory([changed]).exercises.single;
    expect(corrected.previous()!.completedWorking, hasLength(1));
    expect(
      corrected
          .previous()!
          .completedWorking
          .single
          .$2['observation']['actual']['reps'],
      8,
    );
    changed['exercises'][0]['sets'][0]['observation']['execution_status'] =
        'skipped';
    changed['exercises'][0]['sets'][0]['observation']['actual'] = null;
    final skipped = buildExerciseHistory([changed]).exercises.single;
    expect(skipped.previous(), isNull);
    expect(skipped.recordedWorkouts, 1);
  });
  test(
    'source workout time orders history, not input order or correction time',
    () {
      final a = workout('older', [exercise()], date: '2026-10-23T12:00:00Z');
      a['exercises'][0]['sets'][0]['observation']['recorded_at'] =
          '2026-10-28T12:00:00Z';
      final b = workout('newer', [exercise()]);
      expect(
        buildExerciseHistory([a, b]).exercises.single.visits
            .map((v) => v.workout['aggregate_id']),
        ['newer', 'older'],
      );
    },
  );
  test('original kg/lb, actual zero, missing load and assistance retain their meaning', () {
    final zero = exercise();
    final pounds = exercise(load: '20', unit: 'lb');
    final body = exercise(
      variant: 'body',
      basis: 'bodyweight_only',
      load: null,
    );
    final help = exercise(variant: 'help', basis: 'assistance', load: '7');
    final index = buildExerciseHistory([
      workout('one', [zero, pounds, body, help]),
    ]);
    final recorded = index.byExercise[exerciseKey(zero)]!
        .previous()!
        .completedWorking
        .toList();
    expect(recorded.map((p) => observationUnit(p.$2)), ['kg', 'lb']);
    expect(recorded.first.$2['observation']['actual']['load']['value'], '0');
    expect(observationUnit(body['sets'][0] as Json), 'no recorded load');
    expect(help['sets'][0]['observation']['actual']['load']['value'], '7');
    expect(index.byExercise[exerciseKey(body)]!.previous(), isNotNull);
  });
}
