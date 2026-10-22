import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/local_owners.dart';

import 'support/auth_fakes.dart';

import 'repository_test.dart' show recordPayload, fixture;

class DroppedResponseTransport extends HttpSyncTransport {
  @override
  Future<SyncTransport> beginCycle() async => this;
  bool drop = true;
  final requests = <String>[];
  DroppedResponseTransport(super.base, super.accessToken)
    : super(allowLoopbackHttp: true);
  @override
  Future<PushResponseDto> push(String body) async {
    requests.add(body);
    final response = await super.push(body);
    if (drop) {
      drop = false;
      throw const SyncFailure('response_lost', retryable: true);
    }
    return response;
  }
}

void main() {
  final endpoint = Platform.environment['DM_SYNC_ENDPOINT'];
  final enabled = endpoint != null;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late HttpSyncTransport transport;
  late SyncCoordinator sync;
  setUp(() async {
    if (!enabled) return;
    db = TrainingDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    transport = HttpSyncTransport(
      Uri.parse(endpoint),
      () async => Platform.environment['DM_SYNC_TOKEN'],
      allowLoopbackHttp: true,
    );
    sync = SyncCoordinator(repo, transport, jitter: () => 0.5);
  });
  tearDown(() async {
    if (enabled) {
      await sync.close();
      transport.close();
      repo.dispose();
      await db.close();
    }
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

  Future<WorkoutRepository> device(TrainingDatabase otherDb) async {
    final other = WorkoutRepository(otherDb, repo.ownerId);
    await other.initialize();
    return other;
  }

  Future<Json> cloudRoot(String id) async {
    final manifest = await transport.bootstrap(repo.newId());
    final roots = <Json>[];
    for (var i = 0; i < manifest.pageCount; i++) {
      roots.addAll(
        (await transport.page(manifest.token, i)).roots.cast<Json>(),
      );
    }
    return roots.singleWhere((r) => r['aggregate_id'] == id);
  }

  test('real signed JWT, restricted PostgreSQL upload, own echo and second-device bootstrap', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
    expect((await cloudRoot(id))['revision'], 2);
    final otherDb = TrainingDatabase(NativeDatabase.memory());
    final other = await device(otherDb);
    final otherSync = SyncCoordinator(other, transport);
    try {
      await otherSync.synchronize(force: true);
      expect(
        allSets((await other.workout(id))!)
            .first['observation']['actual']['reps'],
        5,
      );
      expect((await other.syncMetadata())['position'], greaterThanOrEqualTo(2));

      await repo.commit(id, 'complete_session', {});
      final recorded = recordPayload((await repo.workout(id))!);
      await repo.commit(id, 'correct_set', {
        ...recorded,
        'completion_seq': 1,
        'execution_status': 'skipped',
        'actual': null,
        'correction_reason': 'The set was recorded by mistake.',
      });
      await sync.synchronize(force: true);
      expect(
        sync.status.phase,
        SyncPhase.synchronized,
        reason: sync.status.code,
      );
      final corrected = await cloudRoot(id);
      expect(corrected['revision'], 4);
      expect(corrected['status'], 'completed');
      expect(
        allSets(corrected).first['observation']['execution_status'],
        'skipped',
      );

      final manifest = await transport.bootstrap(
        (await other.syncMetadata())['installation_id'] as String,
      );
      await other.stageBootstrap(manifest);
      for (var index = 0; index < manifest.pageCount; index++) {
        await other.stageBootstrapPage(
          index,
          await transport.page(manifest.token, index),
        );
      }
      await other.activateBootstrap(
        await transport.validateSnapshot(manifest.token),
      );
      final restored = (await other.workout(id))!;
      expect(restored['status'], 'completed');
      expect(
        allSets(restored).first['observation']['execution_status'],
        'skipped',
      );
      expect(allSets(restored).first['observation']['actual'], isNull);
      expect(
        allSets(restored).first['observation']['correction_reason'],
        'The set was recorded by mistake.',
      );
      expect((await other.syncMetadata())['position'], greaterThanOrEqualTo(4));
    } finally {
      await otherSync.close();
      other.dispose();
      await otherDb.close();
    }
  }, skip: !enabled);

  test('contract defaults and arbitrary supported IANA timezone survive real feed and snapshot', () async {
    await sync.synchronize(force: true);
    final op = fixture();
    op['mutation_id'] = repo.newId();
    op['aggregate_id'] = repo.newId();
    op['installation_id'] = repo.newId();
    op['payload']['timezone'] = 'America/New_York';
    op['payload']['name'] = List.filled(80, '🏋').join();
    for (final exercise in op['payload']['exercises'] as List) {
      exercise['name'] = List.filled(80, '🏋').join();
      exercise['session_exercise_id'] = repo.newId();
      exercise.remove('side');
      for (final item in exercise['sets'] as List) {
        item['set_id'] = repo.newId();
        item.remove('set_class');
        item.remove('set_purpose');
        item['planned'].remove('rest_seconds');
      }
    }
    final raw = canonicalJson(op);
    final response = await transport.push(
      '{"schema_version":1,"operations":[$raw]}',
    );
    expect(response.results.single['status'], 'accepted');
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
    final root = (await repo.workout(op['aggregate_id'] as String))!;
    expect(root['timezone'], 'America/New_York');
    expect(root['name'], op['payload']['name']);
    expect(allSets(root).first['set_class'], 'working');
    expect(allSets(root).first['planned']['rest_seconds'], 120);
    final feed = await transport.pull(null);
    expect(
      canonicalJson(
        feed.changes.singleWhere(
          (c) => c['operation']?['mutation_id'] == op['mutation_id'],
        )['operation'],
      ),
      raw,
    );
    expect(
      allSets(await cloudRoot(op['aggregate_id'] as String))
          .first['set_purpose'],
      'regular',
    );
  }, skip: !enabled);

  test('real receipt after dropped committed response is exact and replay-safe', () async {
    final id = await recorded();
    await sync.close();
    final dropped = DroppedResponseTransport(
      Uri.parse(endpoint!),
      () async => Platform.environment['DM_SYNC_TOKEN'],
    );
    sync = SyncCoordinator(repo, dropped);
    try {
      await sync.synchronize(force: true);
      expect((await cloudRoot(id))['revision'], 1);
      expect(await repo.pendingCount(), 2);
      final frozen = await repo.prepareHead(id);
      await sync.synchronize(force: true);
      expect((await cloudRoot(id))['revision'], 2);
      final delivered = dropped.requests
          .expand((s) => (jsonDecode(s)['operations'] as List).cast<Json>())
          .where((op) => op['command'] == 'create_session')
          .map(canonicalJson)
          .toSet();
      // Recovery can acknowledge through its own pulled echo before resending.
      expect(delivered, {frozen});
      expect(await repo.pendingCount(), 0);
    } finally {
      dropped.close();
    }
  }, skip: !enabled);

  test('real digest mismatch and exact duplicate results', () async {
    final id = await recorded();
    final frozen = (await repo.prepareHead(id))!;
    final batch = '{"schema_version":1,"operations":[$frozen]}';
    expect((await transport.push(batch)).results.single['status'], 'accepted');
    expect((await transport.push(batch)).results.single['status'], 'duplicate');
    final changed = jsonDecode(frozen) as Json;
    changed['payload']['name'] = 'Changed under same mutation';
    final rejected = await transport.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [changed],
      }),
    );
    expect(
      rejected.results.single['error']['code'],
      'mutation_digest_mismatch',
    );
  }, skip: !enabled);

  test('two real devices conflict without losing either branch', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    final otherDb = TrainingDatabase(NativeDatabase.memory());
    final other = await device(otherDb);
    final otherSync = SyncCoordinator(other, transport);
    try {
      await otherSync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1, reps: 6),
      );
      await other.commit(
        id,
        'record_set',
        recordPayload((await other.workout(id))!, index: 1, reps: 9),
      );
      await otherSync.synchronize(force: true);
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.attention);
      expect(
        allSets((await repo.workout(id))!)
            .elementAt(1)['observation']['actual']['reps'],
        6,
      );
      expect(
        allSets(await cloudRoot(id))
            .elementAt(1)['observation']['actual']['reps'],
        9,
      );
    } finally {
      await otherSync.close();
      other.dispose();
      await otherDb.close();
    }
  }, skip: !enabled);

  test('real deletion retires pending branch, redacts feed and invalidates snapshot', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    final stale = (await repo.prepareHead(id))!;
    final snapshot = await transport.bootstrap(repo.newId());
    final delete = {
      'mutation_id': repo.newId(),
      'installation_id': repo.newId(),
      'aggregate_type': 'workout_session',
      'aggregate_id': id,
      'expected_revision': 2,
      'command': 'delete_session',
      'occurred_at': '2026-10-13T07:00:00Z',
      'recorded_at': '2026-10-13T07:00:00Z',
      'payload': <String, dynamic>{},
    };
    await transport.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [delete],
      }),
    );
    await expectLater(
      transport.page(snapshot.token, 0),
      throwsA(isA<SyncFailure>()),
    );
    await sync.synchronize(force: true);
    expect(await repo.workout(id), null, reason: sync.status.code);
    expect(
      (await transport.push('{"schema_version":1,"operations":[$stale]}'))
          .results
          .single['error']['code'],
      'retired_id',
    );
    final feed = await transport.pull(null);
    expect(
      feed.changes
          .where((c) => c['aggregate_id'] == id)
          .every((c) => c['redacted'] == true),
      isTrue,
    );
  }, skip: !enabled);

  test('expired signed credentials pause cloud synchronization while logging continues', () async {
    final id = await recorded();
    await sync.close();
    transport.close();
    transport = HttpSyncTransport(
      Uri.parse(endpoint!),
      () async => Platform.environment['DM_SYNC_EXPIRED_TOKEN'],
      allowLoopbackHttp: true,
    );
    sync = SyncCoordinator(repo, transport);
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.authenticationRequired);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    expect(await repo.pendingCount(), 3);
  }, skip: !enabled);

  test('real SQLite restart after delivered request recovers through real HTTP receipt/echo', () async {
    await sync.close();
    await db.close();
    final dir = await Directory.systemTemp.createTemp('connected-restart-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    sync = SyncCoordinator(repo, transport);
    final id = await recorded();
    final frozen = (await repo.prepareHead(id))!;
    await transport.push('{"schema_version":1,"operations":[$frozen]}');
    await sync.close();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    sync = SyncCoordinator(repo, transport);
    expect(await repo.prepareHead(id), frozen);
    await sync.synchronize(force: true);
    expect((await cloudRoot(id))['revision'], 2);
    expect(await repo.pendingCount(), 0);
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  }, skip: !enabled);
  test('account initialization and A to B to A recovery use real authenticated HTTP and separate SQLite stores', () async {
    final configuration = AuthConfiguration(
      supabaseUrl: 'https://identity.daily-motion.test',
      apiUrl: endpoint!,
      publishableKey: 'sb_publishable_synthetic',
      environment: 'development',
      release: false,
    );
    final secure = MemoryProtectedStorage();
    final protected = SecureSessionStorage(secure, configuration.namespace);
    final directory = await Directory.systemTemp.createTemp('http-auth-owner-');
    final a = Platform.environment['DM_SYNC_OWNER']!;
    final b = Platform.environment['DM_SYNC_OWNER_B']!;
    final provider = FakeOtpProvider(
      testSession(
        a,
        DateTime.now().toUtc(),
        token: Platform.environment['DM_SYNC_TOKEN'],
      ),
    );
    final account = AccountController(
      provider: provider,
      gateway: HttpAccountGateway(configuration),
      storage: protected,
      stores: LocalOwnerStores(directory),
      syncTransport: (_, token) =>
          HttpSyncTransport(configuration.api, token, allowLoopbackHttp: true),
    );
    account.foreground(false);
    Future<void> login(String subject, String token) async {
      provider.session = testSession(
        subject,
        DateTime.now().toUtc(),
        token: token,
      );
      await account.requestOtp('synthetic@example.test');
      await account.verifyOtp('123456');
      expect(
        account.state.phase,
        AccountPhase.authenticated,
        reason: account.state.code,
      );
    }

    try {
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      final local = account.local!.repository;
      expect(await local.workouts(), isEmpty);
      final id = await local.startFoundationWorkout();
      await local.commit(
        id,
        'record_set',
        recordPayload((await local.workout(id))!),
      );
      final frozen = await local.prepareHead(id);
      await account.signOut();
      await login(b, Platform.environment['DM_SYNC_TOKEN_B']!);
      expect(await account.local!.repository.workouts(), isEmpty);
      expect(await account.local!.repository.pendingCount(), 0);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect((await account.local!.repository.syncMetadata())['position'], 0);
      await account.signOut();
      account.foreground(false);
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      expect(await account.local!.repository.prepareHead(id), frozen);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect(await account.local!.repository.pendingCount(), 0);
      expect((await cloudRoot(id))['revision'], 2);
    } finally {
      await account.close();
      await directory.delete(recursive: true);
    }
  }, skip: !enabled);
}
