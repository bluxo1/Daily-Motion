import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/supabase_provider.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fakes.dart' show MemoryProtectedStorage;
import 'support/auth_rejection.dart';

/// An actual elapsed-time provider qualification, enabled only by an operator.
/// The loopback bridge holds delivered codes in memory and exposes safe events.
void main() {
  test(
    'hosted delivered OTP expires and a fresh code succeeds',
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
      Future<Json> call(String method, String path, [Json? data]) async {
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

      Future<void> event(String name, [Json? details]) async {
        await call('POST', '/event', {'event': name, ...?details});
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
      final settings = await call('GET', '/settings');
      final expiry = settings['otp_expiry_seconds'];
      if (expiry is! int || expiry < 60 || expiry > 3600) {
        throw StateError('A verified provider OTP lifetime is required');
      }
      final address = (await call('GET', '/account/A'))['email'] as String;
      Future<String> deliveredCode() async {
        final requested = DateTime.now().toUtc();
        await provider.request(address);
        final challenge = await call('POST', '/challenge', {
          'account': 'A',
          'requested_at': requested.toIso8601String(),
        });
        final deadline = DateTime.now().add(const Duration(minutes: 3));
        while (DateTime.now().isBefore(deadline)) {
          final code = (await call('GET', '/code/${challenge['id']}'))['code'];
          if (code is String && RegExp(r'^\d{6}$').hasMatch(code)) {
            return code;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        throw StateError('Recipient delivery timed out');
      }

      try {
        final expiredCode = await deliveredCode();
        final elapsed = Stopwatch()..start();
        await event('expiry_wait_started', {'configured_seconds': expiry});
        // Start after delivery, so even slow SMTP cannot shorten the lifetime.
        await Future<void>.delayed(Duration(seconds: expiry + 10));
        expect(elapsed.elapsed.inSeconds >= expiry + 10, true);
        await requireAuthRejection(
          () => provider.verify(address, expiredCode),
          'invalid_or_expired_code',
        );
        expect(await storage.restoreSession() == null, true);
        await event('elapsed_otp_expiry_rejected', {
          'elapsed_seconds': elapsed.elapsed.inSeconds,
        });
        final session = await provider.verify(address, await deliveredCode());
        expect(session.user.emailConfirmedAt != null, true);
        await event('fresh_delivered_code_verified_after_expiry');
        await provider.signOut(session);
        await event('qualification_session_signed_out');
      } finally {
        client.close();
      }
    },
    skip: Platform.environment['DM_HOSTED_OTP_EXPIRY'] != '1',
    timeout: const Timeout(Duration(minutes: 68)),
  );
}
