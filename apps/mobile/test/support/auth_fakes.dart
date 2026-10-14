import 'dart:convert';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/supabase_provider.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_server.dart';

const ownerB = '20000000-0000-4000-8000-000000000002';
Session testSession(
  String owner,
  DateTime now, {
  int lifetime = 3600,
  String refresh = 'synthetic-refresh',
  String? token,
}) {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final access =
      token ??
      '${encode({'alg': 'ES256'})}.${encode({'sub': owner, 'exp': now.millisecondsSinceEpoch ~/ 1000 + lifetime})}.synthetic';
  return Session(
    accessToken: access,
    refreshToken: refresh,
    tokenType: 'bearer',
    user: User(
      id: owner,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-13T00:00:00Z',
      emailConfirmedAt: '2026-10-13T00:00:00Z',
      email: 'synthetic@example.test',
    ),
  );
}

class MemoryProtectedStorage implements ProtectedStorage {
  final values = <String, String>{};
  bool failWrite = false;
  Future<void> Function(String key, String value)? beforeWrite;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key, value);
    if (failWrite) throw const AuthFailure('secure_storage_unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeOtpProvider implements OtpProvider {
  Session session;
  AuthFailure? requestFailure;
  AuthFailure? verifyFailure;
  AuthFailure? refreshFailure;
  Future<Session> Function()? verification;
  Future<void> Function()? requestOperation;
  Future<Session> Function()? refreshOperation;
  int requests = 0;
  int refreshes = 0;
  int signOuts = 0;
  FakeOtpProvider(this.session);
  @override
  Future<void> request(String email) async {
    requests++;
    if (requestFailure case final error?) throw error;
    await requestOperation?.call();
  }

  @override
  Future<Session> verify(String email, String code) async {
    if (verifyFailure case final error?) throw error;
    return verification == null ? session : await verification!();
  }

  @override
  Future<Session> refresh(Session current) async {
    refreshes++;
    if (refreshFailure case final error?) throw error;
    return refreshOperation == null ? session : await refreshOperation!();
  }

  @override
  Future<void> signOut(Session? session) async {
    signOuts++;
  }
}

class FakeAccountGateway implements AccountGateway {
  final Map<String, SyncServer> servers;
  Object? failure;
  int calls = 0;
  FakeAccountGateway(this.servers);
  @override
  Future<AccountResponseDto> initialize(Session session) async {
    calls++;
    if (failure case final error?) {
      failure = null;
      throw error;
    }
    return AccountResponseDto.fromJson({
      ...servers[session.user.id]!.identity,
      'profile': {'unit': 'kg'},
    });
  }
}
