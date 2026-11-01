import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner;
import 'routine_repository_test.dart' show routineId, routinePlan;
import 'support/owned_fixture.dart';
import 'support/sync_server.dart' show SyncServer;

/// Deliberately invalid wire responses, not a substitute acceptance server.
/// Successful cloud semantics use the separate real HTTP/PostgreSQL harness.
void main() {
  for (final contract in [1, 3]) {
    for (final (status, schema, authoritative) in [
      (400, 1, false),
      (401, 1, false),
      (403, 1.0, false),
      (403, 2, false),
      (403, 1, true),
    ]) {
      test(
        'HTTP account-disable authority requires exact status and schema $contract/$status/${schema.runtimeType}/$schema',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'routine-disable-wire-',
          );
          final db = TrainingDatabase.open(
            File('${directory.path}/owner.sqlite'),
          );
          final repo = WorkoutRepository(db, owner);
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final transport = HttpSyncTransport(
            Uri.parse('http://127.0.0.1:${server.port}'),
            () async => 'synthetic-wire-only',
            allowLoopbackHttp: true,
            routineSyncEnabled: contract == 3,
          );
          final sync = SyncCoordinator(repo, transport);
          try {
            await repo.initialize();
            await repo.saveRoutine(
              id: routineId,
              expectedRevision: 0,
              plan: routinePlan(),
            );
            final frozen = await repo.prepareRoutineHead(routineId);
            final workout = await repo.startFoundationWorkout();
            final workoutBytes = await repo.prepareHead(workout);
            server.listen((request) async {
              await request.drain<void>();
              request.response.statusCode = status;
              request.response.write(
                jsonEncode({
                  'detail': {
                    'code': 'account_inactive',
                    'schema_version': schema,
                    'owner_id': owner,
                  },
                }),
              );
              await request.response.close();
            });
            await sync.synchronize(force: true);
            sync.foreground(false);
            expect(await repo.remoteDisabled(), authoritative);
            if (authoritative) {
              expect(sync.status.phase, SyncPhase.accountDisabled);
              for (final table in [
                'routines',
                'routine_mutations',
                'routine_cloud_templates',
                'sessions',
                'outbox',
              ]) {
                expect(
                  await db.customSelect('SELECT * FROM $table').get(),
                  isEmpty,
                );
              }
            } else {
              expect(sync.status.phase, isNot(SyncPhase.accountDisabled));
              expect(await repo.prepareRoutineHead(routineId), frozen);
              expect(await repo.prepareHead(workout), workoutBytes);
              expect(await repo.routinePendingCount(), 1);
              expect(await repo.pendingCount(), 1);
            }
          } finally {
            await sync.close();
            transport.close();
            await server.close(force: true);
            repo.dispose();
            await db.close();
            await deleteOwnedTemporaryDirectory(
              directory,
              'routine-disable-wire-',
            );
          }
        },
      );
    }
  }
  for (final entry in {
    'old_server_404': 'routine_sync_unavailable',
    'unknown_contract': 'upgrade_required',
    'unknown_snapshot_root': 'malformed_response',
    'unexpected_snapshot_field': 'malformed_response',
    'snapshot_owner': 'wrong_owner',
    'snapshot_generation': 'snapshot_expired',
    'snapshot_epoch': 'snapshot_expired',
    'checksum': 'snapshot_checksum',
    'oversized_response': 'response_capacity',
    'oversized_page': 'snapshot_checksum',
  }.entries) {
    test(
      'actual HTTP routine capability failure ${entry.key} retains both local outboxes and cursor',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'routine-wire-',
        );
        final db = TrainingDatabase.open(
          File('${directory.path}/owner.sqlite'),
        );
        final repo = WorkoutRepository(db, owner);
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final transport = HttpSyncTransport(
          Uri.parse('http://127.0.0.1:${server.port}'),
          () async => 'synthetic-wire-only',
          allowLoopbackHttp: true,
          routineSyncEnabled: true,
        );
        final sync = SyncCoordinator(repo, transport);
        final paths = <String>[];
        try {
          await repo.initialize();
          final saved = await repo.saveRoutine(
            id: routineId,
            expectedRevision: 0,
            plan: routinePlan(),
          );
          final frozen = (await repo.prepareRoutineHead(routineId))!;
          final workout = await repo.startFoundationWorkout();
          final workoutBytes = await repo.prepareHead(workout);
          final metadata = await repo.syncMetadata();
          final identity = {
            ...SyncServer().identity,
            'schema_version': 3,
            'position': 1,
          };
          final context = {...SyncServer().context, 'schema_version': 3};
          final page = <String, dynamic>{
            'roots': [],
            'routines': [],
            'retired_ids': [],
          };
          if (entry.key == 'oversized_page') {
            page['retired_ids'] = List.filled(15000, repo.newId());
          }
          if (entry.key == 'unknown_snapshot_root') {
            page['routines'] = [
              {
                'aggregate_type': 'future_catalog',
                'aggregate_id': repo.newId(),
              },
            ];
          }
          if (entry.key == 'unexpected_snapshot_field') {
            page['future_roots'] = [];
          }
          final manifest = {
            ...context,
            'installation_id': metadata['installation_id'],
            'token': 'wire-snapshot',
            'cursor': 'wire-cursor',
            'position': 1,
            'expires_at': '2099-01-01T00:00:00Z',
            'page_count': 1,
            'checksums': [
              sha256.convert(utf8.encode(canonicalJson(page))).toString(),
            ],
          };
          if (entry.key == 'snapshot_owner') {
            manifest['owner_id'] = repo.newId();
          }
          if (entry.key == 'snapshot_generation') {
            manifest['generation'] = repo.newId();
          }
          if (entry.key == 'snapshot_epoch') manifest['erasure_epoch'] = 1;
          if (entry.key == 'checksum') {
            manifest['checksums'] = [List.filled(64, '0').join()];
          }
          Future<void> respond(HttpRequest request) async {
            try {
              paths.add(request.uri.path);
              expect(request.headers.value('x-dm-contract'), '3');
              await request.drain<void>();
              request.response.headers.contentType = ContentType.json;
              if (entry.key == 'old_server_404') {
                request.response.statusCode = 404;
                request.response.write(
                  '<html>Legacy server has no /v3 routes</html>',
                );
              } else if (request.uri.path == '/v3/me') {
                if (entry.key == 'oversized_response') {
                  request.response.write(List.filled(1048577, ' ').join());
                } else {
                  request.response.write(
                    jsonEncode({
                      ...identity,
                      if (entry.key == 'unknown_contract') 'schema_version': 99,
                    }),
                  );
                }
              } else if (request.uri.path == '/v3/sync/bootstrap') {
                request.response.write(jsonEncode(manifest));
              } else if (request.uri.path == '/v3/sync/bootstrap/pages/0') {
                request.response.write(jsonEncode(page));
              } else if (request.uri.path == '/v3/sync/bootstrap/validate') {
                request.response.write(jsonEncode(identity));
              } else {
                fail(
                  'No upload or fallback is permitted after unsupported state: ${request.uri.path}',
                );
              }
              await request.response.close();
            } on IOException {
              // The capacity control intentionally aborts its HTTP connection.
            }
          }

          server.listen((request) => unawaited(respond(request)));
          expect(
            paths,
            isEmpty,
            reason: 'Both offline saves finished without HTTP.',
          );
          await sync.synchronize(force: true);
          sync.foreground(false);
          expect(
            sync.status.phase,
            ['snapshot_generation', 'snapshot_epoch'].contains(entry.key)
                ? SyncPhase.pending
                : SyncPhase.attention,
          );
          expect(sync.status.code, entry.value);
          expect(paths.every((path) => path.startsWith('/v3/')), isTrue);
          expect(paths.any((path) => path.endsWith('/push')), isFalse);
          expect(await repo.prepareRoutineHead(routineId), frozen);
          expect(await repo.prepareHead(workout), workoutBytes);
          expect((await repo.routine(routineId))!.templateId, saved.templateId);
          expect(await repo.routinePendingCount(), 1);
          expect(await repo.pendingCount(), 1);
          expect(
            (await repo.routineSyncDetails(routineId))!['server_revision'],
            0,
          );
          final after = await repo.syncMetadata();
          expect(after['cursor'], metadata['cursor']);
          expect(after['position'], metadata['position']);
          expect(after['generation'], metadata['generation']);
        } finally {
          await sync.close();
          transport.close();
          await server.close(force: true);
          repo.dispose();
          await db.close();
          await deleteOwnedTemporaryDirectory(directory, 'routine-wire-');
        }
      },
    );
  }
}
