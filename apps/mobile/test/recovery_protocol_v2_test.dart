import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import 'repository_test.dart' show recordPayload;
import 'recovery_persistence_test.dart' show context;
import 'support/auth_fakes.dart';
import 'support/legacy_schema.dart';
import 'support/process_kill_harness.dart';
import 'support/sync_server.dart' show SyncServer, testOwner;

void main() {
  test('test_historical_receipt_keeps_working_branch_and_successors', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drp2-late-history-',
    );
    final file = File('${directory.path}/training.sqlite');
    var db = TrainingDatabase.open(file);
    var repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    final original = context();
    await repo.installRecoveryContext(original);
    try {
      final id = await repo.startFoundationWorkout();
      final frozen = (await repo.prepareHead(id))!;
      final command = jsonDecode(frozen) as Json;
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1, reps: 6),
      );
      final draftId =
          allSets((await repo.workout(id))!).elementAt(2)['set_id'] as String;
      await repo.saveDraft(draftId, {'reps': '8'});
      final current = context(
        serial: 2,
        incarnation: '30000000-0000-4000-8000-000000000004',
        generation: '30000000-0000-4000-8000-000000000005',
        order: 6,
        digest: 'b',
        epoch: 4,
        position: 20,
      );
      await repo.installRecoveryContext(current);
      // Arrange an already verified/installed current shadow. The subject here
      // is SQLite handling of a late historical result, not transport trust.
      final external = copyJson((await repo.workout(id))!)
        ..remove('local_seq')
        ..remove('conflict')
        ..['name'] = 'External timeline workout'
        ..['revision'] = 7;
      allSets(external).first['observation']['actual']['reps'] = 9;
      validateTransport('RootProjection', external);
      await db.customStatement(
        'INSERT INTO shadows(session_id,revision,projection,recovery_context) VALUES(?,?,?,?)',
        [id, 7, canonicalJson(external), canonicalJson(current.json)],
      );
      expect(await repo.prepareHead(id), isNull);
      Future<String> rows(String table) async => canonicalJson([
        for (final row
            in await db
                .customSelect('SELECT * FROM $table ORDER BY rowid')
                .get())
          row.data,
      ]);
      final before = {
        for (final table in [
          'outbox',
          'shadows',
          'sessions',
          'exercises',
          'workout_sets',
          'local_observations',
          'drafts',
          'rest_timers',
          'sync_metadata',
          'local_identity',
          'recovery_state',
        ])
          table: await rows(table),
      };
      final result = <String, dynamic>{
        'mutation_id': command['mutation_id'],
        'aggregate_id': id,
        'status': 'accepted',
        'accepted_revision': 1,
        'accepted_at': '2026-10-22T00:00:00Z',
      };
      final digest = sha256.convert(utf8.encode(frozen)).toString();
      await repo.recordHistoricalResult(
        result: result,
        requestDigest: digest,
        originalContext: original,
      );
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      await repo.recordHistoricalResult(
        result: result,
        requestDigest: digest,
        originalContext: original,
      );
      for (final entry in before.entries) {
        expect(
          await rows(entry.key),
          entry.value,
          reason: 'Historical evidence cannot change ${entry.key}.',
        );
      }
      final pending = await db
          .customSelect('SELECT * FROM outbox ORDER BY local_seq')
          .get();
      expect(pending.length, 3);
      expect(
        pending.every(
          (row) =>
              row.read<String>('state') == 'pending' &&
              row.readNullable<int>('accepted_revision') == null &&
              row.readNullable<String>('accepted_context') == null,
        ),
        true,
      );
      expect(pending.first.read<String>('frozen_body'), frozen);
      expect(
        pending
            .skip(1)
            .every((row) => row.readNullable<String>('frozen_body') == null),
        true,
      );
      expect(await repo.prepareHead(id), isNull);
      expect(
        allSets((await repo.workout(id))!)
            .first['observation']['actual']['reps'],
        5,
      );
      expect(await repo.draft(draftId), {'reps': '8'});
      expect((await repo.workout(id))!['conflict'], false);
      expect(
        (await db.customSelect('SELECT * FROM historical_receipts').get())
            .length,
        1,
      );
    } finally {
      repo.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test('test_legacy_schema_migration_preserves_all_bytes', () async {
    for (final version in [1, 2, 3]) {
      final directory = await Directory.systemTemp.createTemp(
        'drp2-migrate-$version-',
      );
      final file = File('${directory.path}/training.sqlite');
      var db = TrainingDatabase.open(file);
      var repo = WorkoutRepository(db, testOwner);
      final server = SyncServer();
      Future<void> reopen() async {
        repo.dispose();
        await db.close();
        db = TrainingDatabase.open(file);
        repo = WorkoutRepository(db, testOwner);
        await repo.initialize();
      }

      Json inspectRows() {
        final raw = native.sqlite3.open(
          file.path,
          mode: native.OpenMode.readOnly,
        );
        try {
          return {
            for (final table in [
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
            ])
              if (raw.select(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                [table],
              ).isNotEmpty)
                table: [
                  for (final row in raw.select(
                    'SELECT * FROM $table ORDER BY rowid',
                  ))
                    Map<String, dynamic>.from(row),
                ],
          };
        } finally {
          raw.close();
        }
      }

      try {
        await repo.initialize();
        final id = await repo.startFoundationWorkout();
        final sync = SyncCoordinator(repo, server);
        try {
          await sync.synchronize(force: true);
        } finally {
          await sync.close();
        }
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
        await repo.saveDraft(draftId, {'reps': '9', 'load': '65'});
        final manifest = await server.bootstrap(
          (await repo.syncMetadata())['installation_id'] as String,
        );
        await repo.stageBootstrap(manifest);
        await repo.stageBootstrapPage(0, await server.page(manifest.token, 0));
        await db.customStatement('UPDATE sessions SET has_conflict=1');
        await reconstructLegacySchema(db, version);
        repo.dispose();
        await db.close();
        final original = inspectRows();
        final raw = native.sqlite3.open(file.path);
        try {
          expect(
            raw.select('PRAGMA user_version').single.values.single,
            version,
          );
          raw.execute('CREATE INDEX historical_receipts ON outbox(state)');
        } finally {
          raw.close();
        }
        db = TrainingDatabase.open(file);
        repo = WorkoutRepository(db, testOwner);
        await expectLater(repo.initialize(), throwsA(anything));
        repo.dispose();
        await db.close();
        final failed = native.sqlite3.open(file.path);
        try {
          expect(
            failed.select('PRAGMA user_version').single.values.single,
            version,
          );
          expect(
            failed
                .select('PRAGMA table_info(outbox)')
                .any((row) => row['name'] == 'wire_version'),
            false,
          );
          if (version == 1) {
            expect(
              failed
                  .select('PRAGMA table_info(sessions)')
                  .any((row) => row['name'] == 'branch_base'),
              false,
            );
          }
          failed.execute('DROP INDEX historical_receipts');
        } finally {
          failed.close();
        }
        expect(
          inspectRows(),
          original,
          reason: 'Every earlier ALTER/data change must roll back with the failed upgrade.',
        );
        db = TrainingDatabase.open(file);
        repo = WorkoutRepository(db, testOwner);
        await repo.initialize();
        final upgraded = inspectRows();
        for (final table in original.keys) {
          final before = (original[table] as List).cast<Json>();
          final after = (upgraded[table] as List).cast<Json>();
          expect(after.length, before.length);
          for (var index = 0; index < before.length; index++) {
            expect(
              {for (final key in before[index].keys) key: after[index][key]},
              before[index],
              reason:
                  'Schema $version must retain the exact old $table row/serialized bytes.',
            );
          }
        }
        expect(await repo.draft(draftId), {'reps': '9', 'load': '65'});
        expect((await repo.workout(id))!['conflict'], true);
        expect((await repo.workout(id))!['local_seq'], 3);
        expect(await repo.pendingCount(), 2);
        expect(
          (await db
                  .customSelect('SELECT * FROM outbox ORDER BY local_seq')
                  .get())
              .every(
                (row) =>
                    row.read<int>('wire_version') == 1 &&
                    row.readNullable<String>('origin_context') == null,
              ),
          true,
        );
        await repo.installRecoveryContext(context());
        expect(await repo.prepareHead(id), isNull);
        expect(
          (await db
                  .customSelect(
                    "SELECT frozen_body FROM outbox WHERE state='pending' ORDER BY local_seq LIMIT 1",
                  )
                  .getSingle())
              .read<String>('frozen_body'),
          frozen,
        );
        if (version > 1) {
          final current = await server.validateSnapshot(manifest.token);
          await expectLater(repo.activateBootstrap(current), throwsA(anything));
          expect(inspectRows()['bootstrap_stage'], original['bootstrap_stage']);
          expect(inspectRows()['bootstrap_pages'], original['bootstrap_pages']);
        } else {
          // Schema 1 predates staging; the upgrade creates empty stage tables.
          expect(upgraded['bootstrap_stage'], isEmpty);
          expect(upgraded['bootstrap_pages'], isEmpty);
        }
        await reopen();
        expect(await repo.prepareHead(id), isNull);
        expect(await repo.pendingCount(), 2);
        expect(await repo.draft(draftId), {'reps': '9', 'load': '65'});
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        repo.dispose();
        await db.close();
        await directory.delete(recursive: true);
      }
    }
  });

  test('test_origin_projection_outbox_atomic_restart', () async {
    for (final stage in [
      'before_commit',
      'during_commit',
      'after_commit',
      'during_freeze',
      'after_freeze',
    ]) {
      await assertHardKillRecovery(protocol: 'v2', stage: stage);
    }
    final directory = await Directory.systemTemp.createTemp(
      'drp2-atomic-origin-',
    );
    final file = File('${directory.path}/training.sqlite');
    var db = TrainingDatabase.open(file);
    var repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    await repo.installRecoveryContext(context());
    try {
      await db.customStatement(
        "CREATE TRIGGER fail_insert BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic command persistence failure'); END",
      );
      await expectLater(repo.startFoundationWorkout(), throwsA(anything));
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      expect(await repo.workouts(), isEmpty);
      for (final table in [
        'outbox',
        'exercises',
        'workout_sets',
        'local_observations',
      ]) {
        expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
      }
      expect((await repo.recoveryContext())!.json, context().json);
      await db.customStatement('DROP TRIGGER fail_insert');
      final id = await repo.startFoundationWorkout();
      final original =
          (await db.customSelect('SELECT * FROM outbox').getSingle()).data;
      await db.customStatement(
        "CREATE TRIGGER fail_freeze BEFORE UPDATE OF frozen_body ON outbox BEGIN SELECT RAISE(ABORT,'synthetic freeze failure'); END",
      );
      await expectLater(repo.prepareHead(id), throwsA(anything));
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      expect(
        (await db.customSelect('SELECT * FROM outbox').getSingle()).data,
        original,
      );
      expect((await repo.workout(id))!['local_seq'], 1);
      await db.customStatement('DROP TRIGGER fail_freeze');
      final frozen = (await repo.prepareHead(id))!;
      expect(frozen, original['operation']);
      final mutation = jsonDecode(frozen)['mutation_id'];
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      expect(await repo.prepareHead(id), frozen);
      final row =
          (await db.customSelect('SELECT * FROM outbox').getSingle()).data;
      expect(row['mutation_id'], mutation);
      expect(row['wire_version'], 2);
      expect(row['origin_context'], canonicalJson(context().origin));
      expect(await repo.pendingCount(), 1);
    } finally {
      repo.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('test_grant_loss_and_signed_out_owner_not_guessed', () async {
    // Real owner files and controller gates; protected storage/provider are
    // deterministic fakes, not native secure-storage or OTP qualification.
    for (final fault in ['missing', 'corrupt', 'signed_out']) {
      final directory = await Directory.systemTemp.createTemp(
        'drp2-grant-$fault-',
      );
      final secure = MemoryProtectedStorage();
      final storage = SecureSessionStorage(secure, 'synthetic-drp2-project');
      final clock = DateTime.utc(2026, 10, 22);
      final provider = FakeOtpProvider(testSession(testOwner, clock));
      final servers = {
        testOwner: SyncServer(),
        ownerB: SyncServer()..owner = ownerB,
      };
      final gateway = FakeAccountGateway(servers);
      AccountController controller() => AccountController(
        provider: provider,
        gateway: gateway,
        storage: storage,
        stores: LocalOwnerStores(directory),
        syncTransport: (owner, token) => servers[owner]!,
        clock: () => clock,
      )..foreground(false);
      var account = controller();
      Future<void> signIn(String owner) async {
        provider.session = testSession(owner, clock);
        await account.requestOtp('synthetic@example.test');
        await account.verifyOtp('123456');
        expect(
          account.state.phase,
          AccountPhase.authenticated,
          reason: account.state.code,
        );
      }

      // Forensic inspection is not an application unlock: no initialize,
      // owner guessing, network request or mutation is performed here.
      Future<String> inspectOwnerRows() async {
        final db = native.sqlite3.open(
          '${directory.path}/owner-$testOwner.sqlite',
          mode: native.OpenMode.readOnly,
        );
        try {
          return canonicalJson({
            for (final table in [
              'local_identity',
              'outbox',
              'sessions',
              'exercises',
              'workout_sets',
              'local_observations',
              'drafts',
              'rest_timers',
              'shadows',
              'sync_metadata',
              'bootstrap_stage',
              'bootstrap_pages',
              'recovery_state',
              'historical_receipts',
            ])
              table: [
                for (final row in db.select(
                  'SELECT * FROM $table ORDER BY rowid',
                ))
                  Map<String, dynamic>.from(row),
              ],
          });
        } finally {
          db.close();
        }
      }

      try {
        await signIn(testOwner);
        final repo = account.local!.repository;
        await repo.installRecoveryContext(context());
        final id = await repo.startFoundationWorkout();
        final frozen = await repo.prepareHead(id);
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!),
        );
        final draftId =
            allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
        await repo.saveDraft(draftId, {'reps': '8'});
        await repo.db.customStatement(
          "UPDATE local_identity SET cursor='original-owner-cursor'",
        );
        await repo.db.customStatement(
          "INSERT INTO bootstrap_stage(singleton,manifest) VALUES(1,'{}')",
        );
        final unlockedGrant = secure.values[storage.ownerKey]!;
        if (fault == 'signed_out') await account.signOut();
        await account.close();
        if (fault == 'missing') secure.values.remove(storage.ownerKey);
        if (fault == 'corrupt') secure.values[storage.ownerKey] = '{broken';
        await storage.removePersistedSession();
        final before = await inspectOwnerRows();
        final calls = gateway.calls;
        account = controller();
        await account.restore();
        expect(account.local, isNull);
        expect(account.owner, isNull);
        expect(account.coordinator, isNull);
        if (fault == 'corrupt') {
          expect(account.state.code, 'local_identity_unavailable');
        }
        await account.refresh();
        expect(
          gateway.calls,
          calls,
          reason: 'No subject is guessed from the existing database filename.',
        );
        expect(await inspectOwnerRows(), before);
        await signIn(ownerB);
        expect(await account.local!.repository.workouts(), isEmpty);
        expect(await account.local!.repository.pendingCount(), 0);
        expect(
          (await account.local!.repository.syncMetadata())['cursor'],
          isNull,
        );
        expect(await account.local!.repository.draft(draftId), isNull);
        expect(await inspectOwnerRows(), before);
        expect(servers[testOwner]!.pushed, isEmpty);
        await account.signOut();
        await signIn(testOwner);
        final returned = account.local!.repository;
        expect(await returned.prepareHead(id), frozen);
        expect(await returned.pendingCount(), 2);
        expect(await returned.draft(draftId), {'reps': '8'});
        expect(
          (await returned.syncMetadata())['cursor'],
          'original-owner-cursor',
        );
        expect(
          (await returned.db
                  .customSelect('SELECT manifest FROM bootstrap_stage')
                  .getSingle())
              .read<String>('manifest'),
          '{}',
        );
        expect(
          allSets((await returned.workout(id))!)
              .first['observation']['actual']['reps'],
          5,
        );
        await account.signOut();
        await account.close();
        // A stale unlocked grant cannot undo the database's explicit sign-out.
        secure.values[storage.ownerKey] = unlockedGrant;
        account = controller();
        await account.restore();
        expect(account.local, isNull);
        expect(account.state.phase, AccountPhase.signedOut);
        expect((await storage.restoreOwner())!['unlocked'], false);
      } finally {
        await account.close();
        await directory.delete(recursive: true);
      }
    }
  });

  test('test_authority_auth_failure_does_not_block_training', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drp2-local-availability-',
    );
    final file = File('${directory.path}/training.sqlite');
    final responseStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var failRefresh = false;
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      await request.drain<void>();
      if (!responseStarted.isCompleted) responseStarted.complete();
      await releaseResponse.future;
      request.response.statusCode = 503;
      request.response.write(
        jsonEncode({
          'detail': {'code': 'recovery_unavailable'},
        }),
      );
      await request.response.close();
    });
    final transport = HttpSyncTransport(
      Uri.parse('http://127.0.0.1:${server.port}'),
      () async {
        if (failRefresh) {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          await releaseRefresh.future;
          throw const SyncFailure('authentication_required');
        }
        return 'synthetic-test-token';
      },
      allowLoopbackHttp: true,
    );
    var db = TrainingDatabase.open(file);
    var repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    await repo.installRecoveryContext(context());
    final sync = SyncCoordinator(repo, transport, jitter: () => 0.5);
    try {
      final id = await repo.startFoundationWorkout();
      final frozen = await repo.prepareHead(id);
      final cloud = sync.synchronize(force: true);
      await responseStarted.future.timeout(const Duration(seconds: 10));
      final first = recordPayload((await repo.workout(id))!);
      await repo
          .commit(id, 'record_set', first)
          .timeout(const Duration(seconds: 10));
      final correction = recordPayload((await repo.workout(id))!, reps: 7)
        ..['completion_seq'] = 1
        ..['correction_reason'] = 'Corrected entry';
      await repo
          .commit(id, 'correct_set', correction)
          .timeout(const Duration(seconds: 10));
      expect(
        releaseResponse.isCompleted,
        false,
        reason: 'Local saves completed before the blocked HTTP response was released.',
      );
      releaseResponse.complete();
      await cloud;
      expect(sync.status.code, 'recovery_unavailable');
      failRefresh = true;
      final auth = sync.synchronize(force: true);
      await refreshStarted.future.timeout(const Duration(seconds: 10));
      final draftId =
          allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
      await repo.saveDraft(draftId, {'reps': '9'});
      await repo
          .commit(id, 'complete_session', {})
          .timeout(const Duration(seconds: 10));
      expect((await repo.workouts()).single['status'], 'completed');
      expect(await repo.prepareHead(id), frozen);
      expect(await repo.pendingCount(), 4);
      expect(
        releaseRefresh.isCompleted,
        false,
        reason: 'Completion/history/draft reads finished without waiting for token refresh.',
      );
      releaseRefresh.complete();
      await auth;
      expect(sync.status.phase, SyncPhase.authenticationRequired);
      expect(
        requests,
        1,
        reason: 'Failed token refresh never submitted another HTTP request.',
      );
      sync.foreground(false);
      await sync.close();
      repo.dispose();
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      final restored = (await repo.workout(id))!;
      expect(restored['status'], 'completed');
      expect(allSets(restored).first['observation']['actual']['reps'], 7);
      expect(await repo.draft(draftId), {'reps': '9'});
      expect(await repo.prepareHead(id), frozen);
      expect(await repo.pendingCount(), 4);
      expect(
        (await repo.syncMetadata())['last_error'],
        'authentication_required',
      );
      expect(await repo.remoteDisabled(), false);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      if (!releaseResponse.isCompleted) releaseResponse.complete();
      if (!releaseRefresh.isCompleted) releaseRefresh.complete();
      await sync.close();
      repo.dispose();
      await db.close();
      transport.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  for (final denial in [
    (503, 'recovery_unavailable', true),
    (503, 'recovery_metadata_unverified', true),
    (202, 'publication_pending', true),
    (409, 'timeline_reconciliation_required', false),
    (426, 'upgrade_required', false),
    // Maintenance cannot impersonate genuine, verified account disable.
    (503, 'account_inactive', true),
  ]) {
    final (status, remoteCode, retryable) = denial;
    final code = remoteCode == 'account_inactive' ? 'http_503' : remoteCode;
    test(
      '$status $remoteCode preserves local training and frozen work on restart',
      () async {
        final directory = await Directory.systemTemp.createTemp('drp2-denial-');
        final file = File('${directory.path}/training.sqlite');
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var requests = 0;
        server.listen((request) async {
          requests++;
          await request.drain<void>();
          request.response.statusCode = status;
          request.response.write(
            jsonEncode({
              'detail': {
                'code': remoteCode,
                'owner_id': testOwner,
                'schema_version': 1,
              },
            }),
          );
          await request.response.close();
        });
        final transport = HttpSyncTransport(
          Uri.parse('http://127.0.0.1:${server.port}'),
          () async => 'synthetic-test-token',
          allowLoopbackHttp: true,
        );
        var db = TrainingDatabase.open(file);
        var repo = WorkoutRepository(db, testOwner);
        await repo.initialize();
        var sync = SyncCoordinator(repo, transport, jitter: () => 0.5);
        try {
          final id = await repo.startFoundationWorkout();
          final frozen = await repo.prepareHead(id);
          await expectLater(
            transport.me(),
            throwsA(
              isA<SyncFailure>()
                  .having((e) => e.code, 'code', code)
                  .having((e) => e.retryable, 'retryable', retryable),
            ),
          );
          await sync.synchronize(force: true);
          expect(sync.status.code, code);
          expect(
            sync.status.phase,
            retryable ? SyncPhase.pending : SyncPhase.attention,
          );
          sync.foreground(false);
          expect(await repo.remoteDisabled(), false);
          expect(await repo.prepareHead(id), frozen);

          await repo.commit(
            id,
            'record_set',
            recordPayload((await repo.workout(id))!),
          );
          final setId =
              allSets((await repo.workout(id))!).elementAt(1)['set_id']
                  as String;
          await repo.saveDraft(setId, {'reps': '7'});
          await repo.commit(id, 'complete_session', {});
          expect(await repo.pendingCount(), 3);
          await sync.close();
          repo.dispose();
          await db.close();
          db = TrainingDatabase.open(file);
          repo = WorkoutRepository(db, testOwner);
          await repo.initialize();
          sync = SyncCoordinator(repo, transport);
          expect((await repo.syncMetadata())['last_error'], code);
          expect((await repo.workout(id))!['status'], 'completed');
          expect((await repo.workout(id))!['conflict'], false);
          expect(
            allSets((await repo.workout(id))!)
                .first['observation']['actual']['reps'],
            5,
          );
          expect(await repo.draft(setId), {'reps': '7'});
          expect(await repo.prepareHead(id), frozen);
          expect(await repo.pendingCount(), 3);
          expect(await repo.remoteDisabled(), false);
          if (!retryable) {
            final before = requests;
            await sync.synchronize();
            expect(sync.status.phase, SyncPhase.attention);
            expect(
              requests,
              before,
              reason: 'Attention must survive an automatic new cycle.',
            );
          }
          expect(
            (await db.customSelect('PRAGMA integrity_check').getSingle())
                .data
                .values
                .single,
            'ok',
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await sync.close();
          repo.dispose();
          await db.close();
          transport.close();
          await server.close(force: true);
          // Only the directory created by this test is removed.
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
