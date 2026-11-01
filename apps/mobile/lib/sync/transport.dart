import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/workout.dart';
import 'contract_validation.dart';
import 'transport_contract.dart';
import 'transport_limits.dart';

class SyncFailure implements Exception {
  final String code;
  final bool retryable;
  final String? ownerId;
  const SyncFailure(this.code, {this.retryable = false, this.ownerId});
  @override
  String toString() => code;
}

abstract interface class SyncTransport {
  Future<SyncTransport> beginCycle();
  Future<MeResponseDto> me();
  Future<PushResponseDto> push(String frozenBatch);
  Future<PullResponseDto> pull(String? cursor);
  Future<BootstrapManifestDto> bootstrap(String installation);
  Future<SnapshotPageDto> page(String token, int index);
  Future<MeResponseDto> validateSnapshot(String token);
}

abstract interface class RoutineSyncTransport {
  bool get routineSyncEnabled;
  Future<MeResponse3Dto> routineMe();
  Future<PushResponse3Dto> pushRoutines(String frozenBatch);
  Future<PullResponse3Dto> pullRoutines(String? cursor);
  Future<BootstrapManifest3Dto> bootstrapRoutines(String installation);
  Future<SnapshotPage3Dto> routinePage(String token, int index);
  Future<MeResponse3Dto> validateRoutineSnapshot(String token);
}

class HttpSyncTransport implements SyncTransport, RoutineSyncTransport {
  final Uri base;
  final Future<String?> Function() accessToken;
  final Duration timeout;
  final HttpClient client;
  final bool allowLoopbackHttp;
  @override
  final bool routineSyncEnabled;
  String? _cycleToken;
  HttpSyncTransport(
    this.base,
    this.accessToken, {
    this.timeout = const Duration(seconds: 15),
    HttpClient? client,
    this.allowLoopbackHttp = false,
    this.routineSyncEnabled = false,
  }) : client = client ?? HttpClient() {
    if (base.scheme != 'https' &&
        !(allowLoopbackHttp &&
            base.scheme == 'http' &&
            [
              '127.0.0.1',
              'localhost',
              '10.0.2.2',
              '::1',
            ].contains(base.host))) {
      throw ArgumentError(
        'Sync requires HTTPS; only an explicit local development connection may use HTTP.',
      );
    }
    if (base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw ArgumentError(
        'Use an API origin without credentials or query parameters.',
      );
    }
    this.client.connectionTimeout = timeout;
  }

  @override
  Future<SyncTransport> beginCycle() async {
    final token = await accessToken();
    return HttpSyncTransport(
      base,
      () async => token,
      timeout: timeout,
      client: client,
      allowLoopbackHttp: allowLoopbackHttp,
      routineSyncEnabled: routineSyncEnabled,
    );
  }

  Future<Json> _request(
    String method,
    String path, {
    Json? query,
    String? body,
    int contract = 1,
  }) async {
    HttpClientRequest? request;
    var expired = false;
    Future<Json> send() async {
      final token = _cycleToken ?? await accessToken();
      if (token == null || token.isEmpty) {
        throw const SyncFailure('authentication_required');
      }
      final uri = base
          .resolve(path)
          .replace(
            queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
          );
      request = await client.openUrl(method, uri);
      if (expired) {
        request!.abort();
        throw const SyncFailure('timeout', retryable: true);
      }
      request!.followRedirects = false;
      request!.headers.set('Authorization', 'Bearer $token');
      request!.headers.set('X-DM-Contract', '$contract');
      request!.headers.contentType = ContentType.json;
      if (body != null) {
        final bytes = utf8.encode(body);
        if (bytes.length > transportBatchLimit) {
          throw const SyncFailure('batch_capacity');
        }
        request!.add(bytes);
      }
      final response = await request!.close();
      if (contract == 3 && response.statusCode == 404) {
        await response.drain<void>();
        throw const SyncFailure('routine_sync_unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > transportBatchLimit) {
          request!.abort();
          throw const ContractViolation('response_capacity');
        }
        bytes.addAll(chunk);
      }
      Json decoded;
      // Reverse proxies can return HTML/empty transient errors. Status still
      // determines retryability; malformed successful responses remain terminal.
      final transient =
          response.statusCode >= 500 || response.statusCode == 429;
      try {
        decoded = jsonDecode(utf8.decode(bytes)) as Json;
      } catch (_) {
        if (transient) {
          throw SyncFailure('http_${response.statusCode}', retryable: true);
        }
        if (response.statusCode == 401) {
          throw const SyncFailure('authentication_required');
        }
        if (response.statusCode == 426) {
          throw const SyncFailure('upgrade_required');
        }
        if (response.statusCode != 200) {
          throw SyncFailure('http_${response.statusCode}');
        }
        throw const ContractViolation();
      }
      if (response.statusCode != 200) {
        final detail = decoded['detail'];
        var code = detail is Json && detail['code'] is String
            ? detail['code'] as String
            : 'http_${response.statusCode}';
        // Only defined status/code pairs carry recovery meaning. A proxy error
        // must never impersonate a bound account lifecycle denial.
        final recoveryPause =
            response.statusCode == 503 &&
                [
                  'recovery_unavailable',
                  'recovery_metadata_unverified',
                ].contains(code) ||
            response.statusCode == 202 && code == 'publication_pending';
        if (transient && !recoveryPause) {
          code = 'http_${response.statusCode}';
        }
        final boundLifecycleDenial =
            response.statusCode == 403 &&
            detail is Json &&
            detail['schema_version'] is int &&
            detail['schema_version'] == 1;
        if (code == 'account_inactive' && !boundLifecycleDenial) {
          // This code purges owner-private SQLite content. A malformed error
          // or an unrelated HTTP status cannot authorize that transition.
          code = response.statusCode == 401
              ? 'authentication_required'
              : 'http_${response.statusCode}';
        }
        throw SyncFailure(
          code,
          retryable: transient || recoveryPause,
          ownerId: boundLifecycleDenial && detail['owner_id'] is String
              ? detail['owner_id'] as String
              : null,
        );
      }
      if (decoded['schema_version'] != null &&
          decoded['schema_version'] != contract) {
        throw const ContractViolation('upgrade_required');
      }
      return decoded;
    }

    try {
      return await send().timeout(
        timeout,
        onTimeout: () {
          expired = true;
          request?.abort();
          throw const SyncFailure('timeout', retryable: true);
        },
      );
    } on SocketException {
      throw const SyncFailure('offline', retryable: true);
    } on HttpException {
      throw const SyncFailure('connection_dropped', retryable: true);
    } on HandshakeException {
      throw const SyncFailure('tls_failure');
    }
  }

