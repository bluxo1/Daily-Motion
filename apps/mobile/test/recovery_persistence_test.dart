import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import 'repository_test.dart' show recordPayload;
import 'support/legacy_schema.dart';
import 'support/sync_server.dart';

RecoveryContext context({
  String ownerId = testOwner,
  int serial = 1,
  String incarnation = '30000000-0000-4000-8000-000000000002',
  String generation = '30000000-0000-4000-8000-000000000003',
  int order = 2,
  String digest = 'a',
  int epoch = 3,
  int position = 5,
}) => RecoveryContext(
  ownerId: ownerId,
  environmentId: '30000000-0000-4000-8000-000000000001',
  incarnation: incarnation,
  generation: generation,
  activationSerial: serial,
  evidenceOrder: order,
  evidenceDigest: digest * 64,
  erasureEpoch: epoch,
  position: position,
);

void main() {
  late Directory directory;
  late File file;
  late TrainingDatabase db;
  late WorkoutRepository repo;

  Future<void> open() async {
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
  }

  Future<void> close() async {
    repo.dispose();
    await db.close();
  }

  Future<void> reopen() async {
    await close();
    await open();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('drp2-persistence-');
    file = File('${directory.path}/training.sqlite');
    await open();
  });
  tearDown(() async {
    await close();
    await directory.delete(recursive: true);
  });

  for (final status in ['accepted', 'conflict', 'rejected']) {
    test('historical $status result immediately needs attention after restart', () async {
      final first = context();
      await repo.installRecoveryContext(first);
      final id = await repo.startFoundationWorkout();
      final frozen = (await repo.prepareHead(id))!;
      final operation = jsonDecode(frozen) as Json;
      final digest = sha256.convert(utf8.encode(frozen)).toString();
      await repo.installRecoveryContext(
        context(
          serial: 2,
          incarnation: '30000000-0000-4000-8000-000000000004',
          generation: '30000000-0000-4000-8000-000000000005',
          order: 4,
          digest: 'b',
        ),
      );
      // No upload/prepareHead follows the context change. The historical fact
      // itself must durably require attention without another network attempt.
      expect(await repo.attentionCount(), 0);
      final result = <String, dynamic>{
        'mutation_id': operation['mutation_id'],
        'aggregate_id': id,
        'status': status,
        if (status == 'accepted') ...{
          'accepted_revision': 1,
          'accepted_at': '2026-10-22T00:00:00Z',
        } else ...{
          'error': {
            'code': status == 'conflict' ? 'revision_conflict' : 'retired_id',
            'retryable': false,
          },
          if (status == 'conflict') ...{
            'expected_revision': 0,
            'current_revision': 2,
          },
        },
      };
      Future<void> record() => repo.recordHistoricalResult(
        result: result,
        requestDigest: digest,
        originalContext: first,
      );
      final before = canonicalJson(
        (await db.customSelect('SELECT * FROM outbox').getSingle()).data,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_history_attention BEFORE INSERT ON historical_receipts BEGIN SELECT RAISE(ABORT,'synthetic history failure'); END",
      );
      await expectLater(record(), throwsA(anything));
      await reopen();
      expect(await repo.attentionCount(), 0);
      expect(
        await db.customSelect('SELECT * FROM historical_receipts').get(),
        isEmpty,
      );
      await db.customStatement('DROP TRIGGER fail_history_attention');
      await record();
      await reopen();
      expect(await repo.attentionCount(), 1);
      await record();
      expect(await repo.attentionCount(), 1);
      expect(await repo.pendingCount(), 1);
      expect((await repo.workout(id))!['conflict'], false);
      expect(
        canonicalJson(
          (await db.customSelect('SELECT * FROM outbox').getSingle()).data,
        ),
        before,
      );
    });

    test(
      'historical $status result persists without acknowledging a divergent local branch',
      () async {
        final first = context();
        await repo.installRecoveryContext(first);
        final id = await repo.startFoundationWorkout();
        final frozen = (await repo.prepareHead(id))!;
        final operation = jsonDecode(frozen) as Json;
        final digest = sha256.convert(utf8.encode(frozen)).toString();
        await repo.markAttempts([operation['mutation_id'] as String]);
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!),
        );
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!, index: 1),
        );
        final draftId =
            allSets((await repo.workout(id))!).elementAt(2)['set_id'] as String;
        await repo.saveDraft(draftId, {'reps': '8'});
        final next = context(
          serial: 2,
          incarnation: '30000000-0000-4000-8000-000000000004',
          generation: '30000000-0000-4000-8000-000000000005',
          order: 4,
          digest: 'b',
          epoch: 4,
          position: 0,
        );
        await repo.installRecoveryContext(next);
        expect(await repo.prepareHead(id), isNull);
        const preserved = [
          'outbox',
          'shadows',
          'sessions',
          'exercises',
          'workout_sets',
          'local_observations',
          'drafts',
          'rest_timers',
          'local_identity',
          'sync_metadata',
          'recovery_state',
          'bootstrap_stage',
          'bootstrap_pages',
        ];
        Future<Json> snapshot() async => {
          for (final table in preserved)
            table: [
              for (final row
                  in await db
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                row.data,
            ],
        };
        final before = canonicalJson(await snapshot());
        final result = <String, dynamic>{
          'mutation_id': operation['mutation_id'],
          'aggregate_id': id,
          'status': status,
          if (status == 'accepted') ...{
            'accepted_revision': 1,
            'accepted_at': '2026-10-22T00:00:00Z',
          } else ...{
            'error': {
              'code': status == 'conflict' ? 'revision_conflict' : 'retired_id',
              'retryable': false,
            },
            if (status == 'conflict') ...{
              'expected_revision': 0,
              'current_revision': 2,
            },
          },
        };
        await repo.signOut();
        await expectLater(
          repo.recordHistoricalResult(
            result: result,
            requestDigest: digest,
            originalContext: first,
          ),
          throwsA(anything),
        );
        final other = WorkoutRepository(
          db,
          '30000000-0000-4000-8000-000000000099',
        );
        try {
          await expectLater(
            other.recordHistoricalResult(
              result: result,
              requestDigest: digest,
              originalContext: first,
            ),
            throwsA(anything),
          );
        } finally {
          other.dispose();
        }
        await repo.unlockVerifiedOwner(testOwner);
        expect(canonicalJson(await snapshot()), before);
        await db.customStatement(
          "CREATE TRIGGER fail_historical BEFORE INSERT ON historical_receipts BEGIN SELECT RAISE(ABORT,'synthetic evidence write failure'); END",
        );
        await expectLater(
          repo.recordHistoricalResult(
            result: result,
            requestDigest: digest,
            originalContext: first,
          ),
          throwsA(anything),
        );
        await reopen();
        expect(canonicalJson(await snapshot()), before);
        expect(
          await db.customSelect('SELECT * FROM historical_receipts').get(),
          isEmpty,
        );
        await db.customStatement('DROP TRIGGER fail_historical');
        await repo.recordHistoricalResult(
          result: result,
          requestDigest: digest,
          originalContext: first,
        );
        await reopen();
        await repo.recordHistoricalResult(
          result: result,
          requestDigest: digest,
          originalContext: first,
        );
        expect(canonicalJson(await snapshot()), before);
        final history = await db
            .customSelect('SELECT * FROM historical_receipts')
            .get();
        expect(history, hasLength(1));
        final evidence =
            jsonDecode(history.single.read<String>('evidence')) as Json;
        expect(evidence['original_context'], first.json);
        expect(evidence['original_result'], result);
        expect(evidence['request_digest'], digest);
        expect(await repo.prepareHead(id), isNull);
        expect(await repo.pendingCount(), 3);
        expect((await repo.workout(id))!['conflict'], false);
        for (final bad in [
          () => repo.recordHistoricalResult(
            result: result,
            requestDigest: 'c' * 64,
            originalContext: first,
          ),
          () => repo.recordHistoricalResult(
            result: result,
            requestDigest: digest,
            originalContext: context(
              ownerId: '30000000-0000-4000-8000-000000000099',
            ),
          ),
          () => repo.recordHistoricalResult(
            result: result,
            requestDigest: digest,
            originalContext: next,
          ),
          () => repo.recordHistoricalResult(
            result: {...result, 'aggregate_id': next.incarnation},
            requestDigest: digest,
            originalContext: first,
          ),
          () => repo.recordHistoricalResult(
            result: {...result, 'status': 'duplicate'},
            requestDigest: digest,
            originalContext: first,
          ),
        ]) {
          await expectLater(bad(), throwsA(isA<ContractViolation>()));
        }
        expect(canonicalJson(await snapshot()), before);
        expect(
          (await db.customSelect('SELECT * FROM historical_receipts').get()),
          hasLength(1),
        );
        // A certified fact cannot silently change after it has been persisted.
        await expectLater(
          repo.recordHistoricalResult(
            result: status == 'accepted'
                ? {...result, 'accepted_at': '2026-10-22T00:00:01Z'}
                : {
                    ...result,
                    'error': {'code': 'not_found', 'retryable': false},
                  },
            requestDigest: digest,
            originalContext: first,
          ),
          throwsA(isA<ContractViolation>()),
        );
        expect(canonicalJson(await snapshot()), before);
      },
    );
  }

  test('projection/outbox/origin commit together and a failed insert never reports saved', () async {
    await repo.installRecoveryContext(context());
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    await repo.commit(id, 'complete_session', {});
    await db.customStatement(
      "CREATE TRIGGER fail_origin BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic origin write failure'); END",
    );
    var completions = 0;
    final subscription = repo.commits.listen((_) => completions++);
    await expectLater(repo.startFoundationWorkout(), throwsA(anything));
    expect(completions, 0);
    await subscription.cancel();
    await reopen();
    expect((await repo.workouts()).length, 1);
    expect((await repo.workout(id))!['status'], 'completed');
    expect(await repo.pendingCount(), 3);
    final origins = await db
        .customSelect('SELECT wire_version,origin_context FROM outbox')
        .get();
    expect(
      origins.every(
        (row) =>
            row.read<int>('wire_version') == 2 &&
            row.read<String>('origin_context') ==
                canonicalJson(context().origin),
      ),
      true,
    );
    await db.customStatement('DROP TRIGGER fail_origin');
    expect(await repo.startFoundationWorkout(), isNotEmpty);
    expect(await repo.pendingCount(), 4);
  });

  test('bootstrap context cannot stamp unknown work; independent new root captures known origin', () async {
    await repo.requireRecoveryProtocol();
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    await repo.commit(id, 'complete_session', {});
    final before =
        (await db
                .customSelect('SELECT operation FROM outbox ORDER BY local_seq')
                .get())
            .map((row) => row.read<String>('operation'))
            .toList();
    expect(await repo.prepareHead(id), isNull);
    await repo.installRecoveryContext(context());
    await reopen();
    expect(await repo.prepareHead(id), isNull);
    expect(
      (await db
              .customSelect('SELECT operation FROM outbox ORDER BY local_seq')
              .get())
          .map((row) => row.read<String>('operation'))
          .toList(),
      before,
    );
    expect((await repo.workout(id))!['conflict'], false);
    final independent = await repo.startFoundationWorkout();
    final body = jsonDecode((await repo.prepareHead(independent))!) as Json;
    expect(body['schema_version'], 2);
    for (final entry in context().origin.entries) {
      expect(body[entry.key], entry.value);
    }
    expect(await repo.attentionCount(), greaterThan(0));
  });

  test('new context and further logging preserve a frozen old branch and all successor origins', () async {
    final first = context();
    await repo.installRecoveryContext(first);
    final id = await repo.startFoundationWorkout();
    final frozen = await repo.prepareHead(id);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final next = context(
      serial: 2,
      incarnation: '30000000-0000-4000-8000-000000000004',
      generation: '30000000-0000-4000-8000-000000000005',
      order: 4,
      digest: 'b',
      epoch: 4,
      position: 0,
    );
    await repo.installRecoveryContext(next);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    expect(await repo.prepareHead(id), isNull);
    await reopen();
    final rows = await db
        .customSelect(
          'SELECT origin_context,frozen_body FROM outbox ORDER BY local_seq',
        )
        .get();
    expect(rows.first.read<String>('frozen_body'), frozen);
    expect(
      rows.every(
        (row) =>
            row.read<String>('origin_context') == canonicalJson(first.origin),
      ),
      true,
    );
    expect(
      allSets((await repo.workout(id))!)
          .where((set) => set['observation'] != null)
          .length,
      2,
    );
    await repo.commit(id, 'complete_session', {});
    final other = await repo.startFoundationWorkout();
    expect(
      jsonDecode((await repo.prepareHead(other))!)['origin_incarnation'],
      next.incarnation,
    );
  });

  test('schema three migration preserves every old row/blob and quarantines sent/unsent legacy work', () async {
    final server = SyncServer();
    final sync = SyncCoordinator(repo, server);
    final id = await repo.startFoundationWorkout();
    await sync.synchronize(force: true);
    await sync.close();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final frozen = await repo.prepareHead(id);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    final draftId =
        allSets((await repo.workout(id))!).elementAt(2)['set_id'] as String;
    await repo.saveDraft(draftId, {'reps': '7'});
    final timer = await repo.timerDeadline(id);
    final manifest = await server.bootstrap(
      (await repo.syncMetadata())['installation_id'] as String,
    );
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, await server.page(manifest.token, 0));
    await db.customStatement('UPDATE sessions SET has_conflict=1');
    await db.customStatement('UPDATE sync_metadata SET erasure_epoch=3');
    await reconstructSchemaThree(db);
    const tables = [
      'local_identity',
      'sessions',
      'exercises',
      'workout_sets',
      'local_observations',
      'outbox',
      'shadows',
      'drafts',
      'rest_timers',
      'retired_ids',
      'sync_metadata',
      'bootstrap_stage',
      'bootstrap_pages',
    ];
    final original = <String, List<Json>>{};
    for (final table in tables) {
      original[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((row) => Map<String, dynamic>.from(row.data))
              .toList();
    }
    await reopen();
    for (final table in tables) {
      final after = await db
          .customSelect('SELECT * FROM $table ORDER BY rowid')
          .get();
      expect(after.length, original[table]!.length);
      for (var i = 0; i < after.length; i++) {
        expect({
          for (final key in original[table]![i].keys) key: after[i].data[key],
        }, original[table]![i]);
      }
    }
    expect(await repo.timerDeadline(id), timer);
    expect(await repo.draft(draftId), {'reps': '7'});
    await repo.installRecoveryContext(context(epoch: 4));
    expect(await repo.prepareHead(id), isNull);
    final legacy = await db
        .customSelect('SELECT * FROM outbox ORDER BY local_seq')
        .get();
    expect(
      legacy.every(
        (row) =>
            row.read<int>('wire_version') == 1 &&
            row.readNullable<String>('origin_context') == null,
      ),
      true,
    );
    expect(legacy[1].read<String>('frozen_body'), frozen);
    await expectLater(
      repo.activateBootstrap(await server.me()),
      throwsA(isA<ContractViolation>()),
    );
    expect((await repo.stagedBootstrap())!.token, manifest.token);
  });

  test(
    'newer local schema is refused without downgrading or deleting work',
    () async {
      await repo.startFoundationWorkout();
      await db.customStatement('PRAGMA user_version=5');
      await close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await expectLater(
        repo.initialize(),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'reason',
            contains('newer training database'),
          ),
        ),
      );
      await db.close();
      final raw = native.sqlite3.open(file.path);
      try {
        expect(raw.select('PRAGMA user_version').single.values.single, 5);
        expect(
          raw.select('SELECT count(*) FROM sessions').single.values.single,
          1,
        );
        expect(
          raw.select('SELECT count(*) FROM outbox').single.values.single,
          1,
        );
        // Restore only this synthetic test's declared version so common teardown can close normally.
        raw.execute('PRAGMA user_version=4');
      } finally {
        raw.close();
      }
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
    },
  );

  test(
    'stale high-water, head, serial or other owner never changes saved context',
    () async {
      final first = context();
      await repo.installRecoveryContext(first);
      final id = await repo.startFoundationWorkout();
      final frozen = await repo.prepareHead(id);
      for (final stale in [
        context(epoch: 2),
        context(order: 1),
        context(digest: 'b'),
        context(position: 4),
        context(ownerId: '20000000-0000-4000-8000-000000000002'),
        context(incarnation: '30000000-0000-4000-8000-000000000004'),
      ]) {
        await expectLater(
          repo.installRecoveryContext(stale),
          throwsA(isA<ContractViolation>()),
        );
        expect((await repo.recoveryContext())!.json, first.json);
        expect(await repo.prepareHead(id), frozen);
      }
    },
  );

  test('failed schema upgrade leaves the old version and columns atomically intact', () async {
    final id = await repo.startFoundationWorkout();
    final frozen = await repo.prepareHead(id);
    await reconstructSchemaThree(db);
    // The final CREATE fails after earlier ALTERs; this tests real SQLite DDL
    // rollback rather than assuming the migration framework supplies a transaction.
    await db.customStatement(
      'CREATE INDEX historical_receipts ON sessions(id)',
    );
    await close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await expectLater(repo.initialize(), throwsA(anything));
    repo.dispose();
    await db.close();
    final raw = native.sqlite3.open(file.path);
    try {
      expect(raw.select('PRAGMA user_version').single.values.single, 3);
      final columns = raw
          .select('PRAGMA table_info(outbox)')
          .map((row) => row['name'])
          .toSet();
      expect(
        columns.contains('wire_version'),
        false,
        reason: 'Failed migration must roll back every earlier ALTER.',
      );
      expect(
        raw.select('SELECT frozen_body FROM outbox').single['frozen_body'],
        frozen,
      );
    } finally {
      // Repair only this test's intentional schema collision, including any
      // failed implementation's partial metadata, so teardown retains evidence.
      raw.execute('DROP INDEX historical_receipts');
      raw.execute('DROP TABLE IF EXISTS recovery_state');
      final outboxColumns = raw
          .select('PRAGMA table_info(outbox)')
          .map((row) => row['name'])
          .toSet();
      for (final column in [
        'wire_version',
        'origin_context',
        'accepted_context',
      ]) {
        if (outboxColumns.contains(column)) {
          raw.execute('ALTER TABLE outbox DROP COLUMN $column');
        }
      }
      final shadowColumns = raw
          .select('PRAGMA table_info(shadows)')
          .map((row) => row['name'])
          .toSet();
      if (shadowColumns.contains('recovery_context')) {
        raw.execute('ALTER TABLE shadows DROP COLUMN recovery_context');
      }
      raw.close();
      await open();
    }
  });

  test(
    'unverifiable origin pauses upload while valid local training still saves',
    () async {
      await repo.installRecoveryContext(context());
      final id = await repo.startFoundationWorkout();
      final frozen = await repo.prepareHead(id);
      await db.customStatement('UPDATE outbox SET origin_context=?', [
        canonicalJson({
          ...context().origin,
          'payload': {'untrusted': true},
        }),
      ]);
      expect(await repo.prepareHead(id), isNull);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, reps: 7),
      );
      await repo.commit(id, 'complete_session', {});
      await reopen();
      expect(await repo.prepareHead(id), isNull);
      expect(await repo.pendingCount(), 3);
      expect((await repo.workout(id))!['status'], 'completed');
      expect(
        allSets((await repo.workout(id))!)
            .first['observation']['actual']['reps'],
        7,
      );
      final rows = await db
          .customSelect(
            'SELECT frozen_body,origin_context FROM outbox ORDER BY local_seq',
          )
          .get();
      expect(rows.first.read<String>('frozen_body'), frozen);
      expect(rows[1].readNullable<String>('origin_context'), null);
      expect(await repo.remoteDisabled(), false);
    },
  );

  test('missing recovery control cannot silently downgrade a store or lock local training', () async {
    await repo.installRecoveryContext(context());
    final id = await repo.startFoundationWorkout();
    await db.customStatement('DELETE FROM recovery_state');
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    await reopen();
    expect(await repo.recoveryContext(), null);
    expect(await repo.prepareHead(id), null);
    expect(
      (await db.customSelect('SELECT required FROM recovery_state').getSingle())
          .read<int>('required'),
      1,
    );
    expect(await repo.pendingCount(), 2);
    expect(allSets((await repo.workout(id))!).first['observation'], isNotNull);
    await expectLater(repo.acknowledge({}), throwsA(isA<ContractViolation>()));
    expect(await repo.remoteDisabled(), false);
  });

  for (final fault in {
    'cleared requirement': 'UPDATE recovery_state SET required=0',
    'regressed high-water': 'UPDATE recovery_state SET high_water=2',
    'invalid high-water type': "UPDATE recovery_state SET high_water='corrupt'",
    'reset state with retained V2 work': 'UPDATE recovery_state SET required=0,current_context=NULL,high_water=0',
  }.entries) {
    test(
      'inconsistent recovery state ${fault.key} pauses cloud but preserves local saves',
      () async {
        await repo.installRecoveryContext(context());
        final id = await repo.startFoundationWorkout();
        final frozen = (await repo.prepareHead(id))!;
        final mutation = (jsonDecode(frozen) as Json)['mutation_id'];
        await db.customStatement(fault.value);
        await reopen();
        expect(await repo.prepareHead(id), isNull);
        await expectLater(
          repo.acknowledge({}),
          throwsA(
            isA<ContractViolation>().having(
              (error) => error.code,
              'code',
              'upgrade_required',
            ),
          ),
        );
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!, reps: 7),
        );
        await repo.commit(id, 'complete_session', {});
        final unknown = await repo.startFoundationWorkout();
        await reopen();
        expect(await repo.prepareHead(id), isNull);
        expect(await repo.prepareHead(unknown), isNull);
        expect(await repo.pendingCount(), 4);
        expect((await repo.workout(id))!['status'], 'completed');
        expect(
          allSets((await repo.workout(id))!)
              .first['observation']['actual']['reps'],
          7,
        );
        final retained = await db
            .customSelect('SELECT * FROM outbox ORDER BY rowid')
            .get();
        expect(retained.first.read<String>('mutation_id'), mutation);
        expect(retained.first.read<String>('frozen_body'), frozen);
        expect(
          retained.every((row) => row.read<int>('wire_version') == 2),
          true,
        );
        expect(retained.last.readNullable<String>('origin_context'), null);
        expect(await repo.remoteDisabled(), false);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }

  test('failed V2 freeze preserves the exact original command and can retry after reopen', () async {
    await repo.installRecoveryContext(context());
    final id = await repo.startFoundationWorkout();
    final before =
        (await db.customSelect('SELECT operation FROM outbox').getSingle())
            .read<String>('operation');
    await db.customStatement(
      "CREATE TRIGGER fail_freeze BEFORE UPDATE OF frozen_body ON outbox BEGIN SELECT RAISE(ABORT,'synthetic freeze failure'); END",
    );
    await expectLater(repo.prepareHead(id), throwsA(anything));
    await reopen();
    final row = await db
        .customSelect('SELECT operation,frozen_body FROM outbox')
        .getSingle();
    expect(row.readNullable<String>('frozen_body'), null);
    expect(row.read<String>('operation'), before);
    expect(await repo.pendingCount(), 1);
    await db.customStatement('DROP TRIGGER fail_freeze');
    expect(await repo.prepareHead(id), before);
  });
}
