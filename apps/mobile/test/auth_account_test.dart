import 'dart:async';
import 'dart:io';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_test.dart' show recordPayload;
import 'support/auth_fakes.dart';
import 'support/sync_server.dart';

void main() {
  late Directory directory;
  late MemoryProtectedStorage secure;
  late SecureSessionStorage storage;
  late FakeOtpProvider provider;
  late FakeAccountGateway gateway;
  late AccountController account;
  late Map<String, SyncServer> servers;
  var clock = DateTime.utc(2026, 10, 13);
  AccountController controller() => AccountController(
    provider: provider,
    gateway: gateway,
    storage: storage,
    stores: LocalOwnerStores(directory),
    syncTransport: (owner, token) => servers[owner]!,
    clock: () => clock,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auth-owner-');
    clock = DateTime.utc(2026, 10, 13);
    secure = MemoryProtectedStorage();
    storage = SecureSessionStorage(secure, 'synthetic-project');
    provider = FakeOtpProvider(testSession(testOwner, clock));
    servers = {testOwner: SyncServer(), ownerB: SyncServer()..owner = ownerB};
    gateway = FakeAccountGateway(servers);
    account = controller();
    account.foreground(false);
  });
  tearDown(() async {
    await account.close();
    await directory.delete(recursive: true);
  });
  Future<void> signIn({String owner = testOwner}) async {
    provider.session = testSession(owner, clock);
    await account.requestOtp('synthetic@example.test');
    await account.verifyOtp('123456');
    expect(
      account.state.phase,
      AccountPhase.authenticated,
      reason: account.state.code,
    );
  }

  Future<String> record() async {
    final repo = account.local!.repository;
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    return id;
  }

  test('first verified identity initializes only an owner store, without sample workouts', () async {
    await signIn();
    expect(await account.local!.repository.workouts(), isEmpty);
    expect((await storage.restoreOwner())!['owner'], testOwner);
    expect((await storage.restoreSession())!.refreshToken, 'synthetic-refresh');
    expect(gateway.calls, 1);
  });
  test('OTP request, resend cooldown and incorrect/expired verification errors are separate', () async {
    provider.requestFailure = const AuthFailure('otp_request_failed');
    await account.requestOtp('synthetic@example.test');
    expect(account.state.code, 'otp_request_failed');
    provider.requestFailure = null;
    await account.requestOtp('synthetic@example.test');
    expect(account.state.phase, AccountPhase.codeSent);
    await account.requestOtp('synthetic@example.test', resend: true);
    expect(account.state.code, 'throttled');
    clock = clock.add(const Duration(seconds: 61));
    await account.requestOtp('synthetic@example.test', resend: true);
    expect(provider.requests, 3);
    provider.verifyFailure = const AuthFailure('invalid_or_expired_code');
    await account.verifyOtp('123456');
    expect(account.state.code, 'invalid_or_expired_code');
    expect(account.local, null);
    expect(await storage.restoreOwner(), null);
  });
  test('lost initialization response retains verified session for idempotent retry', () async {
    gateway.failure = const SyncFailure('timeout', retryable: true);
    await account.requestOtp('synthetic@example.test');
    await account.verifyOtp('123456');
    expect(account.local, null);
    expect(await storage.restoreSession(), isNotNull);
    await account.retryInitialization();
    expect(account.owner, testOwner);
    expect(gateway.calls, 2);
  });
  test('resend cooldown starts after a slow OTP request completes', () async {
    provider.requestOperation = () async {
      clock = clock.add(const Duration(seconds: 75));
    };
    await account.requestOtp('synthetic@example.test');
    await account.requestOtp('synthetic@example.test', resend: true);

    expect(account.state.code, 'throttled');
    expect(provider.requests, 1);
    clock = clock.add(const Duration(seconds: 60));
    await account.requestOtp('synthetic@example.test', resend: true);
    expect(account.state.phase, AccountPhase.codeSent);
    expect(provider.requests, 2);
  });
  test('failed request for B cannot verify the previous A challenge', () async {
    await account.requestOtp('a@example.test');
    provider.requestFailure = const AuthFailure('network_unavailable');
    await account.requestOtp('b@example.test');
    var verifications = 0;
    provider.verification = () async {
      verifications++;
      return provider.session;
    };
    await account.verifyOtp('123456');

    expect(verifications, 0);
    expect(account.state.code, 'invalid_or_expired_code');
    expect(account.local, null);
    expect(await storage.restoreSession() == null, true);
    expect(gateway.calls, 0);
  });
  test('expired token and failed refresh permit logging, correction, completion and history', () async {
    await signIn();
    final id = await record();
    final repo = account.local!.repository;
    final frozen = await repo.prepareHead(id);
    clock = clock.add(const Duration(hours: 2));
    provider.refreshFailure = const AuthFailure(
      'network_unavailable',
      retryable: true,
    );
    await account.refresh();
    expect(account.state.phase, AccountPhase.offline);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    final correction = recordPayload((await repo.workout(id))!, reps: 6);
    correction['completion_seq'] = 1;
    correction['correction_reason'] = 'Entry correction';
    await repo.commit(id, 'correct_set', correction);
    await repo.commit(id, 'complete_session', {});
    expect((await repo.workouts()).single['status'], 'completed');
    expect(await repo.pendingCount(), 5);
    expect(await repo.prepareHead(id), frozen);
  });
  test('restart with expired or missing cloud session restores locally established owner', () async {
    await signIn();
    final id = await record();
    final frozen = await account.local!.repository.prepareHead(id);
    clock = clock.add(const Duration(hours: 2));
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(await account.local!.repository.prepareHead(id), frozen);
    expect(account.state.phase, AccountPhase.offline);
    await storage.removePersistedSession();
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.state.phase, AccountPhase.authenticationRequired);
    expect((await account.local!.repository.workout(id))!['status'], 'active');
    await account.local!.repository.commit(
      id,
      'record_set',
      recordPayload((await account.local!.repository.workout(id))!, index: 1),
    );
  });
  test('corrupt cloud session is cleared without deleting owner, workout or frozen outbox', () async {
    await signIn();
    final id = await record();
    await account.close();
    secure.values[storage.sessionKey] = '{broken';
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.owner, testOwner);
    expect(await storage.restoreSession(), null);
    expect(await account.local!.repository.pendingCount(), 2);
    expect(await account.local!.repository.workout(id), isNotNull);
  });
  test('A to B to A uses distinct real databases and preserves A cursor, draft, conflict and outbox', () async {
    await signIn();
    final id = await record();
    final a = account.local!.repository;
    final frozen = await a.prepareHead(id);
    final setId =
        allSets((await a.workout(id))!).elementAt(1)['set_id'] as String;
    await a.saveDraft(setId, {'reps': '7'});
    await a.db.customStatement("UPDATE sessions SET has_conflict=1");
    await a.db.customStatement(
      "UPDATE local_identity SET cursor='owner-a-cursor'",
    );
    await a.db.customStatement(
      "INSERT INTO bootstrap_stage(singleton,manifest) VALUES(1,'{}')",
    );
    await account.signOut();
    expect(await storage.restoreSession(), null);
    final locked = await LocalOwnerStores(directory)
        .open(testOwner, existing: true);
    await expectLater(
      locked.repository.workouts(),
      throwsA(isA<WorkoutValidation>()),
    );
    await locked.close();
    await signIn(owner: ownerB);
    final b = account.local!.repository;
    expect(await b.workouts(), isEmpty);
    expect(await b.pendingCount(), 0);
    expect((await b.syncMetadata())['cursor'], null);
    expect(await b.draft(setId), null);
    expect(await b.attentionCount(), 0);
    expect(await b.stagedBootstrap(), null);
    await account.signOut();
    await signIn();
    final returned = account.local!.repository;
    expect(await returned.prepareHead(id), frozen);
    expect(await returned.draft(setId), {'reps': '7'});
    expect((await returned.syncMetadata())['cursor'], 'owner-a-cursor');
    expect(await returned.attentionCount(), 1);
    expect(await servers[ownerB]!.me(), isNotNull);
    expect(servers[ownerB]!.pushed, isEmpty);
  });
  test('different verified account cannot unlock or replace an established local owner', () async {
    await signIn();
    final id = await record();
    provider.session = testSession(ownerB, clock);
    await account.requestOtp('different@example.test');
    await account.verifyOtp('123456');
    expect(account.state.code, 'wrong_owner');
    expect(account.owner, testOwner);
    expect(await account.local!.repository.workout(id), isNotNull);
    expect((await storage.restoreOwner())!['owner'], testOwner);
  });
  test('late verification completion after sign-out cannot recreate an owner grant', () async {
    await account.requestOtp('synthetic@example.test');
    final arrived = Completer<void>();
    final response = Completer<Session>();
    provider.verification = () async {
      arrived.complete();
      return response.future;
    };
    final verifying = account.verifyOtp('123456');
    await arrived.future;
    final logout = account.signOut();
    response.complete(testSession(testOwner, clock));
    await verifying;
    await logout;
    expect(account.local, null);
    expect(await storage.restoreOwner(), null);
    expect(await storage.restoreSession(), null);
  });
  test(
    'late refresh after sign-out cannot populate the next account session',
    () async {
      await signIn();
      await record();
      final arrived = Completer<void>();
      final result = Completer<Session>();
      provider.refreshOperation = () async {
        arrived.complete();
        return result.future;
      };
      final refreshing = account.refresh();
      await arrived.future;
      final logout = account.signOut();
      result.complete(
        testSession(testOwner, clock, refresh: 'rotated-refresh'),
      );
      await refreshing;
      await logout;
      provider.refreshOperation = null;
      await signIn(owner: ownerB);
      expect((await storage.restoreSession())!.user.id, ownerB);
      expect(account.owner, ownerB);
    },
  );
  test('successful reauthentication resumes original frozen mutations and own receipts', () async {
    await signIn();
    final id = await record();
    final frozen = await account.local!.repository.prepareHead(id);
    clock = clock.add(const Duration(hours: 2));
    provider.refreshFailure = const AuthFailure('authentication_required');
    await account.refresh();
    expect(account.state.phase, AccountPhase.authenticationRequired);
    provider.refreshFailure = null;
    await signIn();
    expect(await account.local!.repository.prepareHead(id), frozen);
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    expect(await account.local!.repository.pendingCount(), 0);
    expect(servers[testOwner]!.roots[id]!['revision'], 2);
  });
  test('refresh persistence failure preserves training and restart offers reauthentication', () async {
    await signIn();
    final id = await record();
    provider.session = testSession(testOwner, clock, refresh: 'new-refresh');
    secure.failWrite = true;
    await account.refresh();
    secure.failWrite = false;
    expect(await account.local!.repository.workout(id), isNotNull);
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(await account.local!.repository.pendingCount(), 2);
  });
  test('release configuration rejects synthetic flags, tokens, HTTP and privileged key formats', () {
    AuthConfiguration valid({
      bool release = true,
      String env = 'production',
      String key = 'sb_publishable_synthetic',
      String api = 'https://api.example.test',
      bool fixture = false,
      String token = '',
    }) => AuthConfiguration(
      supabaseUrl: 'https://project.supabase.co',
      apiUrl: api,
      publishableKey: key,
      environment: env,
      release: release,
      syntheticFixture: fixture,
      syntheticToken: token,
    );
    expect(() => valid(env: 'development'), throwsA(isA<AuthFailure>()));
    expect(() => valid(fixture: true), throwsA(isA<AuthFailure>()));
    expect(() => valid(token: 'synthetic'), throwsA(isA<AuthFailure>()));
    expect(
      () => valid(api: 'http://127.0.0.1:8000'),
      throwsA(isA<AuthFailure>()),
    );
    expect(() => valid(key: 'sb_secret_no'), throwsA(isA<AuthFailure>()));
    expect(valid().namespace, isNotEmpty);
    expect(
      valid(api: 'https://other-api.example.test').namespace,
      valid().namespace,
    );
  });
  test('sign-out during owner-grant persistence cannot leave an unlocked grant after restart', () async {
    final arrived = Completer<void>();
    final release = Completer<void>();
    secure.beforeWrite = (key, value) async {
      if (key == storage.ownerKey && value.contains('"unlocked":true')) {
        arrived.complete();
        await release.future;
      }
    };
    await account.requestOtp('synthetic@example.test');
    final verification = account.verifyOtp('123456');
    await arrived.future;
    final logout = account.signOut();
    release.complete();
    await verification;
    await logout;
    secure.beforeWrite = null;
    expect(account.local, null);
    expect((await storage.restoreOwner())!['unlocked'], false);
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.local, null);
    expect(account.state.phase, AccountPhase.signedOut);
  });
  test('failed secure logout still locks the real database and never transfers pending work', () async {
    await signIn();
    final id = await record();
    secure.failWrite = true;
    await account.signOut();
    secure.failWrite = false;
    expect(account.state.code, 'secure_storage_unavailable');
    expect(account.local, null);
    expect(provider.signOuts, 1);
    final locked = await LocalOwnerStores(directory)
        .open(testOwner, existing: true);
    await expectLater(
      locked.repository.workout(id),
      throwsA(isA<WorkoutValidation>()),
    );
    await locked.close();
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.local, null);
    expect(account.state.phase, AccountPhase.signedOut);
    await signIn();
    expect(await account.local!.repository.pendingCount(), 2);
  });
  test('verified identity with failed local owner creation can retry without adding sample data', () async {
    final directoryPath = directory.path;
    await directory.delete(recursive: true);
    await File(directoryPath).writeAsString('injected unavailable directory');
    await account.requestOtp('synthetic@example.test');
    await account.verifyOtp('123456');
    expect(account.local, null);
    expect(account.state.phase, AccountPhase.attention);
    await File(directoryPath).delete();
    await directory.create();
    await account.retryInitialization();
    expect(account.owner, testOwner);
    expect(await account.local!.repository.workouts(), isEmpty);
  });
  test('missing owner database never becomes an unverified fresh local account on restore', () async {
    await storage.saveOwner(testOwner, unlocked: true);
    await account.restore();
    expect(account.local, null);
    expect(account.state.code, 'local_identity_unavailable');
    expect(
      await File('${directory.path}/owner-$testOwner.sqlite').exists(),
      false,
    );
  });
  test('owned account disable purges according to existing sync policy and cannot unlock on restart', () async {
    await signIn();
    await record();
    await account.local!.repository.disableRemoteAccount();
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.state.phase, AccountPhase.disabled);
    expect(account.local, null);
    final disabled = await LocalOwnerStores(directory)
        .open(testOwner, existing: true);
    await expectLater(
      disabled.repository.unlockVerifiedOwner(testOwner),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(
      await disabled.database.customSelect('SELECT * FROM outbox').get(),
      isEmpty,
    );
    await disabled.close();
  });
  test('repeated invalid API authorization pauses sync without hammering provider refresh', () async {
    await signIn();
    servers[testOwner]!.before = (method) async {
      if (method == 'me') throw const SyncFailure('invalid_credentials');
    };
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(provider.refreshes, lessThanOrEqualTo(1));
    expect(account.local, isNotNull);
    expect(account.state.phase, AccountPhase.authenticationRequired);
  });
  test('disabled-account initialization also erases an already signed-out owner store', () async {
    await signIn();
    await record();
    await account.signOut();
    gateway.failure = const SyncFailure('account_inactive', ownerId: testOwner);
    await account.requestOtp('synthetic@example.test');
    await account.verifyOtp('123456');
    expect(account.state.phase, AccountPhase.disabled);
    final erased = await LocalOwnerStores(directory)
        .open(testOwner, existing: true);
    expect(
      await erased.database.customSelect('SELECT * FROM sessions').get(),
      isEmpty,
    );
    expect(await erased.repository.remoteDisabled(), true);
    await erased.close();
  });
  test(
    'refresh cannot persist a token for B disguised by an A user object',
    () async {
      await signIn();
      final id = await record();
      provider.session = testSession(
        testOwner,
        clock,
        token: testSession(ownerB, clock).accessToken,
      );
      await account.refresh();
      expect(account.state.phase, AccountPhase.authenticationRequired);
      expect(await account.local!.repository.workout(id), isNotNull);
      expect(await storage.restoreSession(), null);
    },
  );
  test('account switching while sync wakes drains only the original owner and preserves pending identity', () async {
    await signIn();
    final id = await record();
    final frozen = await account.local!.repository.prepareHead(id);
    final arrived = Completer<void>();
    final release = Completer<void>();
    servers[testOwner]!.before = (method) async {
      if (method == 'me') {
        arrived.complete();
        await release.future;
      }
    };
    account.foreground(true);
    await arrived.future;
    final logout = account.signOut();
    release.complete();
    await logout;
    expect(servers[testOwner]!.pushed, isEmpty);
    account.foreground(false);
    await signIn(owner: ownerB);
    expect(await account.local!.repository.workouts(), isEmpty);
    expect(servers[ownerB]!.pushed, isEmpty);
    await account.signOut();
    servers[testOwner]!.before = null;
    await signIn();
    expect(await account.local!.repository.prepareHead(id), frozen);
  });
  test('auth loss after server commit pauses without conflict and reauth reconciles the same mutation', () async {
    await signIn();
    final id = await record();
    final repo = account.local!.repository;
    final frozen = await repo.prepareHead(id);
    provider.refreshFailure = const AuthFailure('authentication_required');
    servers[testOwner]!.after = (method) async {
      if (method == 'push') {
        clock = clock.add(const Duration(hours: 2));
        throw const SyncFailure('invalid_credentials');
      }
    };
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await repo.workout(id))!['conflict'], false);
    expect(await repo.prepareHead(id), frozen);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    servers[testOwner]!.after = null;
    provider.refreshFailure = null;
    account.foreground(false);
    await signIn();
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    expect(await repo.pendingCount(), 0);
    expect(servers[testOwner]!.roots[id]!['revision'], 3);
  });
  test('authorization loss during bootstrap stops new requests and preserves staged and local work', () async {
    await signIn();
    final id = await record();
    final arrived = Completer<void>();
    final release = Completer<void>();
    final requests = <String>[];
    servers[testOwner]!.before = (method) async {
      requests.add(method);
      if (method == 'page') {
        arrived.complete();
        await release.future;
      }
    };
    account.foreground(true);
    await arrived.future;
    account.coordinator!.cloudAuthorization(false);
    release.complete();
    await account.coordinator!.synchronize();
    // Drain the already started bounded cycle without granting authorization.
    account.foreground(false);
    await account.coordinator!.close();
    expect(requests, ['me', 'bootstrap', 'page']);
    expect(await account.local!.repository.stagedBootstrap(), isNotNull);
    expect(await account.local!.repository.workout(id), isNotNull);
    expect(await account.local!.repository.pendingCount(), 2);
    await account.close();
    account = controller();
    account.foreground(false);
    servers[testOwner]!.before = null;
    await account.restore();
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    expect(await account.local!.repository.pendingCount(), 0);
    expect(await account.local!.repository.workout(id), isNotNull);
  });
  test('remote disable with unavailable secure storage drains safely and remains disabled after restart', () async {
    await signIn();
    await record();
    secure.failWrite = true;
    servers[testOwner]!.disabled = true;
    account.foreground(true);
    await account.coordinator!.synchronize(force: true);
    for (var attempt = 0; attempt < 200 && account.local != null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(account.local, null);
    expect(account.state.phase, AccountPhase.attention);
    expect(account.state.code, 'secure_storage_unavailable');
    secure.failWrite = false;
    await account.close();
    account = controller();
    account.foreground(false);
    await account.restore();
    expect(account.local, null);
    expect(account.state.phase, AccountPhase.disabled);
  });
}
