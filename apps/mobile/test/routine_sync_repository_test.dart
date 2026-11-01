import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner, fixture;
import 'routine_repository_test.dart' show routineId, routinePlan;
import 'support/owned_fixture.dart';
import 'support/sync_server.dart' show SyncServer, testGeneration;

/// Real file/transaction controls. Transport/server acceptance is independently
/// exercised by routine_connected_http_test.dart; these inject exact persisted
/// response and SQLite failure boundaries without replacing the repository.
void main() {
  late Directory directory;
  late File file;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  final identity = {...SyncServer().identity, 'schema_version': 3};
  final context = {...SyncServer().context, 'schema_version': 3};
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routine-delivery-');
    file = File('${directory.path}/owner.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
    await db.customStatement('UPDATE sync_metadata SET generation=?', [
      testGeneration,
    ]);
  });
  tearDown(() async {
    repo.dispose();
    await db.close();
    final check = TrainingDatabase.open(file);
    expect(
      (await check.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(await check.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await check.close();
    await deleteOwnedTemporaryDirectory(directory, 'routine-delivery-');
  });
  Future<void> reopen() async {
    repo.dispose();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  }

  Json operation({
    String? id,
    String? template,
    int base = 0,
    String? predecessor,
  }) => {
    'mutation_id': repo.newId(),
    'installation_id': repo.newId(),
    'aggregate_type': 'routine',
    'aggregate_id': id ?? routineId,
    'expected_revision': base,
    'command': base == 0 ? 'create_routine' : 'publish_template',
    'occurred_at': '2026-10-29T00:00:00Z',
    'recorded_at': '2026-10-29T00:00:00Z',
    'payload': {
      'template_id': template ?? repo.newId(),
      'predecessor_template_id': predecessor,
      'prescription': routinePlan().json,
    },
  };
  Json root(Json op) => {
    'aggregate_type': 'routine',
    'aggregate_id': op['aggregate_id'],
    'revision': 1,
    'current_template_id': op['payload']['template_id'],
    'template_offset': 0,
    'templates': [
      {...op['payload'], 'revision': 1},
    ],
  };
  Json page(List<Json> changes, {int? position, String? cursor}) => {
    ...context,
    'changes': changes,
    'next_cursor': cursor ?? 'cursor-${position ?? changes.length}',
    'next_position': position ?? changes.length,
    'has_more': false,
  };
  Future<void> pull(Json value, {String? cursor}) async =>
      repo.installRoutinePull(
        PullResponse3Dto.fromJson(value),
        requestedCursor: cursor,
      );
  Future<Json> saved() async {
    await repo.saveRoutine(
      id: routineId,
      expectedRevision: 0,
      plan: routinePlan(),
    );
    return jsonDecode((await repo.prepareRoutineHead(routineId))!) as Json;
  }

  Future<void> acknowledge(Json op) => repo.installRoutineAcknowledgements(
    PushResponse3Dto.fromJson({
      ...context,
      'results': [
        {
          'mutation_id': op['mutation_id'],
          'aggregate_id': op['aggregate_id'],
          'status': 'accepted',
          'accepted_revision': op['expected_revision'] + 1,
          'accepted_at': '2026-10-29T00:00:01Z',
        },
      ],
    }),
    [op['mutation_id'] as String],
  );
  Future<BootstrapManifest3Dto> stage(
    List<Json> pages, {
    int position = 1,
    bool download = true,
    String generation = testGeneration,
  }) async {
    final manifest = BootstrapManifest3Dto.fromJson({
      ...context,
      'generation': generation,
      'installation_id': (await repo.syncMetadata())['installation_id'],
      'token': 'test-snapshot',
      'position': position,
      'cursor': 'snapshot-$position',
      'expires_at': '2099-01-01T00:00:00Z',
      'page_count': pages.length,
      'checksums': [
        for (final p in pages)
          sha256.convert(utf8.encode(canonicalJson(p))).toString(),
      ],
    });
    await repo.stageRoutineBootstrap(manifest);
    if (download) {
      for (final (i, p) in pages.indexed) {
        await repo.stageRoutineBootstrapPage(i, SnapshotPage3Dto.fromJson(p));
      }
    }
    return manifest;
  }

  Future<void> activate({
    int position = 1,
    String generation = testGeneration,
  }) => repo.activateRoutineBootstrap(
    MeResponse3Dto.fromJson({
      ...identity,
      'position': position,
      'generation': generation,
    }),
  );
  Json snapshot({
    List<Json> routines = const [],
    List<Json> workouts = const [],
    List<String> retired = const [],
  }) => {'roots': workouts, 'routines': routines, 'retired_ids': retired};
  Future<String> durableState() async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return canonicalJson({
      for (final table in tables)
        table.read<String>('name'): [
          for (final row
              in await db
                  .customSelect(
                    'SELECT * FROM "${table.read<String>('name')}" ORDER BY rowid',
                  )
                  .get())
            row.data,
        ],
    });
  }

  Matcher violation(String code) =>
      throwsA(isA<ContractViolation>().having((e) => e.code, 'code', code));

  Iterable<List<String>> interleavings(List<String> actions) sync* {
    if (actions.isEmpty) {
      yield [];
      return;
    }
    for (final action in actions) {
      for (final rest in interleavings([
        for (final other in actions)
          if (other != action) other,
      ])) {
        yield [action, ...rest];
      }
    }
  }

  for (final order in interleavings(['ack', 'pull', 'bootstrap', 'edit'])) {
    test(
      'routine ordering preserves the edited base and immutable history: ${order.join('-')}',
      () async {
        final first = await saved();
        final second = operation(
          base: 1,
          predecessor: first['payload']['template_id'],
        );
        second['payload']['prescription'] = routinePlan(
          name: 'Other installation revision 2',
        ).json;
        final remote = {
          ...root(first),
          'revision': 2,
          'current_template_id': second['payload']['template_id'],
          'templates': [
            {...first['payload'] as Json, 'revision': 1},
            {...second['payload'] as Json, 'revision': 2},
          ],
        };
        SavedRoutine? local;
        int? editedBase;
        for (final action in order) {
          switch (action) {
            case 'ack':
              await acknowledge(first);
            case 'pull':
              final metadata = await repo.syncMetadata();
              await pull(
                page([
                  if (metadata['position'] == 0) ...[
                    {'position': 1, 'revision': 1, 'operation': first},
                    {'position': 2, 'revision': 2, 'operation': second},
                  ],
                ], position: 2),
                cursor: metadata['cursor'] as String?,
              );
            case 'bootstrap':
              await stage([
                snapshot(routines: [remote]),
              ], position: 2);
              await activate(position: 2);
            case 'edit':
              final current = (await repo.routine(routineId))!;
              editedBase = current.templateId == first['payload']['template_id']
                  ? 1
                  : 2;
              local = await repo.saveRoutine(
                id: routineId,
                expectedRevision: current.localRevision,
                plan: routinePlan(name: 'Preserved local intent', reps: 19),
              );
          }
        }
        final edited = local!;
        expect((await repo.routine(routineId))!.templateId, edited.templateId);
        expect(
          (await repo.routineSyncDetails(routineId))!['server_revision'],
          2,
        );
        expect(await repo.routinePendingCount(), 1);
        final frozen = (await repo.prepareRoutineHead(routineId))!;
        final head = jsonDecode(frozen) as Json;
        expect(head['expected_revision'], editedBase);
        expect(
          head['payload']['predecessor_template_id'],
          editedBase == 1
              ? first['payload']['template_id']
              : second['payload']['template_id'],
        );
        final before = await durableState();
        await reopen();
        expect(await durableState(), before);
        expect(await repo.prepareRoutineHead(routineId), frozen);
        expect(
          (await repo.routine(routineId))!.plan.name,
          'Preserved local intent',
        );
        if (editedBase == 1) {
          final workout = await repo.startFoundationWorkout();
          final workoutBody = await repo.prepareHead(workout);
          await repo.installRoutineAcknowledgements(
            PushResponse3Dto.fromJson({
              ...context,
              'results': [
                {
                  'mutation_id': head['mutation_id'],
                  'aggregate_id': routineId,
                  'status': 'conflict',
                  'expected_revision': 1,
                  'current_revision': 2,
                  'error': {'code': 'revision_conflict', 'retryable': false},
                },
              ],
            }),
            [head['mutation_id'] as String],
          );
          expect(await repo.prepareRoutineHead(routineId), isNull);
          expect(
            (await repo.routineSyncDetails(routineId))!['has_conflict'],
            1,
          );
          expect(
            (await repo.routine(routineId))!.templateId,
            edited.templateId,
          );
          expect(await repo.prepareHead(workout), workoutBody);
        } else {
          await acknowledge(head);
          await acknowledge(first);
          expect(
            (await repo.routineSyncDetails(routineId))!['server_revision'],
            3,
          );
          expect(await repo.routinePendingCount(), 0);
          expect(
            (await repo.routine(routineId))!.templateId,
            edited.templateId,
          );
        }
      },
    );
  }

  for (final existing in [false, true]) {
    test(
      'routine feed command must match creation lineage: existing=$existing',
      () async {
        String? cursor;
        Json incoming;
        if (existing) {
          final first = operation();
          await pull(
            page([
              {'position': 1, 'revision': 1, 'operation': first},
            ]),
          );
          cursor = 'cursor-1';
          incoming = operation(
            base: 1,
            predecessor: first['payload']['template_id'],
          )..['command'] = 'create_routine';
        } else {
          incoming = operation()..['command'] = 'publish_template';
        }
        final position = existing ? 2 : 1;
        final before = await durableState();
        await expectLater(
          pull(
            page([
              {
                'position': position,
                'revision': position,
                'operation': incoming,
              },
            ], position: position),
            cursor: cursor,
          ),
          violation('invalid_routine_history'),
        );
        expect(await durableState(), before);
        await reopen();
        expect(await durableState(), before);
      },
    );
  }

  for (final boundary in ['pull', 'bootstrap']) {
    for (final target in ['routine_root', 'routine_template']) {
      test(
        'workout retirement cannot alias retained planning identities: $boundary/$target',
        () async {
          final planning = await saved();
          await acknowledge(planning);
          final workout = await repo.startFoundationWorkout();
          final frozen = await repo.prepareHead(workout);
          final alias = target == 'routine_root'
              ? routineId
              : planning['payload']['template_id'] as String;
          final retired = [workout, alias];
          if (boundary == 'bootstrap') {
            await stage([snapshot(retired: retired)]);
          }
          final before = await durableState();
          await expectLater(
            boundary == 'pull'
                ? pull(
                    page([
                      {
                        'position': 1,
                        'aggregate_id': workout,
                        'redacted': true,
                        'retired_ids': retired,
                      },
                    ]),
                  )
                : activate(),
            violation('identity_collision'),
          );
          expect(await durableState(), before);
          await reopen();
          expect(await durableState(), before);
          expect(await repo.prepareHead(workout), frozen);
          expect(
            (await repo.routineSyncDetails(routineId))!['server_revision'],
            1,
          );
          expect(
            (await repo.routine(routineId))!.templateId,
            planning['payload']['template_id'],
          );
        },
      );
    }
  }

  for (final mismatch in ['none', 'prescription', 'template_identity']) {
    test(
      'older external routine echo checks accepted immutable history: $mismatch',
      () async {
        final first = await saved();
        await acknowledge(first);
        final current = (await repo.routine(routineId))!;
        await repo.saveRoutine(
          id: routineId,
          expectedRevision: current.localRevision,
          plan: routinePlan(name: 'Already accepted successor'),
        );
        final second =
            jsonDecode((await repo.prepareRoutineHead(routineId))!) as Json;
        await acknowledge(second);
        final external = copyJson(first)..['mutation_id'] = repo.newId();
        if (mismatch == 'prescription') {
          external['payload']['prescription']['name'] = 'Contradictory history';
        } else if (mismatch == 'template_identity') {
          external['payload']['template_id'] = repo.newId();
        }
        // A valid earlier workout must also roll back if the later routine
        // entry contradicts an immutable publication already acknowledged.
        final response = page([
          {'position': 1, 'revision': 1, 'operation': fixture()},
          {'position': 2, 'revision': 1, 'operation': external},
        ]);
        final before = await durableState();
        if (mismatch == 'none') {
          await pull(response);
          expect((await repo.syncMetadata())['position'], 2);
          expect(
            (await repo.routineSyncDetails(routineId))!['server_revision'],
            2,
          );
          expect(
            (await repo.routine(routineId))!.templateId,
            second['payload']['template_id'],
          );
        } else {
          await expectLater(
            pull(response),
            violation('immutable_template_mismatch'),
          );
          expect(await durableState(), before);
          await reopen();
          expect(await durableState(), before);
        }
      },
    );
  }

  test('stale routine bootstrap cannot rewind a cursor advanced by a newer mixed pull', () async {
    final op = operation();
    await stage([
      snapshot(routines: [root(op)]),
    ]);
    final newer = operation(base: 1, predecessor: op['payload']['template_id']);
    await pull(
      page([
        {'position': 1, 'revision': 1, 'operation': op},
        {'position': 2, 'revision': 2, 'operation': newer},
      ]),
    );
    final before = await durableState();
    await expectLater(activate(position: 2), violation('stale_page'));
    expect(await durableState(), before);
    expect((await repo.syncMetadata())['cursor'], 'cursor-2');
  });

  for (final kind in [
    'workout_root',
    'workout_child',
    'other_routine_root',
    'retired_template',
  ]) {
    test(
      'bootstrap rejects cross-domain routine identity alias: $kind',
      () async {
        final workout = applyOperation(null, fixture(), revision: 1)!;
        final first = operation();
        final roots = <Json>[root(first)];
        var retired = <String>[];
        switch (kind) {
          case 'workout_root':
            roots[0] = root(operation(id: workout['aggregate_id'] as String));
          case 'workout_child':
            roots[0] = root(
              operation(template: allSets(workout).first['set_id'] as String),
            );
          case 'other_routine_root':
            roots.add(
              root(operation(id: first['payload']['template_id'] as String)),
            );
          case 'retired_template':
            retired = [first['payload']['template_id'] as String];
        }
        await stage([
          snapshot(routines: roots, workouts: [workout], retired: retired),
        ]);
        final before = await durableState();
        await expectLater(activate(), violation('identity_collision'));
        expect(await durableState(), before);
      },
    );
  }

  test('request freezing failure rolls back bytes, then restart retries the exact durable mutation', () async {
    await repo.saveRoutine(
      id: routineId,
      expectedRevision: 0,
      plan: routinePlan(),
    );
    final before = await durableState();
    await db.customStatement(
      "CREATE TRIGGER fail_freeze BEFORE UPDATE OF frozen_body ON routine_mutations BEGIN SELECT RAISE(ABORT,'controlled freeze fault'); END",
    );
    await expectLater(repo.prepareRoutineHead(routineId), throwsA(anything));
    expect(await durableState(), before);
    await db.customStatement('DROP TRIGGER fail_freeze');
    final bytes = (await repo.prepareRoutineHead(routineId))!;
    await repo.markMixedAttempts([
      (jsonDecode(bytes) as Json)['mutation_id'] as String,
    ]);
    await repo.recordSyncFailure('offline');
    await reopen();
    expect(await repo.prepareRoutineHead(routineId), bytes);
    final row = await db
        .customSelect('SELECT * FROM routine_mutations')
        .getSingle();
    expect(row.read<int>('attempt_count'), 1);
    expect(
      row.read<String>('request_digest'),
      sha256.convert(utf8.encode(bytes)).toString(),
    );
    expect((await repo.syncMetadata())['last_error'], 'offline');
  });

  for (final boundary in [
    'routine_mutations',
    'routine_cloud_templates',
    'routine_sync_state',
  ]) {
    test(
      'acknowledgement failure at $boundary rolls back all accepted state and safely replays after restart',
      () async {
        final op = await saved();
        final before = await durableState();
        final action = boundary == 'routine_cloud_templates'
            ? 'INSERT'
            : 'UPDATE';
        await db.customStatement(
          "CREATE TRIGGER fail_ack BEFORE $action ON $boundary BEGIN SELECT RAISE(ABORT,'controlled ack fault'); END",
        );
        await expectLater(acknowledge(op), throwsA(anything));
        expect(await durableState(), before);
        await db.customStatement('DROP TRIGGER fail_ack');
        await reopen();
        expect(await repo.prepareRoutineHead(routineId), canonicalJson(op));
        await acknowledge(op);
        await acknowledge(op);
        expect(await repo.routinePendingCount(), 0);
        expect(
          (await repo.routineSyncDetails(routineId))!['server_revision'],
          1,
        );
        expect(
          await db.customSelect('SELECT * FROM routine_cloud_templates').get(),
          hasLength(1),
        );
      },
    );
  }

  test('malformed second aggregate rolls back a valid workout echo and the whole page cursor', () async {
    final invalid = operation(base: 1, predecessor: repo.newId());
    final before = await durableState();
    await expectLater(
      pull(
        page([
          {'position': 1, 'revision': 1, 'operation': fixture()},
          {'position': 2, 'revision': 2, 'operation': invalid},
        ]),
      ),
      violation('invalid_routine_history'),
    );
    expect(await durableState(), before);
    await reopen();
    expect(await repo.workouts(), isEmpty);
    expect(await repo.routines(), isEmpty);
  });

  for (final fault in [
    'unknown_aggregate',
    'unknown_contract',
    'owner',
    'generation',
    'epoch',
    'gap',
    'duplicate',
  ]) {
    test('mixed pull refuses $fault without changing data or cursor', () async {
      final op = operation();
      final value = page([
        {'position': 1, 'revision': 1, 'operation': op},
      ]);
      switch (fault) {
        case 'unknown_aggregate':
          op['aggregate_type'] = 'catalog';
        case 'unknown_contract':
          value['schema_version'] = 99;
        case 'owner':
          value['owner_id'] = repo.newId();
        case 'generation':
          value['generation'] = repo.newId();
        case 'epoch':
          value['erasure_epoch'] = 1;
        case 'gap':
          value['changes'][0]['position'] = 2;
          value['next_position'] = 2;
        case 'duplicate':
          value['changes'].add(copyJson(value['changes'][0] as Json));
      }
      final before = await durableState();
      await expectLater(pull(value), throwsA(isA<ContractViolation>()));
      expect(await durableState(), before);
    });
  }

  test(
    'delayed old pull never reinstalls an obsolete cursor or template',
    () async {
      final op = operation();
      final first = page([
        {'position': 1, 'revision': 1, 'operation': op},
      ]);
      await pull(first);
      final before = await durableState();
      await expectLater(pull(first), violation('stale_page'));
      expect(await durableState(), before);
    },
  );

  for (final fault in [
    'checksum',
    'incomplete',
    'lineage',
    'offset',
    'head',
    'immutable',
  ]) {
    test(
      'bootstrap $fault preserves local pending work, frozen bytes and staged evidence',
      () async {
        final local = await saved();
        final incoming = root(operation(id: repo.newId()));
        final p = snapshot(routines: [incoming]);
        if (fault == 'lineage') {
          incoming['templates'][0]['predecessor_template_id'] = repo.newId();
        }
        if (fault == 'offset') incoming['template_offset'] = 1;
        if (fault == 'head') incoming['current_template_id'] = repo.newId();
        if (fault == 'immutable') {
          await acknowledge(local);
          final existing = root(local);
          existing['templates'][0]['prescription']['name'] =
              'Changed immutable prescription';
          p['routines'].add(existing);
        }
        final manifest = await stage([
          p,
        ], download: fault != 'checksum' && fault != 'incomplete');
        if (fault == 'checksum') {
          final before = await durableState();
          await expectLater(
            repo.stageRoutineBootstrapPage(
              0,
              SnapshotPage3Dto.fromJson(snapshot()),
            ),
            violation('snapshot_checksum'),
          );
          expect(await durableState(), before);
        } else {
          final before = await durableState();
          await expectLater(activate(), throwsA(isA<ContractViolation>()));
          expect(await durableState(), before);
        }
        expect((await repo.stagedRoutineBootstrap())!.token, manifest.token);
        expect(
          (await repo.routine(routineId))!.templateId,
          local['payload']['template_id'],
        );
        expect(
          await db.customSelect('SELECT * FROM routine_mutations').get(),
          hasLength(1),
        );
      },
    );
  }

  for (final kind in [
    'workout_root',
    'workout_set',
    'routine_template',
    'retired_template',
  ]) {
    test(
      'routine pull rejects identity aliases against retained local data: $kind',
      () async {
        final workoutId = await repo.startFoundationWorkout();
        final workout = (await repo.workout(workoutId))!;
        var op = operation();
        switch (kind) {
          case 'workout_root':
            op = operation(id: workoutId);
          case 'workout_set':
            op = operation(
              template: allSets(workout).first['set_id'] as String,
            );
          case 'routine_template':
            final local = await saved();
            op = operation(id: local['payload']['template_id'] as String);
          case 'retired_template':
            await db.customStatement('INSERT INTO retired_ids(id) VALUES(?)', [
              op['payload']['template_id'],
            ]);
        }
        final before = await durableState();
        await expectLater(
          pull(
            page([
              {'position': 1, 'revision': 1, 'operation': op},
            ]),
          ),
          violation('identity_collision'),
        );
        expect(await durableState(), before);
      },
    );
  }

  for (final kind in ['routine_root', 'routine_template']) {
    test('workout in mixed pull cannot alias an installed $kind', () async {
      final op = operation();
      await pull(
        page([
          {'position': 1, 'revision': 1, 'operation': op},
        ]),
      );
      final workout = fixture();
      if (kind == 'routine_root') {
        workout['aggregate_id'] = op['aggregate_id'];
      } else {
        workout['payload']['exercises'][0]['sets'][0]['set_id'] =
            op['payload']['template_id'];
      }
      final before = await durableState();
      await expectLater(
        pull(
          page([
            {'position': 2, 'revision': 1, 'operation': workout},
          ], position: 2),
          cursor: 'cursor-1',
        ),
        violation('identity_collision'),
      );
      expect(await durableState(), before);
    });
  }

  test('an acknowledgement cannot claim acceptance outside the already installed immutable lineage', () async {
    final local = await saved();
    final other = operation();
    await pull(
      page([
        {'position': 1, 'revision': 1, 'operation': other},
      ]),
    );
    final before = await durableState();
    await expectLater(
      acknowledge(local),
      violation('immutable_template_mismatch'),
    );
    expect(await durableState(), before);
    expect(await repo.prepareRoutineHead(routineId), canonicalJson(local));
  });

  test('missing accepted root becomes a durable conflict while an offline-only root stays pending', () async {
    final accepted = await saved();
    await acknowledge(accepted);
    final newId = repo.newId();
    await repo.saveRoutine(
      id: newId,
      expectedRevision: 0,
      plan: routinePlan(name: 'Only on this device'),
    );
    final frozen = await repo.prepareRoutineHead(newId);
    await stage([snapshot()], position: 2);
    await activate(position: 2);
    await reopen();
    expect((await repo.routineSyncDetails(routineId))!['has_conflict'], 1);
    expect(
      (await repo.routine(routineId))!.templateId,
      accepted['payload']['template_id'],
    );
    expect(
      await db.customSelect('SELECT * FROM routine_cloud_templates').get(),
      hasLength(1),
    );
    expect((await repo.routineSyncDetails(newId))!['has_conflict'], 0);
    expect(await repo.prepareRoutineHead(newId), frozen);
  });

  test('a changed generation never establishes ancestry for a pending local routine branch', () async {
    final op = await saved();
    await acknowledge(op);
    final savedPlan = (await repo.routine(routineId))!;
    await repo.saveRoutine(
      id: routineId,
      expectedRevision: savedPlan.localRevision,
      plan: routinePlan(reps: 11),
    );
    final frozen = await repo.prepareRoutineHead(routineId);
    final generation = repo.newId();
    await stage([
      snapshot(routines: [root(op)]),
    ], generation: generation);
    await activate(generation: generation);
    await reopen();
    expect((await repo.routineSyncDetails(routineId))!['has_conflict'], 1);
    expect(await repo.prepareRoutineHead(routineId), isNull);
    final pending = await db
        .customSelect(
          "SELECT frozen_body FROM routine_mutations WHERE state='pending'",
        )
        .getSingle();
    expect(pending.read<String>('frozen_body'), frozen);
    expect(
      (await repo.routine(routineId))!
          .plan
          .json['exercises'][0]['sets'][0]['planned']['reps'],
      11,
    );
  });

  test('installed recovery authority fences every routine cloud write while offline saves remain usable', () async {
    final op = await saved();
    final p = snapshot(routines: [root(operation(id: repo.newId()))]);
    await stage([p]);
    await db.customStatement('UPDATE recovery_state SET required=1');
    final before = await durableState();
    final actions = <Future<void> Function()>[
      () async {
        await repo.prepareRoutineHead(routineId);
      },
      () => repo.markMixedAttempts([op['mutation_id'] as String]),
      () => acknowledge(op),
      () => pull(
        page([
          {'position': 1, 'revision': 1, 'operation': op},
        ]),
      ),
      () async {
        await stage([p]);
      },
      () => repo.stageRoutineBootstrapPage(0, SnapshotPage3Dto.fromJson(p)),
      () => activate(),
    ];
    for (final action in actions) {
      await expectLater(action(), violation('upgrade_required'));
      expect(await durableState(), before);
    }
    final current = (await repo.routine(routineId))!;
    await repo.saveRoutine(
      id: routineId,
      expectedRevision: current.localRevision,
      plan: routinePlan(reps: 12),
    );
    expect(await repo.routinePendingCount(), 2);
    expect(
      (await repo.routine(routineId))!.localRevision,
      current.localRevision + 1,
    );
  });

  for (final tampered in [false, true]) {
    test(
      'a snapshot behind acknowledged routine state validates its immutable prefix: tampered=$tampered',
      () async {
        final first = await saved();
        await acknowledge(first);
        final current = (await repo.routine(routineId))!;
        await repo.saveRoutine(
          id: routineId,
          expectedRevision: current.localRevision,
          plan: routinePlan(name: 'Newly acknowledged plan'),
        );
        final second =
            jsonDecode((await repo.prepareRoutineHead(routineId))!) as Json;
        await acknowledge(second);
        expect(
          (await repo.syncMetadata())['position'],
          0,
          reason: 'A push acknowledgement is ahead of the pull cursor.',
        );
        final older = copyJson(root(first));
        if (tampered) {
          older['templates'][0]['prescription']['name'] =
              'Contradictory immutable content';
        }
        await stage([
          snapshot(routines: [older]),
        ]);
        final before = await durableState();
        if (tampered) {
          await expectLater(
            activate(position: 2),
            violation('immutable_template_mismatch'),
          );
          expect(await durableState(), before);
        } else {
          await activate(position: 2);
          expect((await repo.syncMetadata())['position'], 1);
          expect(
            (await repo.routineSyncDetails(routineId))!['server_revision'],
            2,
          );
          expect(
            (await repo.routine(routineId))!.templateId,
            second['payload']['template_id'],
          );
          await pull(
            page([
              {'position': 2, 'revision': 2, 'operation': second},
            ], position: 2),
            cursor: 'snapshot-1',
          );
          expect((await repo.syncMetadata())['position'], 2);
          expect(await repo.routinePendingCount(), 0);
          expect(
            await db
                .customSelect('SELECT * FROM routine_cloud_templates')
                .get(),
            hasLength(2),
          );
        }
      },
    );
  }

  test('failed replacement manifest restores the prior staging branch and pending local data', () async {
    await saved();
    await stage([
      snapshot(routines: [root(operation(id: repo.newId()))]),
    ]);
    final before = await durableState();
    await db.customStatement(
      "CREATE TRIGGER fail_manifest BEFORE INSERT ON bootstrap_stage BEGIN SELECT RAISE(ABORT,'controlled staging fault'); END",
    );
    await expectLater(stage([snapshot()], position: 2), throwsA(anything));
    expect(await durableState(), before);
    await db.customStatement('DROP TRIGGER fail_manifest');
    await reopen();
    expect((await repo.stagedRoutineBootstrap())!.position, 1);
    expect(await repo.stagedPageIndices(), {0});
    expect(await repo.routinePendingCount(), 1);
  });

  test('page staging storage failure retains manifest and resumes after file restart without touching local pending work', () async {
    final local = await saved();
    final p = snapshot(routines: [root(operation(id: repo.newId()))]);
    await stage([p], download: false);
    final before = await durableState();
    await db.customStatement(
      "CREATE TRIGGER fail_page BEFORE INSERT ON bootstrap_pages BEGIN SELECT RAISE(ABORT,'controlled page write fault'); END",
    );
    await expectLater(
      repo.stageRoutineBootstrapPage(0, SnapshotPage3Dto.fromJson(p)),
      throwsA(anything),
    );
    expect(await durableState(), before);
    await db.customStatement('DROP TRIGGER fail_page');
    await reopen();
    expect(await repo.stagedPageIndices(), isEmpty);
    expect(await repo.prepareRoutineHead(routineId), canonicalJson(local));
    await repo.stageRoutineBootstrapPage(0, SnapshotPage3Dto.fromJson(p));
    await activate();
    expect(await repo.routines(), hasLength(2));
    expect(await repo.routinePendingCount(), 1);
    expect(await repo.prepareRoutineHead(routineId), canonicalJson(local));
  });

  test('bootstrap activation storage failure rolls back imports and cursor, and resumes staged pages after restart', () async {
    await stage([
      snapshot(routines: [root(operation())]),
    ]);
    final before = await durableState();
    await db.customStatement(
      "CREATE TRIGGER fail_activation BEFORE UPDATE ON sync_metadata BEGIN SELECT RAISE(ABORT,'controlled activation fault'); END",
    );
    await expectLater(activate(), throwsA(anything));
    expect(await durableState(), before);
    await db.customStatement('DROP TRIGGER fail_activation');
    await reopen();
    expect(await repo.stagedPageIndices(), {0});
    await activate();
    expect(await repo.routines(), hasLength(1));
    expect(await repo.stagedRoutineBootstrap(), isNull);
    expect((await repo.syncMetadata())['position'], 1);
  });
}
