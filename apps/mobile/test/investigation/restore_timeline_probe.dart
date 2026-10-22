// Explicit characterization probe; intentionally outside *_test.dart discovery.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../repository_test.dart' show recordPayload;

const cases = [
  'equal_fenced',
  'lower_fenced',
  'higher_fenced',
  'equal_unfenced',
  'delayed_inflight',
  'same_generation',
  'lost_receipt',
  'retained_receipt',
  'restart_preflight',
  'owner_isolation',
  'deletion_equal_epoch',
  'deletion_regressed_epoch',
  'deletion_retained_control',
];

class CheckpointTransport extends HttpSyncTransport {
  final Future<void> Function(String) checkpoint;
  final void Function() pause;
  PushResponseDto? response;
  String? sent;
  CheckpointTransport(
    super.base,
    super.accessToken,
    this.checkpoint,
    this.pause,
  ) : super(allowLoopbackHttp: true);
  @override
  Future<SyncTransport> beginCycle() async => this;
  @override
  Future<PushResponseDto> push(String body) async {
    sent = body;
    await checkpoint(body);
    response = await super.push(body);
    pause(); // Stop the automatic next turn, not the first acceptance/ack install.
    return response!;
  }
}

void main() {
  final origin = Platform.environment['DM_TIMELINE_ENDPOINT'];
  for (final scenario in cases) {
    test(scenario, () async {
      expect(
        origin,
        isNotNull,
        reason: 'Run through the disposable Python harness',
      );
      final base = Uri.parse(origin!);
      expect(base.host, '127.0.0.1');
      final owner = Platform.environment['DM_TIMELINE_OWNER']!;
      final token = Platform.environment['DM_TIMELINE_TOKEN']!;
      final controls = HttpClient();
      Future<Json> control(String action, [Json body = const {}]) async {
        final request = await controls.postUrl(
          base.resolve('/__investigation/$action'),
        );
        request.headers.set('X-DM-Investigation', 'local-only');
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
        final response = await request.close();
        expect(
          response.statusCode,
          200,
          reason: 'Disposable control failed: $action',
        );
        return jsonDecode(await utf8.decoder.bind(response).join()) as Json;
      }

      final setup = await control('start', {'case': scenario});
      final id = setup['root'] as String;
      final directory = await Directory.systemTemp.createTemp(
        'timeline-probe-',
      );
      final file = File('${directory.path}/owner-a.sqlite');
      late TrainingDatabase database;
      late WorkoutRepository repo;
      late SyncCoordinator sync;
      final plain = HttpSyncTransport(
        base,
        () async => token,
        allowLoopbackHttp: true,
      );
      var opened = false;
      Future<void> open() async {
        database = TrainingDatabase.open(file);
        repo = WorkoutRepository(database, owner);
        await repo.initialize();
        sync = SyncCoordinator(repo, plain);
        opened = true;
      }

      Future<void> close() async {
        await sync.close();
        repo.dispose();
        await database.close();
        opened = false;
      }

      final evidence = <String, dynamic>{
        'case': scenario,
        'file_backed_sqlite': true,
      };
      try {
        await open();
        await sync.synchronize(force: true);
        expect(sync.status.phase, SyncPhase.synchronized);
        expect((await repo.workout(id))!['revision'], 2);
        final originMeta = await repo.syncMetadata();

        if (scenario.startsWith('deletion_')) {
          final deleted = await control('delete');
          await sync.synchronize(force: true);
          expect(await repo.workout(id), isNull);
          expect(
            (await repo.syncMetadata())['erasure_epoch'],
            deleted['erasure_epoch'],
          );
          await close();
          await open();
          await control('restore');
          await sync.synchronize(force: true);
          evidence['cached_deletion_epoch'] = deleted['erasure_epoch'];
          evidence['established_client_status'] = sync.status.phase.name;
          evidence['established_client_code'] = sync.status.code;
          expect(await repo.workout(id), isNull);
          final freshDb = TrainingDatabase.open(
            File('${directory.path}/fresh.sqlite'),
          );
          final fresh = WorkoutRepository(freshDb, owner);
          await fresh.initialize();
          final freshSync = SyncCoordinator(fresh, plain);
          try {
            await freshSync.synchronize(force: true);
            final present = await fresh.workout(id) != null;
            evidence['fresh_client_received_deleted_root'] = present;
            expect(present, scenario != 'deletion_retained_control');
            evidence['fresh_client_epoch'] = (await fresh
                .syncMetadata())['erasure_epoch'];
            if (scenario == 'deletion_regressed_epoch') {
              expect(sync.status.phase, SyncPhase.attention);
              expect((await repo.syncMetadata())['erasure_epoch'], 3);
              expect(evidence['fresh_client_epoch'], 1);
            }
          } finally {
            await freshSync.close();
            fresh.dispose();
            await freshDb.close();
          }
        } else {
          await repo.commit(
            id,
            'record_set',
            recordPayload((await repo.workout(id))!, index: 1, reps: 7),
          );
          final frozen = (await repo.prepareHead(id))!;
          final operation = jsonDecode(frozen) as Json;
          final mutation = operation['mutation_id'] as String;
          final batch = '{"schema_version":1,"operations":[$frozen]}';
          evidence['mutation_id'] = mutation;
          evidence['frozen_sha256'] = sha256
              .convert(utf8.encode(frozen))
              .toString();
          evidence['expected_revision'] = operation['expected_revision'];
          expect(operation['expected_revision'], 2);
          PushResponseDto? first;
          if (['lost_receipt', 'retained_receipt'].contains(scenario)) {
            final beforeRestore = await plain.push(batch);
            expect(beforeRestore.results.single['status'], 'accepted');
            expect(beforeRestore.generation, originMeta['generation']);
            evidence['discarded_timeline_outcome'] = 'accepted';
            await close();
            await open();
            expect(await repo.prepareHead(id), frozen);
            await control('restore', {'mutation_id': mutation});
            first = await plain.push(
              batch,
            ); // Explicit stale-envelope server probe.
          } else if (scenario == 'restart_preflight') {
            await close();
            await control('restore', {'mutation_id': mutation});
            await open();
            expect(await repo.prepareHead(id), frozen);
            await sync.synchronize(force: true);
            expect(sync.status.phase, SyncPhase.attention);
            expect((await control('inspect'))['root_revision'], 2);
            evidence['coordinator_preflight_prevented_upload'] = true;
          } else if (scenario == 'owner_isolation') {
            await control('restore', {'mutation_id': mutation});
            final other = HttpSyncTransport(
              base,
              () async => Platform.environment['DM_TIMELINE_TOKEN_B'],
              allowLoopbackHttp: true,
            );
            try {
              final wrongOwner = await other.push(batch);
              expect(wrongOwner.results.single['status'], 'conflict');
              expect((await control('inspect'))['root_revision'], 2);
              expect((await control('inspect'))['other_root_revision'], 1);
              evidence['wrong_owner_outcome'] = 'conflict';
              final bdb = TrainingDatabase.open(
                File('${directory.path}/owner-b.sqlite'),
              );
              final brepo = WorkoutRepository(
                bdb,
                Platform.environment['DM_TIMELINE_OWNER_B']!,
              );
              await brepo.initialize();
              final bsync = SyncCoordinator(brepo, other);
              try {
                await bsync.synchronize(force: true);
                expect(await brepo.workout(id), isNull);
                final bid = setup['other_root'] as String;
                await brepo.commit(
                  bid,
                  'record_set',
                  recordPayload((await brepo.workout(bid))!),
                );
                await bsync.synchronize(force: true);
                expect(bsync.status.phase, SyncPhase.synchronized);
                expect((await control('inspect'))['root_revision'], 2);
                expect((await control('inspect'))['other_root_revision'], 2);
                evidence['fresh_same_generation_owner_b_upload'] = 'accepted';
              } finally {
                await bsync.close();
                brepo.dispose();
                await bdb.close();
              }
            } finally {
              other.close();
            }
          } else {
            await sync.close();
            late CheckpointTransport checkpoint;
            checkpoint = CheckpointTransport(base, () async => token, (
              _,
            ) async {
              if (scenario == 'same_generation') return;
              if (scenario == 'delayed_inflight') {
                // The server-side gate, not a simulated API response, holds the request.
                return;
              }
              await control('restore', {'mutation_id': mutation});
            }, () => sync.foreground(false));
            sync = SyncCoordinator(repo, checkpoint);
            try {
              if (scenario == 'delayed_inflight') {
                final running = sync.synchronize(force: true);
                // /restore waits until the complete HTTP push has arrived at its gate.
                await control('restore', {'mutation_id': mutation});
                await running;
              } else {
                await sync.synchronize(force: true);
              }
              first = checkpoint.response;
              expect(checkpoint.sent, batch);
              evidence['coordinator_code'] = sync.status.code;
            } finally {
              checkpoint.close();
            }
          }
          if (first != null) {
            final expected =
                ['lower_fenced', 'higher_fenced'].contains(scenario)
                ? 'conflict'
                : scenario == 'retained_receipt'
                ? 'duplicate'
                : 'accepted';
            expect(first.results.single['status'], expected);
            evidence['first_outcome'] = first.results.single;
            evidence['response_generation_changed'] =
                first.generation != originMeta['generation'];
            expect(
              evidence['response_generation_changed'],
              !['same_generation', 'equal_unfenced'].contains(scenario),
            );
            final beforeRepeat = await control('inspect', {
              'mutation_id': mutation,
            });
            expect(
              (beforeRepeat['mutation_receipt'] as Json)['mutation_id'],
              mutation,
            );
            final revision = scenario == 'lower_fenced' ? 1 : 3;
            expect(beforeRepeat['root_revision'], revision);
            final reps = scenario == 'lower_fenced'
                ? [null, null, null]
                : scenario == 'higher_fenced'
                ? [9, null, 5]
                : ['same_generation', 'retained_receipt'].contains(scenario)
                ? [5, 7, null]
                : [9, 7, null];
            expect(beforeRepeat['observed_reps'], reps);
            evidence['server_before_repeat'] = beforeRepeat;
            final repeated = await plain.push(batch);
            expect(
              repeated.results.single['status'],
              expected == 'conflict' ? 'conflict' : 'duplicate',
            );
            final afterRepeat = await control('inspect', {
              'mutation_id': mutation,
            });
            expect(afterRepeat, beforeRepeat);
            evidence['repeat_outcome'] = repeated.results.single;
            evidence['repeat_added_no_database_effect'] = true;
            if ([
              'equal_fenced',
              'lower_fenced',
              'higher_fenced',
              'delayed_inflight',
            ].contains(scenario)) {
              expect(sync.status.code, 'bootstrap_required');
              expect(
                (await repo.syncMetadata())['generation'],
                originMeta['generation'],
              );
              expect(await repo.prepareHead(id), frozen);
            }
          }
          final row = await database
              .customSelect('SELECT frozen_body,state FROM outbox')
              .getSingle();
          expect(row.read<String>('frozen_body'), frozen);
          evidence['local_outbox_state'] = row.read<String>('state');
          evidence['frozen_body_unchanged'] = true;
          evidence['local_first_set_reps'] = allSets((await repo.workout(id))!)
              .first['observation']['actual']['reps'];
          expect(evidence['local_first_set_reps'], 5);
        }
        expect(
          (await database.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await control('finish', evidence);
      } finally {
        if (opened) await close();
        plain.close();
        controls.close(force: true);
        final parent = await Directory.systemTemp.resolveSymbolicLinks();
        final target = await directory.resolveSymbolicLinks();
        expect(path.isWithin(parent, target), true);
        expect(path.basename(target).startsWith('timeline-probe-'), true);
        await Directory(target).delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
