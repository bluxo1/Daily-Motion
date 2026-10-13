import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuration.dart';
import 'secure_storage.dart';
import 'auth_http.dart';

abstract interface class OtpProvider {
  Future<void> request(String email);
  Future<Session> verify(String email, String code);
  Future<Session> refresh(Session session);
  Future<void> signOut(Session? session);
}

/// The supported Flutter SDK's SupabaseClient/Auth API. Each bounded operation
/// owns a client, so late SDK state cannot mutate another account's client.
/// Automatic refresh and URI login are replaced by explicit foreground scheduling;
/// secure LocalStorage writes are awaited by AccountController.
class SupabaseOtpProvider implements OtpProvider {
  final SupabaseClient Function() clientFactory;
  final void Function(SupabaseClient)? _closeHttp;
  factory SupabaseOtpProvider(
    AuthConfiguration configuration,
    SecureSessionStorage storage,
  ) {
    final owned = <SupabaseClient, AuthHttpClient>{};
    return SupabaseOtpProvider._(() {
      final http = AuthHttpClient(configuration.supabase);
      final client = SupabaseClient(
        configuration.supabase.toString(),
        configuration.publishableKey,
        httpClient: http,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: SecureGotrueStorage(
            storage.storage,
            storage.namespace,
          ),
        ),
      );
      owned[client] = http;
      return client;
    }, (client) => owned.remove(client)?.close());
  }
  SupabaseOtpProvider._(this.clientFactory, this._closeHttp) {
    silenceAuthenticationLogs();
  }
  SupabaseOtpProvider.withFactory(this.clientFactory) : _closeHttp = null {
    silenceAuthenticationLogs();
  }
  static void silenceAuthenticationLogs() {
    hierarchicalLoggingEnabled = true;
    Logger('supabase').level = Level.OFF;
  }

  Future<T> _operation<T>(
    Future<T> Function(SupabaseClient) action,
    String fallback,
  ) async {
    final client = clientFactory();
    try {
      return await action(client).timeout(const Duration(seconds: 15));
    } on AuthException catch (error) {
      if (error is AuthRetryableFetchException) {
        throw const AuthFailure('provider_unavailable', retryable: true);
      }
      if (error.statusCode == '429') throw const AuthFailure('throttled');
      if ((int.tryParse(error.statusCode ?? '') ?? 0) >= 500) {
        throw const AuthFailure('provider_unavailable', retryable: true);
      }
      final code = error.code;
      if (['otp_expired', 'otp_disabled'].contains(code)) {
        throw const AuthFailure('invalid_or_expired_code');
      }
      if (fallback == 'verification_failed') {
        throw const AuthFailure('invalid_or_expired_code');
      }
      throw AuthFailure(fallback);
    } on TimeoutException {
      throw const AuthFailure('network_unavailable', retryable: true);
    } on SocketException {
      throw const AuthFailure('network_unavailable', retryable: true);
    } on http.ClientException {
      throw const AuthFailure('network_unavailable', retryable: true);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw AuthFailure(fallback);
    } finally {
      try {
        await client.dispose();
      } finally {
        _closeHttp?.call(client);
      }
    }
  }

  @override
  Future<void> request(String email) => _operation(
    (c) => c.auth.signInWithOtp(email: email, shouldCreateUser: true),
    'otp_request_failed',
  );
  @override
  Future<Session> verify(String email, String code) => _operation((c) async {
    final response = await c.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
    final session = response.session;
    if (session == null || session.user.emailConfirmedAt == null) {
      throw const AuthFailure('verification_failed');
    }
    return session;
  }, 'verification_failed');
  @override
  Future<Session> refresh(Session session) => _operation((c) async {
    final response = await c.auth.refreshSession(session.refreshToken);
    if (response.session == null ||
        response.session!.user.id != session.user.id) {
      throw const AuthFailure('authentication_required');
    }
    return response.session!;
  }, 'authentication_required');
  @override
  Future<void> signOut(Session? session) => _operation((c) async {
    if (session != null) {
      await c.auth.setInitialSession(jsonEncode(session.toJson()));
      await c.auth.signOut(scope: SignOutScope.local);
    }
  }, 'remote_sign_out_unavailable');
}
