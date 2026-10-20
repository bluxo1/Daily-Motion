import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload;
import 'support/sync_server.dart';

void main() {
  late Directory directory;
  late File file;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late SyncServer server;
  late SyncCoordinator sync;

  Future<void> open() async {
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
  }

  Future<void> close() async {
    await sync.close();
    repo.dispose();
    await db.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('restore-recovery-');
    file = File('${directory.path}/training.sqlite');
    server = SyncServer();
    await open();
  });
  tearDown(() async {
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await close();
    await directory.delete(recursive: true);
  });

  Future<String> recorded() async {
    final id = await repo.startFoundationWorkout();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    await sync.synchronize(force: true);
    expect(await repo.pendingCount(), 0);
    return id;
  }

  void restoredGeneration() {
    server.generation = repo.newId();
    server.feed.clear();
    server.position = 0;
  }

  for (final revision in [1, 2, 3]) {
    test(
      'restored generation preserves acknowledged local work against divergent revision $revision',
      () async {
        final id = await recorded();
        final original = (await repo.workout(id))!;
        final restored = copyJson(server.roots[id]!);
        restored['revision'] = revision;
        restored['name'] = 'Restored server branch';
        if (revision != 2) {
          for (final item in allSets(restored)) {
            item['observation'] = null;
          }
        }
        server.roots[id] = restored;
        restoredGeneration();
        await sync.synchronize(force: true);
        expect(sync.status.phase, SyncPhase.attention);
        expect((await repo.workout(id))!['conflict'], true);
        expect((await repo.workout(id))!['name'], original['name']);
        expect(
          allSets((await repo.workout(id))!)
              .first['observation']['actual']['reps'],
          5,
        );
        final sent = server.pushed.length;
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!, index: 1, reps: 7),
        );
        await sync.synchronize(force: true);
        expect(server.pushed.length, sent);
        expect(await repo.pendingCount(), 1);
        final shadow = await db
            .customSelect('SELECT revision,projection FROM shadows')
            .getSingle();
        expect(shadow.read<int>('revision'), revision);
        expect(
          jsonDecode(shadow.read<String>('projection'))['name'],
          'Restored server branch',
        );
        await close();
        await open();
        expect((await repo.workout(id))!['conflict'], true);
        expect(
          allSets((await repo.workout(id))!)
              .first['observation']['actual']['reps'],
          5,
        );
      },
    );
  }

  test('same revision in restored generation cannot silently accept a frozen pending branch', () async {
    final id = await recorded();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 6),
    );
    final frozen = await repo.prepareHead(id);
    final branchBase =
        (await db.customSelect('SELECT branch_base FROM sessions').getSingle())
            .read<int>('branch_base');
    expect(branchBase, 2);
    final sent = server.pushed.length;
    server.roots[id]!['name'] = 'Different revision two';
    restoredGeneration();
    await sync.synchronize(force: true);
    expect(server.pushed.length, sent);
    expect(sync.status.phase, SyncPhase.attention);
    expect(await repo.pendingCount(), 1);
    expect(await repo.prepareHead(id), isNull);
    expect(
      (await db
              .customSelect(
                'SELECT frozen_body FROM outbox WHERE accepted_revision IS NULL',
              )
              .getSingle())
          .read<String>('frozen_body'),
      frozen,
    );
    expect(
      (await db.customSelect('SELECT branch_base FROM sessions').getSingle())
          .read<int>('branch_base'),
      branchBase,
    );
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      6,
    );
    await close();
    await open();
    expect(await repo.prepareHead(id), isNull);
    expect(
      (await db
              .customSelect(
                'SELECT frozen_body FROM outbox WHERE accepted_revision IS NULL',
              )
              .getSingle())
          .read<String>('frozen_body'),
      frozen,
    );
    expect((await repo.workout(id))!['conflict'], true);
  });

  test('workout absent from restored backup remains a recoverable local branch after reopening', () async {
    final id = await recorded();
    server.roots.clear();
    restoredGeneration();
    await sync.synchronize(force: true);
    expect((await repo.workout(id))?['conflict'], true);
    expect(sync.status.phase, SyncPhase.attention);
    await close();
    await open();
    expect(
      allSets((await repo.workout(id))!).first['observation']['actual']['reps'],
      5,
    );
    expect((await repo.workout(id))!['conflict'], true);
    final sent = server.pushed.length;
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 7),
    );
    await sync.synchronize(force: true);
    expect(server.pushed.length, sent);
    expect(await repo.pendingCount(), 1);
  });

  test('unchanged restored root retains normal synchronization', () async {
    final id = await recorded();
    restoredGeneration();
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized);
    expect((await repo.workout(id))!['conflict'], false);
    expect((await repo.syncMetadata())['generation'], server.generation);
  });

  test('downloaded workout with no outbox history retains its restore fence after logging and reopen', () async {
    final id = await recorded();
    await close();
    file = File('${directory.path}/second-device.sqlite');
    await open();
    await sync.synchronize(force: true);
    expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
    server.roots[id]!['name'] = 'Divergent restored root';
    restoredGeneration();
    await sync.synchronize(force: true);
    expect((await repo.workout(id))!['conflict'], true);
    expect((await repo.workout(id))!.containsKey('_restore_conflict'), false);
    final sent = server.pushed.length;
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    expect((await repo.workout(id))!.containsKey('_restore_conflict'), false);
    await close();
    await open();
    await sync.synchronize(force: true);
    expect(server.pushed.length, sent);
    expect(await repo.prepareHead(id), isNull);
    expect(await repo.pendingCount(), 1);
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      5,
    );
  });

  test('restore activation failure rolls back shadow, upload fence and cursor together across restart', () async {
    final id = await recorded();
    final original = (await repo.workout(id))!;
    final before = await repo.syncMetadata();
    final originalShadow =
        (await db.customSelect('SELECT projection FROM shadows').getSingle())
            .read<String>('projection');
    server.roots[id]!['name'] = 'Divergent restored branch';
    restoredGeneration();
    final manifest = await server.bootstrap(
      before['installation_id'] as String,
    );
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, await server.page(manifest.token, 0));
    // Logging after the download must survive both failed and successful activation.
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 8),
    );
    final frozen = await repo.prepareHead(id);
    final current = await server.validateSnapshot(manifest.token);
    await db.customStatement(
      "CREATE TRIGGER fail_restore_cursor BEFORE UPDATE OF cursor ON local_identity BEGIN SELECT RAISE(ABORT,'injected restore cursor failure'); END",
    );
    await expectLater(repo.activateBootstrap(current), throwsA(anything));
    await close();
    await open();
    expect((await repo.syncMetadata())['cursor'], before['cursor']);
    expect((await repo.syncMetadata())['generation'], before['generation']);
    expect(
      (await db.customSelect('SELECT projection FROM shadows').getSingle())
          .read<String>('projection'),
      originalShadow,
    );
    expect((await repo.workout(id))!['name'], original['name']);
    expect((await repo.workout(id))!['conflict'], false);
    expect(await repo.prepareHead(id), frozen);
    expect((await repo.stagedBootstrap())!.token, manifest.token);
    expect(await repo.stagedPageIndices(), {0});
    await db.customStatement('DROP TRIGGER fail_restore_cursor');
    await repo.activateBootstrap(current);
    expect((await repo.syncMetadata())['generation'], server.generation);
    expect((await repo.workout(id))!['conflict'], true);
    expect(await repo.prepareHead(id), isNull);
    expect(await repo.stagedBootstrap(), isNull);
    final sent = server.pushed.length;
    await close();
    await open();
    await sync.synchronize(force: true);
    await sync.synchronize(force: true);
    expect(server.pushed.length, sent);
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      8,
    );
    expect(
      (await db
              .customSelect(
                'SELECT frozen_body FROM outbox WHERE accepted_revision IS NULL',
              )
              .getSingle())
          .read<String>('frozen_body'),
      frozen,
    );
  });

  test('permanent retirement erases a restore-fenced branch and pending payload after restart', () async {
    final id = await recorded();
    server.roots[id]!['name'] = 'Divergent restored branch';
    restoredGeneration();
    await sync.synchronize(force: true);
    expect((await repo.workout(id))!['conflict'], true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 8),
    );
    expect(await repo.pendingCount(), 1);
    final sent = server.pushed.length;
    server.erase(id);
    await sync.synchronize(force: true);
    await close();
    await open();
    expect(await repo.workout(id), isNull);
    expect(await repo.pendingCount(), 0);
    expect(await repo.prepareHead(id), isNull);
    expect(await db.customSelect('SELECT * FROM shadows').get(), isEmpty);
    final rows = await db.customSelect('SELECT * FROM outbox').get();
    expect(rows, isNotEmpty);
    expect(rows.every((row) => row.read<String>('operation') == '{}'), true);
    expect(
      rows.every((row) => row.readNullable<String>('frozen_body') == null),
      true,
    );
    await expectLater(
      repo.commit(id, 'record_set', {}),
      throwsA(isA<WorkoutValidation>()),
    );
    await sync.synchronize(force: true);
    expect(server.pushed.length, sent);
  });
}