  @override
  Future<MeResponseDto> me() async {
    // Freeze this credential across preflight, upload, pull and bootstrap. A token
    // provider/account switch is observed only at the next authenticated preflight.
    _cycleToken = await accessToken();
    return MeResponseDto.fromJson(await _request('GET', '/v1/me'));
  }

  Future<AccountResponseDto> initializeAccount() async =>
      AccountResponseDto.fromJson(
        await _request('POST', '/v1/account/initialize', body: '{}'),
      );

  @override
  Future<PushResponseDto> push(String frozenBatch) async =>
      PushResponseDto.fromJson(
        await _request('POST', '/v1/sync/push', body: frozenBatch),
      );
  @override
  Future<PullResponseDto> pull(String? cursor) async =>
      PullResponseDto.fromJson(
        await _request('GET', '/v1/sync/pull', query: {'cursor': ?cursor}),
      );
  @override
  Future<BootstrapManifestDto> bootstrap(String installation) async =>
      BootstrapManifestDto.fromJson(
        await _request(
          'POST',
          '/v1/sync/bootstrap',
          body: canonicalJson({'installation_id': installation}),
        ),
      );
  @override
  Future<SnapshotPageDto> page(String token, int index) async =>
      SnapshotPageDto.fromJson(
        await _request(
          'GET',
          '/v1/sync/bootstrap/pages/$index',
          query: {'token': token},
        ),
      );
  @override
  Future<MeResponseDto> validateSnapshot(String token) async =>
      MeResponseDto.fromJson(
        await _request(
          'GET',
          '/v1/sync/bootstrap/validate',
          query: {'token': token},
        ),
      );

  void _routineCapability() {
    if (!routineSyncEnabled) {
      throw const SyncFailure('routine_sync_unavailable');
    }
  }

  @override
  Future<MeResponse3Dto> routineMe() async {
    _routineCapability();
    _cycleToken = await accessToken();
    return MeResponse3Dto.fromJson(
      await _request('GET', '/v3/me', contract: 3),
    );
  }

  @override
  Future<PushResponse3Dto> pushRoutines(String frozenBatch) async {
    _routineCapability();
    validateTransport('PushRequest3', jsonDecode(frozenBatch) as Json);
    return PushResponse3Dto.fromJson(
      await _request('POST', '/v3/sync/push', body: frozenBatch, contract: 3),
    );
  }

  @override
  Future<PullResponse3Dto> pullRoutines(String? cursor) async {
    _routineCapability();
    return PullResponse3Dto.fromJson(
      await _request(
        'GET',
        '/v3/sync/pull',
        query: {'cursor': ?cursor},
        contract: 3,
      ),
    );
  }

  @override
  Future<BootstrapManifest3Dto> bootstrapRoutines(String installation) async {
    _routineCapability();
    return BootstrapManifest3Dto.fromJson(
      await _request(
        'POST',
        '/v3/sync/bootstrap',
        body: canonicalJson({'installation_id': installation}),
        contract: 3,
      ),
    );
  }

  @override
  Future<SnapshotPage3Dto> routinePage(String token, int index) async {
    _routineCapability();
    return SnapshotPage3Dto.fromJson(
      await _request(
        'GET',
        '/v3/sync/bootstrap/pages/$index',
        query: {'token': token},
        contract: 3,
      ),
    );
  }

  @override
  Future<MeResponse3Dto> validateRoutineSnapshot(String token) async {
    _routineCapability();
    return MeResponse3Dto.fromJson(
      await _request(
        'GET',
        '/v3/sync/bootstrap/validate',
        query: {'token': token},
        contract: 3,
      ),
    );
  }

  void close() => client.close(force: true);
}
