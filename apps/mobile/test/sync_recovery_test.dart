import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload, fixture;
import 'support/sync_server.dart';
import 'support/legacy_schema.dart';

void main() {
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late SyncServer server;
  late SyncCoordinator sync;
  late Directory fixtureDirectory;
  late File fixtureDatabase;
  setUp(() async {
    fixtureDirectory = await Directory.systemTemp.createTemp('sync-fault-');
    fixtureDatabase = File('${fixtureDirectory.path}/db.sqlite');
    db = TrainingDatabase.open(fixtureDatabase);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    server = SyncServer();
    sync = SyncCoordinator(repo, server);
  });
  tearDown(() async {
    await sync.close();
    repo.dispose();
    await db.close();
    final reopened = TrainingDatabase.open(fixtureDatabase);
    expect(
      (await reopened.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(
      await reopened.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    await reopened.close();
    await fixtureDirectory.delete(recursive: true);
  });
  Future<void> reopen() async {
    await sync.close();
    repo.dispose();
    await db.close();
    db = TrainingDatabase.open(fixtureDatabase);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
  }

  Future<void> baseline() async {
    final manifest = await server.bootstrap(
      (await repo.syncMetadata())['installation_id'] as String,
    );
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, await server.page(manifest.token, 0));
    await repo.activateBootstrap(await server.validateSnapshot(manifest.token));
  }

  Future<BootstrapManifestDto> stage(List<Json> pages, {int? position}) async {
    final meta = await repo.syncMetadata();
    server.snapshotPages['staged'] = pages;
    server.snapshotEpochs['staged'] = server.epoch;
    final manifest = BootstrapManifestDto.fromJson({
      ...server.context,
      'installation_id': meta['installation_id'],
      'token': 'staged',
      'position': position ?? server.position,
      'cursor': '${server.generation}:${position ?? server.position}',
      'expires_at': '2099-01-01T00:00:00Z',
      'page_count': pages.length,
      'checksums': pages
          .map((p) => sha256.convert(utf8.encode(canonicalJson(p))).toString())
          .toList(),
    });
    await repo.stageBootstrap(manifest);
    for (var i = 0; i < pages.length; i++) {
      await repo.stageBootstrapPage(i, SnapshotPageDto.fromJson(pages[i]));
    }
    return manifest;
  }

  test('bootstrap preserves a completed workout corrected to skipped after file restart', () async {
    final id = await repo.startFoundationWorkout();
    await expectLater(
      repo.commit(id, 'complete_session', {}),
      throwsA(isA<WorkoutValidation>()),
    );
    final recorded = recordPayload((await repo.workout(id))!);
    await repo.commit(id, 'record_set', recorded);
    await repo.commit(id, 'complete_session', {});
    await repo.commit(id, 'correct_set', {
      ...recorded,
      'execution_status': 'skipped',
      'actual': null,
      'correction_reason': 'The set was recorded by mistake.',
    });
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
    expect(await repo.pendingCount(), 0);

    // A clean installation sees only the corrected snapshot, not its earlier
    // performed observation. Completion was valid when the user finished.
    await sync.close();
    repo.dispose();
    await db.close();
    fixtureDatabase = File('${fixtureDirectory.path}/import.sqlite');
    db = TrainingDatabase.open(fixtureDatabase);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    await baseline();
    await reopen();

    final restored = (await repo.workout(id))!;
    expect(restored['status'], 'completed');
    expect(restored['ended_at'], isNotNull);
    expect(restored['revision'], 4);
    final observation = allSets(restored).first['observation'] as Json;
    expect(observation['execution_status'], 'skipped');
    expect(observation['actual'], isNull);
    expect(observation['completion_seq'], 1);
    expect(
      observation['correction_reason'],
      'The set was recorded by mistake.',
    );
    expect(
      allSets(restored).where(
        (s) =>
            s['observation'] != null &&
            s['observation']['execution_status'] != 'skipped',
      ),
      isEmpty,
    );
    expect(await repo.pendingCount(), 0);
    expect((await repo.syncMetadata())['position'], server.position);
  });

  test('acknowledgement failure rolls back metadata and recovers the committed receipt', () async {
    final id = await repo.startFoundationWorkout();
    await baseline();
    final body = (await repo.prepareHead(id))!;
    final op = jsonDecode(body) as Json;
    final response = await server.push(
      '{"schema_version":1,"operations":[$body]}',
    );
    await db.customStatement(
      "CREATE TRIGGER fail_ack BEFORE UPDATE OF state ON outbox BEGIN SELECT RAISE(ABORT,'injected acknowledgement failure'); END",
    );
    await expectLater(
      repo.installAcknowledgements(response, [op['mutation_id'] as String]),
      throwsA(anything),
    );
    await reopen();
    expect(await repo.pendingCount(), 1);
    expect(await repo.prepareHead(id), body);
    expect((await db.customSelect('SELECT * FROM shadows').get()), isEmpty);
    await db.customStatement('DROP TRIGGER fail_ack');
    await sync.synchronize(force: true);
    expect(await repo.pendingCount(), 0);
  });
  test('late acknowledgement after newer external pull never rebases its successor', () async {
    final id = await repo.startFoundationWorkout();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final body = (await repo.prepareHead(id))!;
    final op = jsonDecode(body) as Json;
    final response = await server.push(
      '{"schema_version":1,"operations":[$body]}',
    );
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1, reps: 6),
    );
    final remote = {
      ...op,
      'mutation_id': repo.newId(),
      'expected_revision': 2,
      'payload': recordPayload(server.roots[id]!, index: 1, reps: 9),
    };
    await server.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [remote],
      }),
    );
    final meta = await repo.syncMetadata();
    await repo.installPull(
      await server.pull(meta['cursor'] as String?),
      requestedCursor: meta['cursor'] as String?,
    );
    await repo.installAcknowledgements(response, [op['mutation_id'] as String]);
    expect(jsonDecode((await repo.prepareHead(id))!)['expected_revision'], 2);
    expect(
      (await db.customSelect('SELECT revision FROM shadows').getSingle())
          .read<int>('revision'),
      3,
    );
    expect(
      allSets((await repo.workout(id))!)
          .elementAt(1)['observation']['actual']['reps'],
      6,
    );
  });
  test('bootstrap activation failure leaves working state, cursor and stage recoverable', () async {
    final id = await repo.startFoundationWorkout();
    await stage([
      {'roots': [], 'retired_ids': []},
    ]);
    await db.customStatement(
      "CREATE TRIGGER fail_activation BEFORE UPDATE OF cursor ON local_identity BEGIN SELECT RAISE(ABORT,'injected bootstrap failure'); END",
    );
    await expectLater(
      repo.activateBootstrap(await server.me()),
      throwsA(anything),
    );
    await reopen();
    expect(await repo.workout(id), isNotNull);
    expect((await repo.syncMetadata())['cursor'], null);
    expect(await repo.stagedBootstrap(), isNotNull);
    await db.customStatement('DROP TRIGGER fail_activation');
    await repo.activateBootstrap(await server.me());
    expect(await repo.workout(id), isNotNull);
    expect(await repo.stagedBootstrap(), null);
  });
  test('incomplete snapshot cannot activate or advance a cursor', () async {
    final page = <String, dynamic>{'roots': [], 'retired_ids': []};
    final meta = await repo.syncMetadata();
    final manifest = BootstrapManifestDto.fromJson({
      ...server.context,
      'installation_id': meta['installation_id'],
      'token': 'two-pages',
      'position': 0,
      'cursor': 'future',
      'expires_at': '2099-01-01T00:00:00Z',
      'page_count': 2,
      'checksums': List.filled(
        2,
        sha256.convert(utf8.encode(canonicalJson(page))).toString(),
      ),
    });
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, SnapshotPageDto.fromJson(page));
    await expectLater(
      repo.activateBootstrap(await server.me()),
      throwsA(isA<ContractViolation>()),
    );
    expect((await repo.syncMetadata())['cursor'], null);
  });
  test(
    'snapshot metadata cannot skip beyond the current committed feed',
    () async {
      await stage([
        {'roots': [], 'retired_ids': []},
      ], position: 10);
      await expectLater(
        repo.activateBootstrap(await server.me()),
        throwsA(isA<ContractViolation>()),
      );
      expect((await repo.syncMetadata())['position'], 0);
    },
  );
  test(
    'checksum-valid child collision cannot overwrite a local-only branch',
    () async {
      final id = await repo.startFoundationWorkout();
      final existing = (await repo.workout(id))!;
      final root = applyOperation(null, fixture(), revision: 1)!;
      root['exercises'][0]['sets'][0]['set_id'] = allSets(existing)
          .first['set_id'];
      server.position = 1;
      await stage([
        {
          'roots': [root],
          'retired_ids': [],
        },
      ]);
      await expectLater(
        repo.activateBootstrap(await server.me()),
        throwsA(isA<ContractViolation>()),
      );
      expect((await repo.workouts()).length, 1);
      expect(allSets((await repo.workout(id))!).first['observation'], null);
    },
  );
  test(
    'malformed own echo cannot acknowledge a different frozen body',
    () async {
      final id = await repo.startFoundationWorkout();
      await baseline();
      final body = (await repo.prepareHead(id))!;
      await server.push('{"schema_version":1,"operations":[$body]}');
      server.feed.last['operation']['payload']['name'] = 'Forged echo';
      final meta = await repo.syncMetadata();
      await expectLater(
        repo.installPull(
          await server.pull(meta['cursor'] as String?),
          requestedCursor: meta['cursor'] as String?,
        ),
        throwsA(isA<ContractViolation>()),
      );
      expect(await repo.pendingCount(), 1);
      expect((await repo.syncMetadata())['position'], 0);
    },
  );
  test(
    'malformed duplicate feed positions cannot partially install a page',
    () async {
      final id = await repo.startFoundationWorkout();
      await baseline();
      final body = (await repo.prepareHead(id))!;
      await server.push('{"schema_version":1,"operations":[$body]}');
      server.feed.add(copyJson(server.feed.single));
      final meta = await repo.syncMetadata();
      await expectLater(
        repo.installPull(
          await server.pull(meta['cursor'] as String?),
          requestedCursor: meta['cursor'] as String?,
        ),
        throwsA(isA<ContractViolation>()),
      );
      expect(await repo.pendingCount(), 1);
      expect((await repo.syncMetadata())['position'], 0);
    },
  );
  test('deletion handling failure cannot commit retirement without purging payload', () async {
    final id = await repo.startFoundationWorkout();
    await sync.synchronize(force: true);
    server.erase(id);
    final meta = await repo.syncMetadata();
    final page = await server.pull(meta['cursor'] as String?);
    // Simulate matching epoch observed by a separately reconciled page context.
    await db.customStatement('UPDATE sync_metadata SET erasure_epoch=1');
    await db.customStatement(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON sessions BEGIN SELECT RAISE(ABORT,'injected erase failure'); END",
    );
    await expectLater(
      repo.installPull(page, requestedCursor: meta['cursor'] as String?),
      throwsA(anything),
    );
    await reopen();
    expect(await repo.workout(id), isNotNull);
    expect((await db.customSelect('SELECT * FROM retired_ids').get()), isEmpty);
    await db.customStatement('DROP TRIGGER fail_delete');
    await repo.installPull(page, requestedCursor: meta['cursor'] as String?);
    expect(await repo.workout(id), null);
  });
  test(
    'failure creating conflict leaves the pending branch and cursor untouched',
    () async {
      final id = await repo.startFoundationWorkout();
      await sync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, reps: 6),
      );
      final remote = {
        ...jsonDecode((await repo.prepareHead(id))!) as Json,
        'mutation_id': repo.newId(),
        'payload': recordPayload(server.roots[id]!, reps: 9),
      };
      await server.push(
        canonicalJson({
          'schema_version': 1,
          'operations': [remote],
        }),
      );
      final meta = await repo.syncMetadata();
      final page = await server.pull(meta['cursor'] as String?);
      await db.customStatement(
        "CREATE TRIGGER fail_conflict BEFORE UPDATE OF has_conflict ON sessions BEGIN SELECT RAISE(ABORT,'injected conflict failure'); END",
      );
      await expectLater(
        repo.installPull(page, requestedCursor: meta['cursor'] as String?),
        throwsA(anything),
      );
      await reopen();
      expect((await repo.syncMetadata())['cursor'], meta['cursor']);
      expect(
        allSets((await repo.workout(id))!)
            .first['observation']['actual']['reps'],
        6,
      );
    },
  );
  test(
    'local timing observer failures cannot change durable completion feedback',
    () async {
      repo.onLocalCommit = (_) => throw StateError('broken observer');
      final id = await repo.startFoundationWorkout();
      expect(await repo.workout(id), isNotNull);
      expect(await repo.pendingCount(), 1);
    },
  );
  test('bounded pull pages include a commit made between pages', () async {
    await baseline();
    final remote = fixture();
    await server.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [remote],
      }),
    );
    final id = remote['aggregate_id'] as String;
    final update = {
      ...remote,
      'mutation_id': repo.newId(),
      'expected_revision': 1,
      'command': 'record_set',
      'payload': recordPayload(server.roots[id]!),
    };
    await server.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [update],
      }),
    );
    server.limit = 1;
    var appended = false;
    server.after = (method) async {
      if (method == 'pull' && !appended) {
        appended = true;
        await server.push(
          canonicalJson({
            'schema_version': 1,
            'operations': [
              {
                ...update,
                'mutation_id': repo.newId(),
                'expected_revision': 2,
                'command': 'complete_session',
                'payload': {},
              },
            ],
          }),
        );
      }
    };
    await sync.synchronize(force: true);
    expect((await repo.syncMetadata())['position'], 3);
    expect((await repo.workout(id))!['status'], 'completed');
  });
  test('terminal rejection blocks only its own dependent root', () async {
    final badId = await repo.startFoundationWorkout();
    await repo.commit(badId, 'abandon_session', {});
    final goodId = await repo.startFoundationWorkout();
    await baseline();
    final frozen = jsonDecode((await repo.prepareHead(badId))!) as Json;
    final mutation = frozen['mutation_id'] as String;
    server.digests[mutation] = canonicalJson(frozen);
    server.receipts[mutation] = {
      'mutation_id': mutation,
      'aggregate_id': badId,
      'status': 'rejected',
      'error': {'code': 'invalid_transition', 'retryable': false},
    };
    await sync.synchronize(force: true);
    expect(server.roots[goodId], isNotNull);
    expect(await repo.prepareHead(badId), null);
    expect((await repo.workout(badId))!['conflict'], true);
    expect(sync.status.phase, SyncPhase.attention);
  });
  test(
    'expired and wrong-generation staged snapshots retain local work',
    () async {
      final id = await repo.startFoundationWorkout();
      final manifest = await stage([
        {'roots': [], 'retired_ids': []},
      ]);
      final expired = BootstrapManifestDto.fromJson({
        ...manifest.json,
        'expires_at': '2000-01-01T00:00:00Z',
      });
      await repo.stageBootstrap(expired);
      await repo.stageBootstrapPage(
        0,
        SnapshotPageDto.fromJson({'roots': [], 'retired_ids': []}),
      );
      await expectLater(
        repo.activateBootstrap(await server.me()),
        throwsA(isA<ContractViolation>()),
      );
      await stage([
        {'roots': [], 'retired_ids': []},
      ]);
      server.generation = repo.newId();
      await expectLater(
        repo.activateBootstrap(await server.me()),
        throwsA(isA<ContractViolation>()),
      );
      expect(await repo.workout(id), isNotNull);
      expect((await repo.syncMetadata())['cursor'], null);
    },
  );
  test('checksum-valid impossible dates and invalid observation semantics fail safely', () async {
    server.position = 1;
    final root = applyOperation(null, fixture(), revision: 1)!;
    root['started_at'] = '2026-02-30T07:00:00Z';
    await expectLater(
      stage([
        {
          'roots': [root],
          'retired_ids': [],
        },
      ]),
      throwsA(isA<ContractViolation>()),
    );
    root['started_at'] = '2026-02-28T07:00:00Z';
    allSets(root).first['observation'] = {
      ...recordPayload(root),
      'occurred_at': root['started_at'],
      'recorded_at': root['started_at'],
    };
    allSets(root).first['observation']['actual']['reps'] = 0;
    await stage([
      {
        'roots': [root],
        'retired_ids': [],
      },
    ]);
    await expectLater(
      repo.activateBootstrap(await server.me()),
      throwsA(isA<ContractViolation>()),
    );
    expect(await repo.workouts(), isEmpty);
  });
  test('checksum-valid malformed snapshot lifecycle or load convention never activates', () async {
    final original = applyOperation(null, fixture(), revision: 1)!;
    for (final kind in ['lifecycle', 'load', 'empty_completion']) {
      final root = copyJson(original);
      if (kind == 'lifecycle') {
        root['ended_at'] = root['started_at'];
      } else if (kind == 'load') {
        allSets(root).first['planned']['load']['basis'] = 'per_implement';
      } else {
        root['status'] = 'completed';
        root['ended_at'] = root['started_at'];
      }
      await stage([
        {
          'roots': [root],
          'retired_ids': [],
        },
      ]);
      await expectLater(
        repo.activateBootstrap(await server.me()),
        throwsA(isA<ContractViolation>()),
      );
      expect(await repo.workouts(), isEmpty);
      expect((await repo.syncMetadata())['cursor'], null);
    }
  });
  test('schema one migration preserves frozen command, timer, draft and branch basis', () async {
    await sync.close();
    await db.close();
    final dir = await Directory.systemTemp.createTemp('migration-sync-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final setId =
        allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
    await repo.saveDraft(setId, {'reps': '7'});
    final frozen = await repo.prepareHead(id);
    final timer = await repo.timerDeadline(id);
    await reconstructSchemaThree(db);
    // Reconstruct the exact previous SQL schema; no prior released schema exists.
    for (final table in [
      'sync_metadata',
      'bootstrap_stage',
      'bootstrap_pages',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('ALTER TABLE sessions DROP COLUMN branch_base');
    for (final column in ['attempt_count', 'last_error', 'request_digest']) {
      await db.customStatement('ALTER TABLE outbox DROP COLUMN $column');
    }
    for (final column in ['monotonic_us', 'continuity_id', 'uncertain']) {
      await db.customStatement('ALTER TABLE rest_timers DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version=1');
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    expect(await repo.pendingCount(), 2);
    expect(await repo.prepareHead(id), frozen);
    expect(await repo.draft(setId), {'reps': '7'});
    expect(await repo.timerDeadline(id), timer);
    expect(
      (await db.customSelect('SELECT branch_base FROM sessions').getSingle())
          .read<int>('branch_base'),
      0,
    );
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'staged pages, cursor and remote retirement survive real file reopen',
    () async {
      await sync.close();
      await db.close();
      final dir = await Directory.systemTemp.createTemp('staged-sync-');
      final file = File('${dir.path}/db.sqlite');
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      sync = SyncCoordinator(repo, server);
      final id = await repo.startFoundationWorkout();
      await stage([
        {'roots': [], 'retired_ids': []},
      ]);
      await sync.close();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      sync = SyncCoordinator(repo, server);
      expect(await repo.stagedBootstrap(), isNotNull);
      expect(await repo.stagedPageIndices(), {0});
      await sync.synchronize(force: true);
      server.erase(id);
      await sync.synchronize(force: true);
      await sync.close();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      sync = SyncCoordinator(repo, server);
      expect(await repo.workout(id), null);
      expect((await repo.syncMetadata())['cursor'], isNotNull);
      await expectLater(
        repo.commit(id, 'record_set', {}),
        throwsA(isA<WorkoutValidation>()),
      );
      await sync.close();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
  test('interrupted snapshot download resumes missing pages after real file reopen', () async {
    await sync.close();
    await db.close();
    final dir = await Directory.systemTemp.createTemp('partial-bootstrap-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    final id = await repo.startFoundationWorkout();
    final page = <String, dynamic>{'roots': [], 'retired_ids': []};
    final manifest = await stage([page, page]);
    await repo.discardBootstrap();
    await repo.stageBootstrap(manifest);
    await repo.stageBootstrapPage(0, SnapshotPageDto.fromJson(page));
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    var downloaded = 0;
    server.before = (method) async {
      if (method == 'page') downloaded++;
    };
    expect(await repo.stagedPageIndices(), {0});
    await sync.synchronize(force: true);
    expect(downloaded, 1);
    expect(await repo.stagedBootstrap(), null);
    expect(await repo.workout(id), isNotNull);
    expect(await repo.pendingCount(), 0);
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  test('remote account erasure remains disabled with no personal payload after restart', () async {
    await sync.close();
    await db.close();
    final dir = await Directory.systemTemp.createTemp('account-erasure-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    sync = SyncCoordinator(repo, server);
    await repo.startFoundationWorkout();
    server.disabled = true;
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.accountDisabled);
    await sync.close();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    sync = SyncCoordinator(repo, server);
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.accountDisabled);
    expect((await db.customSelect('SELECT * FROM sessions').get()), isEmpty);
    expect((await db.customSelect('SELECT * FROM outbox').get()), isEmpty);
    await expectLater(repo.initialize(), throwsA(isA<WorkoutValidation>()));
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'offline foreground start and connection flapping never alter durable sets',
    () async {
      final id = await repo.startFoundationWorkout();
      var offline = true;
      server.before = (method) async {
        if (method == 'me' && offline) {
          throw const SyncFailure('offline', retryable: true);
        }
      };
      await sync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      offline = false;
      server.failAfter = 'timeout';
      await sync.synchronize(force: true);
      final frozen = await repo.prepareHead(id);
      offline = true;
      await sync.synchronize(force: true);
      expect(await repo.prepareHead(id), frozen);
      expect(
        allSets((await repo.workout(id))!).first['observation'],
        isNotNull,
      );
      offline = false;
      await sync.synchronize(force: true);
      expect(server.roots[id]!['revision'], 2);
      expect(await repo.pendingCount(), 0);
    },
  );
  test(
    'a stalled network upload cannot block a durable local set commit',
    () async {
      final id = await repo.startFoundationWorkout();
      await sync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      final reached = Completer<void>();
      final release = Completer<void>();
      server.before = (method) async {
        if (method == 'push') {
          reached.complete();
          await release.future;
        }
      };
      final upload = sync.synchronize(force: true);
      await reached.future;
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1),
      );
      expect(await repo.pendingCount(), 2);
      // Stop foreground scheduling after the in-flight request, preserving successor.
      sync.foreground(false);
      release.complete();
      await upload;
      expect(
        allSets((await repo.workout(id))!)
            .where((s) => s['observation'] != null)
            .length,
        2,
      );
      expect(await repo.pendingCount(), 1);
      server.before = null;
      sync.foreground(true);
      await sync.synchronize(force: true);
      expect(await repo.pendingCount(), 0);
    },
  );
  test(
    'bootstrap page staging failure leaves no partial page and can retry',
    () async {
      final manifest = await server.bootstrap(
        (await repo.syncMetadata())['installation_id'] as String,
      );
      await repo.stageBootstrap(manifest);
      await db.customStatement(
        "CREATE TRIGGER fail_stage BEFORE INSERT ON bootstrap_pages BEGIN SELECT RAISE(ABORT,'injected staging failure'); END",
      );
      final page = await server.page(manifest.token, 0);
      await expectLater(repo.stageBootstrapPage(0, page), throwsA(anything));
      await reopen();
      expect(await repo.stagedPageIndices(), isEmpty);
      expect((await repo.syncMetadata())['cursor'], null);
      await db.customStatement('DROP TRIGGER fail_stage');
      await sync.synchronize(force: true);
      expect(await repo.stagedBootstrap(), null);
    },
  );
  test('contract-invalid local command is rejected before creating a stranded outbox head', () async {
    final op = fixture();
    final exercise = op['payload']['exercises'][0] as Json;
    exercise['loading_basis'] = 'bodyweight_only';
    for (final item in exercise['sets'] as List) {
      item['planned']['load']['basis'] = 'bodyweight_only';
    }
    await expectLater(
      repo.commit(
        op['aggregate_id'] as String,
        'create_session',
        op['payload'] as Json,
      ),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(await repo.pendingCount(), 0);
    expect(await repo.workouts(), isEmpty);
  });
  test('failure before durable outbox creation leaves no acknowledged local workout after restart', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'injected local commit failure'); END",
    );
    await expectLater(repo.startFoundationWorkout(), throwsA(anything));
    await reopen();
    expect(await repo.workouts(), isEmpty);
    expect(await repo.pendingCount(), 0);
    await db.customStatement('DROP TRIGGER fail_outbox');
    expect(await repo.startFoundationWorkout(), isNotEmpty);
  });
  test('failure after page installation but before cursor write rolls back the entire page across restart', () async {
    final id = await repo.startFoundationWorkout();
    await baseline();
    final body = (await repo.prepareHead(id))!;
    await server.push('{"schema_version":1,"operations":[$body]}');
    final meta = await repo.syncMetadata();
    final page = await server.pull(meta['cursor'] as String?);
    await db.customStatement(
      "CREATE TRIGGER fail_cursor BEFORE UPDATE OF cursor ON local_identity BEGIN SELECT RAISE(ABORT,'injected cursor failure'); END",
    );
    await expectLater(
      repo.installPull(page, requestedCursor: meta['cursor'] as String?),
      throwsA(anything),
    );
    await reopen();
    expect((await repo.syncMetadata())['cursor'], meta['cursor']);
    expect((await repo.syncMetadata())['position'], 0);
    expect(await repo.pendingCount(), 1);
    expect(await db.customSelect('SELECT * FROM shadows').get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_cursor');
    await sync.synchronize(force: true);
    expect(await repo.pendingCount(), 0);
    expect((await repo.syncMetadata())['position'], 1);
  });
  test(
    'foreground interruption with more pull pages cannot claim synchronized',
    () async {
      await baseline();
      final remote = fixture();
      await server.push(
        canonicalJson({
          'schema_version': 1,
          'operations': [remote],
        }),
      );
      await server.push(
        canonicalJson({
          'schema_version': 1,
          'operations': [
            {
              ...remote,
              'mutation_id': repo.newId(),
              'expected_revision': 1,
              'command': 'abandon_session',
              'payload': {},
            },
          ],
        }),
      );
      server.limit = 1;
      server.after = (method) async {
        if (method == 'pull') sync.foreground(false);
      };
      await sync.synchronize(force: true);
      expect((await repo.syncMetadata())['position'], 1);
      expect(sync.status.phase, SyncPhase.pending);
      server.after = null;
      sync.foreground(true);
      await sync.synchronize(force: true);
      expect((await repo.syncMetadata())['position'], 2);
      expect(sync.status.phase, SyncPhase.synchronized);
    },
  );
}
