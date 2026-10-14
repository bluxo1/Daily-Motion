import 'dart:convert';

import 'package:crypto/crypto.dart';

class AuthFailure implements Exception {
  final String code;
  final bool retryable;
  const AuthFailure(this.code, {this.retryable = false});
  @override
  String toString() => code; // Never forward SDK/provider exception bodies.
}

class AuthConfiguration {
  final Uri supabase;
  final Uri api;
  final String publishableKey;
  final String environment;
  final bool development;
  AuthConfiguration({
    required String supabaseUrl,
    required String apiUrl,
    required this.publishableKey,
    this.environment = 'production',
    bool release = true,
    bool syntheticFixture = false,
    String syntheticToken = '',
  }) : supabase = Uri.parse(supabaseUrl),
       api = Uri.parse(apiUrl),
       development = !release && environment == 'development' {
    if (!['development', 'staging', 'production'].contains(environment) ||
        release &&
            (environment == 'development' ||
                syntheticFixture ||
                syntheticToken.isNotEmpty) ||
        !publishableKey.startsWith('sb_publishable_')) {
      throw const AuthFailure('authentication_configuration');
    }
    for (final uri in [supabase, api]) {
      if (uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.path.isNotEmpty && uri.path != '/' ||
          uri.scheme != 'https' &&
              !(development &&
                  uri.scheme == 'http' &&
                  ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host))) {
        throw const AuthFailure('authentication_configuration');
      }
    }
  }
  String get namespace =>
      sha256.convert(utf8.encode('${supabase.origin}|$environment')).toString();
}
