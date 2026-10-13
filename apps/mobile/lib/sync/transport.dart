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

class HttpSyncTransport implements SyncTransport {
  final Uri base;
  final Future<String?> Function() accessToken;
  final Duration timeout;
  final HttpClient client;
  final bool allowLoopbackHttp;
  String? _cycleToken;
  HttpSyncTransport(
    this.base,
    this.accessToken, {
    this.timeout = const Duration(seconds: 15),
    HttpClient? client,
    this.allowLoopbackHttp = false,
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
    );
  }

  Future<Json> _request(
    String method,
    String path, {
    Json? query,
    String? body,
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
      request!.headers.set('X-DM-Contract', '1');
      request!.headers.contentType = ContentType.json;
      if (body != null) {
        final bytes = utf8.encode(body);
        if (bytes.length > transportBatchLimit) {
          throw const SyncFailure('batch_capacity');
        }
        request!.add(bytes);
      }
      final response = await request!.close();
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
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw SyncFailure('http_${response.statusCode}', retryable: true);
      }
      try {
        decoded = jsonDecode(utf8.decode(bytes)) as Json;
      } catch (_) {
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
        final code = detail is Json && detail['code'] is String
            ? detail['code'] as String
            : 'http_${response.statusCode}';
        throw SyncFailure(
          code,
          retryable: response.statusCode >= 500 || response.statusCode == 429,
          ownerId:
              detail is Json &&
                  detail['schema_version'] == 1 &&
                  detail['owner_id'] is String
              ? detail['owner_id'] as String
              : null,
        );
      }
      if (decoded['schema_version'] != null && decoded['schema_version'] != 1) {
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
  void close() => client.close(force: true);
}
