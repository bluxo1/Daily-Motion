import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/supabase_provider.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'repository_test.dart' show recordPayload;
import 'support/auth_fakes.dart' show MemoryProtectedStorage;
import 'support/auth_rejection.dart';

/// Real hosted providers and SQLite; memory storage does not qualify native keys.
/// The operator bridge supplies inbox codes in memory, never in test arguments.
void main() {
  final enabled = Platform.environment['DM_HOSTED_AUTH_LIFECYCLE'] == '1';
  test(
    'hosted SDK OTP, refresh, restart, remote sign-out and owner isolation',
    () async {
      final bridge = Uri.parse(
        Platform.environment['DM_HOSTED_OTP_BRIDGE'] ?? '',
      );
      if (bridge.scheme != 'http' ||
          bridge.host != '127.0.0.1' ||
          bridge.userInfo.isNotEmpty ||
          bridge.hasQuery ||
          bridge.hasFragment) {
        throw StateError('A local operator bridge is required');
      }
      final client = http.Client();
      Future<Json> operatorCall(
        String method,
        String path, [
        Json? data,
      ]) async {
        final headers = {
          'X-DM-Qualification': 'phase0-local',
          'Content-Type': 'application/json',
        };
        final response =
            await (method == 'GET'
                    ? client.get(bridge.resolve(path), headers: headers)
                    : client.post(
                        bridge.resolve(path),
                        headers: headers,
                        body: jsonEncode(data ?? {}),
                      ))
                .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw StateError('Operator bridge request failed');
        }
        return jsonDecode(response.body) as Json;
      }

      Future<void> event(String name) async {
        await operatorCall('POST', '/event', {'event': name});
      }

      final config = AuthConfiguration(
        environment: 'staging',
        supabaseUrl: Platform.environment['DM_SUPABASE_URL']!,
        apiUrl: Platform.environment['DM_API_URL']!,
        publishableKey: Platform.environment['DM_SUPABASE_PUBLISHABLE_KEY']!,
      );
      final storage = SecureSessionStorage(
        MemoryProtectedStorage(),
        config.namespace,
      );
      final provider = SupabaseOtpProvider(config, storage);
      final directory = await Directory.systemTemp.createTemp(
        'dm-hosted-auth-',
      );
      final stores = LocalOwnerStores(directory);
      AccountController controller() => AccountController(
        provider: provider,
        gateway: HttpAccountGateway(config),
        storage: storage,
        stores: stores,
        syncTransport: (_, token) => HttpSyncTransport(config.api, token),
      )..foreground(false);
      var account = controller();
      final requests = <String, DateTime>{};
      var invalidCodeChecked = false;
      Future<String> signIn(String label) async {
        final previous = requests[label];
        if (previous != null) {
          final remaining = previous
              .add(const Duration(seconds: 61))
              .difference(DateTime.now().toUtc());
          if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        }
        final address = (await operatorCall('GET', '/account/$label'))['email'];
        final requestedAt = DateTime.now().toUtc();
        await account.requestOtp(address as String);
        if (account.state.phase != AccountPhase.codeSent) {
          throw StateError('Hosted OTP request failed: ${account.state.code}');
        }
        requests[label] = requestedAt;
        if (requests.length == 1 && !invalidCodeChecked) {
          await expectLater(
            provider.request(address),
            throwsA(
              isA<AuthFailure>().having((e) => e.code, 'code', 'throttled'),
            ),
          );
          await event('provider_resend_throttle_passed');
        }
        final challenge = await operatorCall('POST', '/challenge', {
          'account': label,
          'requested_at': requestedAt.toIso8601String(),
        });
        final deadline = DateTime.now().add(const Duration(minutes: 3));
        while (DateTime.now().isBefore(deadline)) {
          final result = await operatorCall('GET', '/code/${challenge['id']}');
          final code = result['code'];
          if (code is String && RegExp(r'^\d{6}$').hasMatch(code)) {
            if (!invalidCodeChecked) {
              final wrong =
                  '${code.substring(0, 5)}${(int.parse(code[5]) + 1) % 10}';
              await account.verifyOtp(wrong);
              expect(account.state.code, 'invalid_or_expired_code');
              invalidCodeChecked = true;
              await event('incorrect_code_rejected');
            }
            await account.verifyOtp(code);
            if (account.canRetryInitialization &&
                account.state.code == 'timeout') {
              await account.retryInitialization();
            }
            if (account.state.phase != AccountPhase.authenticated) {
              throw StateError(
                'Hosted verification failed: ${account.state.code}',
              );
            }
            await event('${label.toLowerCase()}_verified');
            return account.owner!;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        throw StateError('Recipient inbox verification timed out');
      }

      try {
        final ownerA = await signIn('A');
        final beforeRefresh = (await storage.restoreSession())!;
        await account.refresh(force: true);
        expect(account.state.phase, AccountPhase.authenticated);
        final refreshed = (await storage.restoreSession())!;
        expect(refreshed.user.id == ownerA, true);
        expect(refreshed.refreshToken != beforeRefresh.refreshToken, true);
        await event('sdk_refresh_passed');

        final repository = account.local!.repository;
        final root = await repository.startFoundationWorkout();
        await repository.commit(
          root,
          'record_set',
          recordPayload((await repository.workout(root))!),
        );
        account.foreground(true);
        await account.coordinator!.synchronize(force: true);
        expect(account.coordinator!.status.phase, SyncPhase.synchronized);
        expect(await repository.pendingCount(), 0);
        account.foreground(false);
        await repository.commit(
          root,
          'record_set',
          recordPayload((await repository.workout(root))!, index: 1),
        );
        final frozen = (await repository.prepareHead(root))!;
        final attackPayload = (jsonDecode(frozen) as Json)['payload'];
        await account.close();
        account = controller();
        await account.restore();
        expect(account.owner, ownerA);
        expect(account.state.phase, AccountPhase.authenticated);
        expect(await account.local!.repository.prepareHead(root), frozen);
        await event('controller_file_restart_passed');

        final beforeLogout = (await storage.restoreSession())!;
        await account.signOut();
        expect(account.state.phase, AccountPhase.signedOut);
        expect(account.state.code, null);
        expect(await storage.restoreSession() == null, true);
        expect((await storage.restoreOwner())!['unlocked'], false);
        final locked = await stores.open(ownerA, existing: true);
        try {
          await expectLater(
            locked.repository.workout(root),
            throwsA(isA<WorkoutValidation>()),
          );
        } finally {
          await locked.close();
        }
        await requireAuthRejection(
          () => provider.refresh(beforeLogout),
          'authentication_required',
        );
        await event('remote_sign_out_pending_and_revocation_passed');

        final ownerB = await signIn('B');
        expect(ownerA == ownerB, false);
        expect(await account.local!.repository.workout(root), null);
        expect(await account.local!.repository.pendingCount(), 0);
        final bSession = (await storage.restoreSession())!;
        final bTransport = HttpSyncTransport(
          config.api,
          () async => bSession.accessToken,
        );
        try {
          final feed = await bTransport.pull(null);
          expect(
            feed.changes.any((c) => canonicalJson(c).contains(root)),
            false,
          );
          final bRepo = account.local!.repository;
          final timestamp = DateTime.now().toUtc().toIso8601String();
          final rejection = await bTransport.push(
            canonicalJson({
              'schema_version': 1,
              'operations': [
                {
                  'mutation_id': bRepo.newId(),
                  'installation_id': (await bRepo
                      .syncMetadata())['installation_id'],
                  'aggregate_type': 'workout_session',
                  'aggregate_id': root,
                  'expected_revision': 0,
                  'command': 'record_set',
                  'occurred_at': timestamp,
                  'recorded_at': timestamp,
                  'payload': attackPayload,
                },
              ],
            }),
          );
          expect(
            (rejection.results.single as Json)['error']['code'],
            'not_found',
          );
        } finally {
          bTransport.close();
        }
        await event('cross_owner_feed_and_mutation_denial_passed');
        await account.signOut();
        expect(account.state.code, null);

        expect(await signIn('A'), ownerA);
        expect(await account.local!.repository.prepareHead(root), frozen);
        account.foreground(true);
        await account.coordinator!.synchronize(force: true);
        expect(account.coordinator!.status.phase, SyncPhase.synchronized);
        expect(await account.local!.repository.pendingCount(), 0);
        final current = (await storage.restoreSession())!;
        final transport = HttpSyncTransport(
          config.api,
          () async => current.accessToken,
        );
        try {
          final manifest = await transport.bootstrap(
            account.local!.repository.newId(),
          );
          final roots = <Json>[];
          for (var i = 0; i < manifest.pageCount; i++) {
            roots.addAll(
              (await transport.page(manifest.token, i)).roots.cast<Json>(),
            );
          }
          final cloud = roots.singleWhere((r) => r['aggregate_id'] == root);
          expect(cloud['revision'], 3);
          expect(
            allSets(cloud).elementAt(1)['observation']['actual']['reps'],
            5,
          );
        } finally {
          transport.close();
        }
        await event('a_b_a_pending_recovery_and_hosted_bootstrap_passed');
      } finally {
        await account.close();
        client.close();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
