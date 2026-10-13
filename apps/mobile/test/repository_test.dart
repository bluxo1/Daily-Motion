import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = '20000000-0000-4000-8000-000000000001';
Json fixture() =>
    jsonDecode(File('../../contracts/fixtures/workout.json').readAsStringSync())
        as Json;

Json recordPayload(
  Json state, {
  int index = 0,
  int reps = 5,
  String status = 'completed',
}) {
  final exercise = (state['exercises'] as List).first as Json;
  final item = (exercise['sets'] as List)[index] as Json;
  return {
    'session_exercise_id': exercise['session_exercise_id'],
    'set_id': item['set_id'],
    'execution_status': status,
    'actual': status == 'skipped'
        ? null
        : {
            'load': {'value': '60', 'unit': 'kg', 'basis': 'total_external'},
            'reps': reps,
            'rep_convention': 'bilateral',
            'effort': null,
          },
    'completion_seq': completionSequence(state) + 1,
    'order_source': 'logged',
  };
}

Future<String> create(WorkoutRepository repo) async {
  final op = fixture();
  await repo.commit(
    op['aggregate_id'] as String,
    'create_session',
    op['payload'] as Json,
  );
  return op['aggregate_id'] as String;
}

Future<Json> acknowledgeHead(
  WorkoutRepository repo,
  String id,
  int revision,
) async {
  final body = (await repo.prepareHead(id))!;
  final op = jsonDecode(body) as Json;
  await repo.acknowledge({
    'mutation_id': op['mutation_id'],
    'aggregate_id': id,
    'status': 'accepted',
    'accepted_revision': revision,
  });
  return op;
}

