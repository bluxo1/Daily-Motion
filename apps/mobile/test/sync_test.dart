import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload;
import 'support/sync_server.dart';

void main() {
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late SyncServer server;
  late SyncCoordinator sync;
  setUp(() async {
    db = TrainingDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    server = SyncServer();
    sync = SyncCoordinator(repo, server, jitter: () => 0.5);
  });
  tearDown(() async {
    await sync.close();
    repo.dispose();
    await db.close();
  });
  Future<String> recorded() async {
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    return id;
  }

  Future<void> remoteRecord(String id, {int index = 1, int reps = 9}) async {
    final state = server.roots[id]!;
    final op = {
      'mutation_id': repo.newId(),
      'installation_id': repo.newId(),
      'aggregate_type': 'workout_session',
      'aggregate_id': id,
      'expected_revision': state['revision'],
      'command': 'record_set',
      'occurred_at': '2026-10-13T07:00:00Z',
      'recorded_at': '2026-10-13T07:00:00Z',
      'payload': recordPayload(state, index: index, reps: reps),
    };
    await server.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [op],
      }),
    );
  }

  test(
    'first upload orders predecessor commands and installs own echoes',
    () async {
      final id = await recorded();
      await sync.synchronize(force: true);
      expect(await repo.pendingCount(), 0);
      expect(server.roots[id]!['revision'], 2);
      expect(sync.status.phase, SyncPhase.synchronized);
      expect((await repo.workout(id))!['conflict'], false);
      expect((await repo.syncMetadata())['position'], 2);
    },
  );

  for (final failure in [
    'offline',
    'timeout',
    'http_503',
    'connection_dropped',
  ]) {
    test(
      '$failure before send preserves local state and recovers on retry',
      () async {
        final id = await recorded();
        server.failBefore = failure;
        await sync.synchronize(force: true);
        expect(await repo.pendingCount(), 2);
        expect(
          allSets((await repo.workout(id))!)
              .first['observation']['actual']['reps'],
          5,
        );
        expect(sync.status.phase, SyncPhase.pending);
        await sync.synchronize(force: true);
        expect(await repo.pendingCount(), 0);
        expect(server.roots[id]!['revision'], 2);
      },
    );
  }

  test(
    'lost response after server commit retries byte-identical frozen mutation',
    () async {
      final id = await recorded();
      server.failAfter = 'timeout';
      await sync.synchronize(force: true);
      final frozen = await repo.prepareHead(id);
      expect(server.roots[id]!['revision'], 1);
      await sync.synchronize(force: true);
      expect(server.roots[id]!['revision'], 2);
      expect(await repo.pendingCount(), 0);
      expect(
        server.pushed
            .expand((b) => (jsonDecode(b)['operations'] as List).cast<Json>())
            .where((op) => op['command'] == 'create_session')
            .map(canonicalJson)
            .toSet(),
        {frozen},
      );
    },
  );

  test('echo before local acknowledgement persistence reconciles the receipt', () async {
    final id = await recorded();
    // Bootstrap empty, freeze and deliver without persisting the push response.
    final manifest = await server.bootstrap(
      (await repo.syncMetadata())['installation_id'] as String,
    );
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, await server.page(manifest.token, 0));
    await repo.activateBootstrap(await server.validateSnapshot(manifest.token));
    final head = (await repo.prepareHead(id))!;
    await server.push('{"schema_version":1,"operations":[$head]}');
    final meta = await repo.syncMetadata();
    await repo.installPull(
      await server.pull(meta['cursor'] as String?),
      requestedCursor: meta['cursor'] as String?,
    );
    expect(await repo.pendingCount(), 1);
    final successor = jsonDecode((await repo.prepareHead(id))!) as Json;
    expect(successor['expected_revision'], 1);
    expect((await repo.workout(id))!['conflict'], false);
  });

  test('external update preserves multiple successors and original conflict basis', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 6),
    );
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 2, reps: 7),
    );
    await remoteRecord(id, index: 1, reps: 9);
    await sync.synchronize(force: true);
    final state = (await repo.workout(id))!;
    expect(allSets(state).elementAt(1)['observation']['actual']['reps'], 6);
    expect(allSets(state).elementAt(2)['observation']['actual']['reps'], 7);
    expect(state['conflict'], true);
    expect(sync.status.phase, SyncPhase.attention);
    final rows = await db
        .customSelect(
          "SELECT * FROM outbox WHERE state!='acknowledged' ORDER BY local_seq",
        )
        .get();
    expect(rows.first.read<String>('state'), 'conflict');
    expect(rows.first.read<int>('origin_base'), 2);
    expect(rows.last.read<String>('state'), 'pending');
  });

  test('clean remote updates and repeated pages advance the cursor without duplicates', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await remoteRecord(id);
    final meta = await repo.syncMetadata();
    final page = await server.pull(meta['cursor'] as String?);
    await repo.installPull(page, requestedCursor: meta['cursor'] as String?);
    final seq = (await repo.workout(id))!['local_seq'];
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      9,
    );
    await expectLater(
      repo.installPull(page, requestedCursor: meta['cursor'] as String?),
      throwsA(isA<ContractViolation>()),
    );
    expect((await repo.workout(id))!['local_seq'], seq);
  });

  test('failure at cursor persistence rolls back all pull changes', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await remoteRecord(id);
    final meta = await repo.syncMetadata();
    final page = await server.pull(meta['cursor'] as String?);
    await db.customStatement(
      "CREATE TRIGGER fail_cursor BEFORE UPDATE OF cursor ON local_identity BEGIN SELECT RAISE(ABORT,'injected cursor failure'); END",
    );
    await expectLater(
      repo.installPull(page, requestedCursor: meta['cursor'] as String?),
      throwsA(anything),
    );
    expect((await repo.syncMetadata())['cursor'], meta['cursor']);
    expect(
      allSets((await repo.workout(id))!).elementAt(1)['observation'],
      null,
    );
    await db.customStatement('DROP TRIGGER fail_cursor');
    await repo.installPull(page, requestedCursor: meta['cursor'] as String?);
    expect(
      allSets((await repo.workout(id))!).elementAt(1)['observation'],
      isNotNull,
    );
  });

  test('remote erasure purges pending payloads and blocks stale replay', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    final stale = (await repo.prepareHead(id))!;
    server.erase(id);
    await sync.synchronize(force: true);
    expect(await repo.workout(id), null);
    final row = await db
        .customSelect(
          "SELECT operation,frozen_body FROM outbox WHERE session_id='$id' ORDER BY local_seq DESC LIMIT 1",
        )
        .getSingle();
    expect(row.read<String>('operation'), '{}');
    expect(row.readNullable<String>('frozen_body'), null);
    await expectLater(
      repo.commit(id, 'record_set', {}),
      throwsA(isA<WorkoutValidation>()),
    );
    final result = await server.push(
      '{"schema_version":1,"operations":[$stale]}',
    );
    expect(result.results.first['error']['code'], 'retired_id');
  });

  test('logging while bootstrap downloads survives activation', () async {
    final id = await recorded();
    server.after = (method) async {
      if (method == 'page') {
        server.after = null;
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!, index: 1, reps: 6),
        );
      }
    };
    await sync.synchronize(force: true);
    expect(server.roots[id]!['revision'], 3);
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      6,
    );
  });

  test('corrupted snapshot never replaces existing working data', () async {
    final id = await recorded();
    server.before = (method) async {
      if (method == 'page') {
        server.before = null;
        server.snapshotPages.values.first.first['retired_ids'] = [id];
      }
    };
    await sync.synchronize(force: true);
    expect(sync.status.code, 'snapshot_checksum');
    expect(await repo.workout(id), isNotNull);
    expect((await repo.syncMetadata())['cursor'], null);
  });

  test(
    'generation reset bootstraps without discarding pending local work',
    () async {
      final id = await recorded();
      await sync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1),
      );
      server.generation = '40000000-0000-4000-8000-000000000002';
      await sync.synchronize(force: true);
      expect(await repo.pendingCount(), 0);
      expect(server.roots[id]!['revision'], 3);
    },
  );

  test(
    'wrong-owner identity pauses sync without transferring or erasing work',
    () async {
      final id = await recorded();
      server.owner = '20000000-0000-4000-8000-000000000002';
      await sync.synchronize(force: true);
      expect(sync.status.code, 'wrong_owner');
      expect(await repo.workout(id), isNotNull);
      expect(server.pushed, isEmpty);
    },
  );

  test(
    'auth expiry leaves training available; remote disable locks and purges',
    () async {
      final id = await recorded();
      server.before = (method) async {
        throw const SyncFailure('invalid_credentials');
      };
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.authenticationRequired);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1),
      );
      server.before = null;
      server.disabled = true;
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.accountDisabled);
      expect((await db.customSelect('SELECT * FROM sessions').get()), isEmpty);
      await expectLater(repo.workouts(), throwsA(isA<WorkoutValidation>()));
    },
  );

  test('contract rejects unsupported versions and correctness-bearing extra fields', () {
    expect(
      () => MeResponseDto.fromJson({...server.identity, 'schema_version': 2}),
      throwsA(isA<ContractViolation>()),
    );
    expect(
      () => MeResponseDto.fromJson({
        ...server.identity,
        'unknown_cursor_mode': 'timestamp',
      }),
      throwsA(isA<ContractViolation>()),
    );
    expect(
      () => PullResponseDto.fromJson({
        ...server.context,
        'changes': [],
        'next_cursor': 'x',
        'next_position': '0',
        'has_more': false,
      }),
      throwsA(isA<ContractViolation>()),
    );
  });

  test('file restart recovers frozen upload, installed cursor and conflict metadata', () async {
    await db.close();
    final dir = await Directory.systemTemp.createTemp('sync-restart-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    await sync.close();
    sync = SyncCoordinator(repo, server);
    final id = await recorded();
    server.failAfter = 'timeout';
    await sync.synchronize(force: true);
    final frozen = await repo.prepareHead(id);
    await sync.close();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    expect(await repo.prepareHead(id), frozen);
    await sync.synchronize(force: true);
    expect((await repo.syncMetadata())['position'], 2);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 6),
    );
    await remoteRecord(id);
    await sync.synchronize(force: true);
    await sync.close();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    expect((await repo.workout(id))!['conflict'], true);
    expect(await repo.prepareHead(id), null);
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  });
}
