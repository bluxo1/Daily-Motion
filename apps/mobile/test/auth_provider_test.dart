import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/auth_http.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/supabase_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/auth_fakes.dart';
import 'support/sync_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int status;
  late Object response;
  late List<http.Request> requests;
  late SupabaseOtpProvider provider;
  late Session session;
  setUp(() {
    status = 200;
    response = {};
    requests = [];
    session = testSession(testOwner, DateTime.now().toUtc());
    provider = SupabaseOtpProvider.withFactory(
      () => SupabaseClient(
        'https://identity.supabase.test',
        'sb_publishable_synthetic',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: SecureGotrueStorage(
            MemoryProtectedStorage(),
            'sdk-test',
          ),
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(response),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });
  test(
    'supported SDK sends email OTP in POST body, without code/token URL',
    () async {
      await provider.request('synthetic@example.test');
      expect(requests.single.url.path, '/auth/v1/otp');
      expect(requests.single.method, 'POST');
      expect(
        jsonDecode(requests.single.body)['email'],
        'synthetic@example.test',
      );
      expect(requests.single.url.query, isEmpty);
    },
  );
  for (final scenario in [
    ('request_failed', 400, 'otp_request_failed'),
    ('throttled', 429, 'throttled'),
    ('provider_down', 503, 'provider_unavailable'),
  ]) {
    test('SDK request ${scenario.$1} produces safe actionable code', () async {
      status = scenario.$2;
      response = {
        'code': scenario.$1,
        'msg': 'synthetic provider secret must not escape',
      };
      await expectLater(
        provider.request('synthetic@example.test'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', scenario.$3)),
      );
    });
  }
  test('SDK email verification returns a session; explicit secure adapter restores refresh material', () async {
    response = session.toJson();
    final verified = await provider.verify('synthetic@example.test', '123456');
    expect(verified.user.id, testOwner);
    expect(requests.single.url.path, '/auth/v1/verify');
    expect(jsonDecode(requests.single.body)['type'], 'email');
    expect(requests.single.url.query, isEmpty);
    final secure = MemoryProtectedStorage();
    final store = SecureSessionStorage(secure, 'project');
    await store.saveSession(verified);
    final reopened = SecureSessionStorage(secure, 'project');
    expect(
      (await reopened.restoreSession())!.refreshToken == session.refreshToken,
      true,
    );
    await reopened.removePersistedSession();
    expect(await reopened.restoreSession(), null);
  });
  for (final code in ['otp_expired', 'invalid_credentials']) {
    test('SDK rejects $code without exposing provider messages', () async {
      status = 403;
      response = {'code': code, 'msg': '123456 synthetic-refresh'};
      await expectLater(
        provider.verify('synthetic@example.test', '123456'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.toString(),
            'safe error',
            'invalid_or_expired_code',
          ),
        ),
      );
    });
  }
  test('SDK verification network failure remains transient', () async {
    provider = SupabaseOtpProvider.withFactory(
      () => SupabaseClient(
        'https://identity.supabase.test',
        'sb_publishable_synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (_) async => throw const SocketException('synthetic offline'),
        ),
      ),
    );
    await expectLater(
      provider.verify('synthetic@example.test', '123456'),
      throwsA(isA<AuthFailure>().having((e) => e.retryable, 'retryable', true)),
    );
  });
  test(
    'SDK refresh uses refresh grant and supports rotation after restart',
    () async {
      response = testSession(
        testOwner,
        DateTime.now().toUtc(),
        refresh: 'rotated-refresh',
      ).toJson();
      final refreshed = await provider.refresh(session);
      expect(refreshed.refreshToken == 'rotated-refresh', true);
      expect(requests.single.url.path, '/auth/v1/token');
      expect(
        requests.single.url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(
        requests.single.url.toString().contains(session.refreshToken!),
        false,
      );
    },
  );
  test(
    'SDK sign-out uses server logout while persistence removal is explicit',
    () async {
      await provider.signOut(session);
      expect(requests.single.url.path, '/auth/v1/logout');
      expect(requests.single.url.queryParameters['scope'], 'local');
    },
  );
  test(
    'SDK logging is disabled even when provider errors echo sensitive inputs',
    () async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      status = 403;
      response = {
        'msg': '123456 synthetic-refresh Authorization: Bearer secret',
      };
      try {
        await provider.verify('synthetic@example.test', '123456');
      } on AuthFailure {
        /* Safe failure is expected. */
      }
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(
        records.where((r) => r.loggerName.startsWith('supabase')),
        isEmpty,
      );
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      'secure adapter invokes native protected storage on $platform',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final saved = <String, String>{};
        final options = <Map<String, dynamic>>[];
        const channel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = call.arguments as Map<Object?, Object?>;
              options.add(Map<String, dynamic>.from(args['options'] as Map));
              final key = args['key'] as String;
              if (call.method == 'write') saved[key] = args['value'] as String;
              if (call.method == 'delete') saved.remove(key);
              return call.method == 'read' ? saved[key] : null;
            });
        try {
          final storage = SecureSessionStorage(
            PlatformProtectedStorage(),
            'platform',
          );
          await storage.saveSession(session);
          expect((await storage.restoreSession())!.user.id, testOwner);
          if (platform == TargetPlatform.iOS) {
            expect(options.first['accessibility'], 'unlocked_this_device');
            expect(options.first['synchronizable'], 'false');
          } else {
            expect(options.first['storageCipherAlgorithm'], contains('GCM'));
          }
          await storage.removePersistedSession();
          expect(saved, isEmpty);
        } finally {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
  test('auth HTTP rejects redirects, wrong origins and oversized responses before exposing credentials', () async {
    final origin = Uri.parse('https://identity.supabase.test');
    var redirects = true;
    var observed = 0;
    final client = AuthHttpClient(
      origin,
      client: MockClient((request) async {
        observed++;
        expect(request.followRedirects, false);
        return redirects
            ? http.Response(
                '',
                307,
                headers: {'location': 'https://other.example.test'},
              )
            : http.Response('x' * 65537, 200);
      }),
    );
    try {
      await expectLater(
        client.post(origin.resolve('/auth/v1/verify')),
        throwsA(isA<AuthFailure>()),
      );
      expect(observed, 1);
      await expectLater(
        client.post(Uri.parse('https://other.example.test/auth/v1/verify')),
        throwsA(isA<AuthFailure>()),
      );
      expect(observed, 1);
      redirects = false;
      await expectLater(
        client.get(origin.resolve('/auth/v1/user')),
        throwsA(isA<AuthFailure>()),
      );
    } finally {
      client.close();
    }
  });
}
