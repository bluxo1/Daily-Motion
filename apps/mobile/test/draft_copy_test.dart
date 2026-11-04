import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner, fixture, create, recordPayload;

const entry = <String, dynamic>{
  'load': '40',
  'unit': 'lb',
  'reps': '8',
  'effort': '5',
  'effort_scale': 'rpe',
  'execution_status': 'completed',
};

Future<String> recorded(
  WorkoutRepository repo, {
  String status = 'completed',
  bool warmup = false,
}) async {
  final op = fixture();
  if (warmup) op['payload']['exercises'][0]['sets'][0]['set_class'] = 'warmup';
  final id = op['aggregate_id'] as String;
  await repo.commit(id, 'create_session', op['payload'] as Json);
  final state = (await repo.workout(id))!;
  final payload = recordPayload(state, status: status);
  payload['actual']['load']['value'] = '60.000001';
  payload['actual']['effort'] = {
    'value': '3',
    'scale': 'rir',
    'source': 'self_reported',
  };
  await repo.commit(id, 'record_set', payload);
  return id;
}

void main() {
  late TrainingDatabase db;
  late WorkoutRepository repo;
  setUp(() async {
    db = TrainingDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  });
  tearDown(() async => db.close());
  Future<String> target(String id) async =>
      allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;

  test('copy is draft only, exact units and decimals, effort blank; frozen bytes unchanged', () async {
    final id = await recorded(repo);
    final set = await target(id);
    final before = canonicalJson(await repo.workout(id));
    final frozen = await repo.prepareHead(id);
    final count = await repo.pendingCount();
    final preview = await repo.previewSetDraftCopy(id, set, entry);
    expect(preview.sourceOrdinal, 1);
    expect(preview.targetOrdinal, 2);
    // A caller's editable copy cannot mutate the confirmed preview itself.
    preview.values['load'] = '999';
    final result = await repo.applySetDraftCopy(preview);
    expect(result, {
      ...entry,
      'load': '60.000001',
      'unit': 'kg',
      'reps': '5',
      'effort': '',
    });
    expect(await repo.draft(set), result);
    expect(canonicalJson(await repo.workout(id)), before);
    expect(await repo.prepareHead(id), frozen);
    expect(await repo.pendingCount(), count);
    await expectLater(
      repo.applySetDraftCopy(preview),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(
      allSets((await repo.workout(id))!).where((s) => s['observation'] != null),
      hasLength(1),
    );
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    expect(
      allSets((await repo.workout(id))!).where((s) => s['observation'] != null),
      hasLength(2),
    );
  });
  for (final kind in ['partial', 'failed', 'warmup', 'unperformed']) {
    test('$kind is not an eligible completed working source', () async {
      final id = kind == 'unperformed'
          ? await create(repo)
          : await recorded(
              repo,
              status: kind == 'warmup' ? 'completed' : kind,
              warmup: kind == 'warmup',
            );
      await expectLater(
        repo.previewSetDraftCopy(id, await target(id), entry),
        throwsA(isA<WorkoutValidation>()),
      );
    });
  }
  test(
    'changed local draft invalidates preview and preserves newer draft',
    () async {
      final id = await recorded(repo);
      final set = await target(id);
      final preview = await repo.previewSetDraftCopy(id, set, entry);
      await repo.saveDraft(set, {...entry, 'load': '99'});
      await expectLater(
        repo.applySetDraftCopy(preview),
        throwsA(isA<WorkoutValidation>()),
      );
      expect((await repo.draft(set))!['load'], '99');
    },
  );
  test(
    'changed branch invalidates preview; observed target cannot be overwritten',
    () async {
      final id = await recorded(repo);
      final set = await target(id);
      final preview = await repo.previewSetDraftCopy(id, set, entry);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1),
      );
      await expectLater(
        repo.applySetDraftCopy(preview),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        repo.previewSetDraftCopy(id, set, entry),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );
  test('transaction failure preserves original draft and projection', () async {
    final id = await recorded(repo);
    final set = await target(id);
    await repo.saveDraft(set, entry);
    final before = canonicalJson(await repo.workout(id));
    final preview = await repo.previewSetDraftCopy(id, set, entry);
    await db.customStatement(
      "CREATE TRIGGER fail_copy BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
    );
    await expectLater(repo.applySetDraftCopy(preview), throwsA(anything));
    expect(await repo.draft(set), entry);
    expect(canonicalJson(await repo.workout(id)), before);
  });
  test(
    'lock, wrong owner and another installation cannot apply a preview',
    () async {
      final id = await recorded(repo);
      final set = await target(id);
      final preview = await repo.previewSetDraftCopy(id, set, entry);
      await expectLater(
        WorkoutRepository(
          db,
          '20000000-0000-4000-8000-000000000099',
        ).applySetDraftCopy(preview),
        throwsA(isA<WorkoutValidation>()),
      );
      final other = TrainingDatabase(NativeDatabase.memory());
      try {
        final second = WorkoutRepository(other, owner);
        await second.initialize();
        await recorded(second);
        await expectLater(
          second.applySetDraftCopy(preview),
          throwsA(isA<WorkoutValidation>()),
        );
      } finally {
        await other.close();
      }
      await repo.signOut();
      await expectLater(
        repo.applySetDraftCopy(preview),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );
  test(
    'unknown draft fields fail closed without dropping their content',
    () async {
      final id = await recorded(repo);
      final set = await target(id);
      await repo.saveDraft(set, {...entry, 'future': 'preserve'});
      await expectLater(
        repo.previewSetDraftCopy(id, set, entry),
        throwsA(isA<WorkoutValidation>()),
      );
      expect((await repo.draft(set))!['future'], 'preserve');
    },
  );
  test('authoritative disable between preview and confirmation prevents resurrection', () async {
    final id = await recorded(repo);
    final set = await target(id);
    final preview = await repo.previewSetDraftCopy(id, set, entry);
    await repo.disableRemoteAccount();
    await expectLater(
      repo.applySetDraftCopy(preview),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await db.customSelect('SELECT * FROM drafts').get(), isEmpty);
  });
  test(
    'nearest predecessor is selected; abandoned workouts cannot copy',
    () async {
      final id = await recorded(repo);
      final payload = recordPayload(
        (await repo.workout(id))!,
        index: 1,
        reps: 7,
      );
      payload['actual']['load']['value'] = '65';
      await repo.commit(id, 'record_set', payload);
      final last = allSets((await repo.workout(id))!).last['set_id'] as String;
      final preview = await repo.previewSetDraftCopy(id, last, entry);
      expect(preview.sourceOrdinal, 2);
      expect(preview.values['load'], '65');
      expect(preview.values['reps'], '7');
      await repo.commit(id, 'abandon_session', {});
      await expectLater(
        repo.applySetDraftCopy(preview),
        throwsA(isA<WorkoutValidation>()),
      );
      await expectLater(
        repo.previewSetDraftCopy(id, last, entry),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );
  test(
    'same variant in a different exercise instance cannot supply copied values',
    () async {
      final op = fixture();
      final second = copyJson(op['payload']['exercises'][0] as Json);
      second['session_exercise_id'] = '10000000-0000-4000-8000-000000000099';
      var index = 20;
      for (final set in second['sets'] as List) {
        set['set_id'] = '10000000-0000-4000-8000-0000000000${index++}';
      }
      op['payload']['exercises'].add(second);
      final id = op['aggregate_id'] as String;
      await repo.commit(id, 'create_session', op['payload'] as Json);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      await expectLater(
        repo.previewSetDraftCopy(
          id,
          second['sets'][0]['set_id'] as String,
          entry,
        ),
        throwsA(isA<WorkoutValidation>()),
      );
    },
  );
  test(
    'real file reopen restores draft without inventing a performed set',
    () async {
      final dir = await Directory.systemTemp.createTemp('draft-copy-');
      final file = File('${dir.path}/training.sqlite');
      var store = TrainingDatabase(NativeDatabase(file));
      try {
        var local = WorkoutRepository(store, owner);
        await local.initialize();
        final id = await recorded(local);
        final set =
            allSets((await local.workout(id))!).elementAt(1)['set_id']
                as String;
        await local.applySetDraftCopy(
          await local.previewSetDraftCopy(id, set, entry),
        );
        await store.close();
        store = TrainingDatabase(NativeDatabase(file));
        local = WorkoutRepository(store, owner);
        await local.initialize();
        expect((await local.draft(set))!['load'], '60.000001');
        expect(
          allSets((await local.workout(id))!)
              .where((s) => s['observation'] != null),
          hasLength(1),
        );
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
