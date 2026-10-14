import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sync_server.dart';

void main() {
  for (final status in [500, 502, 503, 504, 429]) {
    test('HTTP $status with a non-JSON body remains retryable', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.statusCode = status;
        request.response.write('<html>temporary failure</html>');
        request.response.close();
      });
      final transport = HttpSyncTransport(
        Uri.parse('http://127.0.0.1:${server.port}'),
        () async => 'test-token',
        allowLoopbackHttp: true,
      );
      try {
        await expectLater(
          transport.me(),
          throwsA(
            isA<SyncFailure>().having((e) => e.retryable, 'retryable', true),
          ),
        );
      } finally {
        transport.close();
        await server.close(force: true);
      }
    });
  }
  test(
    'successful malformed body and unsupported contract fail explicitly',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var malformed = true;
      server.listen((request) {
        request.response.write(
          malformed
              ? 'not json'
              : jsonEncode({...SyncServer().identity, 'schema_version': 2}),
        );
        request.response.close();
      });
      final transport = HttpSyncTransport(
        Uri.parse('http://127.0.0.1:${server.port}'),
        () async => 'test-token',
        allowLoopbackHttp: true,
      );
      try {
        await expectLater(transport.me(), throwsA(isA<ContractViolation>()));
        malformed = false;
        await expectLater(
          transport.me(),
          throwsA(
            isA<ContractViolation>().having(
              (e) => e.code,
              'code',
              'upgrade_required',
            ),
          ),
        );
      } finally {
        transport.close();
        await server.close(force: true);
      }
    },
  );
  test('request timeout and socket disconnection remain transient', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>(); /* Deliberately never respond. */
    });
    final transport = HttpSyncTransport(
      Uri.parse('http://127.0.0.1:${server.port}'),
      () async => 'test-token',
      allowLoopbackHttp: true,
      timeout: const Duration(milliseconds: 100),
    );
    try {
      await expectLater(
        transport.me(),
        throwsA(isA<SyncFailure>().having((e) => e.code, 'code', 'timeout')),
      );
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });
  test(
    'credential switch is deferred until the next authenticated preflight',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final fake = SyncServer();
      var token = 'owner-a-token';
      final observed = <String>[];
      server.listen((request) {
        observed.add(request.headers.value('Authorization')!);
        request.response.write(
          jsonEncode(
            request.uri.path == '/v1/me'
                ? fake.identity
                : {
                    ...fake.context,
                    'changes': [],
                    'next_cursor': 'x',
                    'next_position': 0,
                    'has_more': false,
                  },
          ),
        );
        request.response.close();
      });
      final transport = HttpSyncTransport(
        Uri.parse('http://127.0.0.1:${server.port}'),
        () async => token,
        allowLoopbackHttp: true,
      );
      try {
        await transport.me();
        token = 'owner-b-token';
        await transport.pull(null);
        await transport.me();
        expect(observed, [
          'Bearer owner-a-token',
          'Bearer owner-a-token',
          'Bearer owner-b-token',
        ]);
      } finally {
        transport.close();
        await server.close(force: true);
      }
    },
  );
  test('disabled other-owner response cannot purge the local owner', () async {
    final db = TrainingDatabase(NativeDatabase.memory());
    final repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    final id = await repo.startFoundationWorkout();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = 403;
      request.response.write(
        jsonEncode({
          'detail': {
            'code': 'account_inactive',
            'schema_version': 1,
            'owner_id': '20000000-0000-4000-8000-000000000002',
          },
        }),
      );
      request.response.close();
    });
    final transport = HttpSyncTransport(
      Uri.parse('http://127.0.0.1:${server.port}'),
      () async => 'other-owner-token',
      allowLoopbackHttp: true,
    );
    final coordinator = SyncCoordinator(repo, transport);
    try {
      await coordinator.synchronize(force: true);
      expect(coordinator.status.code, 'wrong_owner');
      expect(await repo.workout(id), isNotNull);
      expect(await repo.pendingCount(), 1);
    } finally {
      await coordinator.close();
      transport.close();
      await server.close(force: true);
      repo.dispose();
      await db.close();
    }
  });
  test('credentials are never forwarded through an HTTP redirect', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = 302;
      request.response.headers.set('Location', 'https://untrusted.invalid');
      request.response.write('{}');
      request.response.close();
    });
    final transport = HttpSyncTransport(
      Uri.parse('http://127.0.0.1:${server.port}'),
      () async => 'test-token',
      allowLoopbackHttp: true,
    );
    try {
      await expectLater(
        transport.me(),
        throwsA(isA<SyncFailure>().having((e) => e.code, 'code', 'http_302')),
      );
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });
  test('sync origin enforces HTTPS outside explicit loopback development', () {
    expect(
      () => HttpSyncTransport(
        Uri.parse('http://remote.example'),
        () async => 'x',
      ),
      throwsArgumentError,
    );
    expect(
      () => HttpSyncTransport(
        Uri.parse('https://user:password@example.test'),
        () async => 'x',
      ),
      throwsArgumentError,
    );
  });
}