void main() {
  late TrainingDatabase db;
  late WorkoutRepository repo;
  setUp(() async {
    db = TrainingDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  });
  tearDown(() async {
    await db.close();
  });

  test(
    'a duplicate tap records one observation and one outbox action',
    () async {
      final id = await create(repo);
      final state = (await repo.workout(id))!;
      final payload = recordPayload(state);
      expect(await repo.commit(id, 'record_set', payload), isTrue);
      expect(await repo.commit(id, 'record_set', payload), isFalse);
      expect(await repo.pendingCount(), 2);
      final actual = (await repo.workout(id))!;
      expect(actual['local_seq'], 2);
      expect(allSets(actual).where((s) => s['observation'] != null).length, 1);
      expect(allSets(actual).first['planned']['reps'], 5);
      expect(allSets(actual).first['observation']['actual']['effort'], isNull);
    },
  );

  test(
    'SQL failure rolls back the projection, revision, timer and outbox',
    () async {
      final id = await create(repo);
      final state = (await repo.workout(id))!;
      final setId = allSets(state).first['set_id'] as String;
      await repo.saveDraft(setId, {'load': '70', 'reps': '6'});
      await db.customStatement(
        "CREATE TRIGGER fail_observation BEFORE INSERT ON local_observations BEGIN SELECT RAISE(ABORT, 'synthetic storage failure'); END",
      );
      await expectLater(
        repo.commit(id, 'record_set', recordPayload(state)),
        throwsA(anything),
      );
      expect((await repo.workout(id))!['local_seq'], 1);
      expect(allSets((await repo.workout(id))!).first['observation'], isNull);
      expect(await repo.pendingCount(), 1);
      expect(await repo.timerDeadline(id), isNull);
      expect((await repo.draft(setId))!['load'], '70');
    },
  );

  test(
    'file reopen restores active work, draft, timer and frozen retry',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'daily-motion-restart-',
      );
      final file = File('${directory.path}/training.sqlite');
      final first = TrainingDatabase.open(file);
      final initial = WorkoutRepository(
        first,
        owner,
        clock: () => DateTime.utc(2026, 10, 12, 13),
      );
      await initial.initialize();
      final id = await create(initial);
      final before = (await initial.workout(id))!;
      await initial.commit(id, 'record_set', recordPayload(before));
      final nextId =
          allSets((await initial.workout(id))!).elementAt(1)['set_id']
              as String;
      await initial.saveDraft(nextId, {'load': '62.5', 'reps': '6'});
      final frozen = await initial.prepareHead(id);
      await first.close();
      final reopened = TrainingDatabase.open(file);
      try {
        final restored = WorkoutRepository(reopened, owner);
        await restored.initialize();
        expect((await restored.workout(id))!['status'], 'active');
        expect(
          allSets((await restored.workout(id))!)
              .first['observation']['actual']['reps'],
          5,
        );
        expect((await restored.draft(nextId))!['load'], '62.5');
        expect(
          await restored.timerDeadline(id),
          DateTime.utc(2026, 10, 12, 13, 2),
        );
        expect(await restored.prepareHead(id), frozen);
        expect(await restored.pendingCount(), 2);
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('empty completion and a second active workout are refused', () async {
    final id = await create(repo);
    await expectLater(
      repo.commit(id, 'complete_session', {}),
      throwsA(isA<WorkoutValidation>()),
    );
    await expectLater(
      repo.startFoundationWorkout(),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await repo.pendingCount(), 1);
  });

  test('a reused child ID cannot corrupt a previous session', () async {
    final id = await create(repo);
    await repo.commit(id, 'abandon_session', {});
    final body = fixture();
    await expectLater(
      repo.commit(
        '30000000-0000-4000-8000-000000000001',
        'create_session',
        body['payload'] as Json,
      ),
      throwsA(isA<WorkoutValidation>()),
    );
    expect((await repo.workouts()).length, 1);
    expect(allSets((await repo.workout(id))!).length, 3);
  });

  test(
    'sign-out locks data and account switching never retags pending work',
    () async {
      final id = await create(repo);
      await repo.signOut();
      await expectLater(repo.workouts(), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.prepareHead(id),
        throwsA(isA<WorkoutValidation>()),
      );
      final other = WorkoutRepository(
        db,
        '20000000-0000-4000-8000-000000000002',
      );
      await expectLater(other.initialize(), throwsA(isA<WorkoutValidation>()));
      await expectLater(
        repo.unlockVerifiedOwner(other.ownerId),
        throwsA(isA<WorkoutValidation>()),
      );
      await repo.unlockVerifiedOwner(owner);
      expect(await repo.pendingCount(), 1);
    },
  );

  test('pending branches survive newer pulls and a late own receipt', () async {
    final id = await create(repo);
    final createOp = await acknowledgeHead(repo, id, 1);
    final local = (await repo.workout(id))!;
    await repo.commit(id, 'record_set', recordPayload(local));
    final frozen = await repo.prepareHead(id);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    var remote = applyOperation(null, createOp, revision: 1)!;
    remote = applyOperation(remote, {
      'command': 'record_set',
      'aggregate_id': id,
      'occurred_at': '2026-10-12T13:00:00Z',
      'recorded_at': '2026-10-12T13:00:00Z',
      'payload': recordPayload(remote, reps: 9),
    }, revision: 3)!;
    await repo.installRemote(remote);
    expect(
      allSets((await repo.workout(id))!).first['observation']['actual']['reps'],
      5,
    );
    expect(await repo.prepareHead(id), frozen);
    final op = jsonDecode(frozen!) as Json;
    await repo.acknowledge({
      'mutation_id': op['mutation_id'],
      'aggregate_id': id,
      'status': 'accepted',
      'accepted_revision': 2,
    });
    final successor = jsonDecode((await repo.prepareHead(id))!) as Json;
    expect(
      successor['expected_revision'],
      2,
    ); // Own predecessor, not pulled revision 3.
    final shadow = await db
        .customSelect('SELECT revision FROM shadows')
        .getSingle();
    expect(shadow.read<int>('revision'), 3);
  });

  test('bootstrap checksum failure never partially activates and local-only work survives', () async {
    final id = await create(repo);
    final pages = <Json>[
      {'roots': <Json>[]},
    ];
    await expectLater(
      repo.installBootstrap(pages, ['bad'], 'bad-cursor'),
      throwsA(isA<WorkoutValidation>()),
    );
    expect((await repo.workout(id))!['status'], 'active');
    final digest = sha256
        .convert(utf8.encode(canonicalJson(pages.single)))
        .toString();
    await repo.installBootstrap(pages, [digest], 'valid-cursor');
    expect((await repo.workout(id))!['status'], 'active');
    expect(await repo.pendingCount(), 1);
  });

  test(
    'corrections retain revisions and never reopen a completed session',
    () async {
      final id = await create(repo);
      final payload = recordPayload((await repo.workout(id))!);
      await repo.commit(id, 'record_set', payload);
      await repo.commit(id, 'complete_session', {});
      final correction = copyJson(payload);
      correction['actual']['reps'] = 6;
      correction['correction_reason'] = 'Corrected entry';
      await repo.commit(id, 'correct_set', correction);
      expect((await repo.workout(id))!['status'], 'completed');
      expect(
        allSets((await repo.workout(id))!)
            .first['observation']['actual']['reps'],
        6,
      );
      expect(
        (await db.customSelect('SELECT * FROM local_observations').get())
            .length,
        2,
      );
    },
  );

  test('oversized rejected edit retains its draft and cannot strand an outbox head', () async {
    final id = await create(repo);
    final state = (await repo.workout(id))!;
    final setId = allSets(state).first['set_id'] as String;
    await repo.saveDraft(setId, {'load': '60', 'reps': '5'});
    final payload = recordPayload(state)
      ..['oversized'] = 'x' * commandByteLimit;
    await expectLater(
      repo.commit(id, 'record_set', payload),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await repo.pendingCount(), 1);
    expect(await repo.draft(setId), isNotNull);
  });
}
