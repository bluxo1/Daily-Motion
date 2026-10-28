import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/auth/local_owners.dart';

import 'support/auth_fakes.dart';

import 'repository_test.dart' show recordPayload, fixture;

class DroppedResponseTransport extends HttpSyncTransport {
  @override
  Future<SyncTransport> beginCycle() async => this;
  bool drop = true;
  final requests = <String>[];
  DroppedResponseTransport(super.base, super.accessToken)
    : super(allowLoopbackHttp: true);
  @override
  Future<PushResponseDto> push(String body) async {
    requests.add(body);
    final response = await super.push(body);
    if (drop) {
      drop = false;
      throw const SyncFailure('response_lost', retryable: true);
    }
    return response;
  }
}

void main() {
  final endpoint = Platform.environment['DM_SYNC_ENDPOINT'];
  final enabled = endpoint != null;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late HttpSyncTransport transport;
  late SyncCoordinator sync;
  setUp(() async {
    if (!enabled) return;
    db = TrainingDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    transport = HttpSyncTransport(
      Uri.parse(endpoint),
      () async => Platform.environment['DM_SYNC_TOKEN'],
      allowLoopbackHttp: true,
    );
    sync = SyncCoordinator(repo, transport, jitter: () => 0.5);
  });
  tearDown(() async {
    if (enabled) {
      await sync.close();
      transport.close();
      repo.dispose();
      await db.close();
    }
  });
  Future<String> recorded() async {
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    return id;
  }

  Future<WorkoutRepository> device(TrainingDatabase otherDb) async {
    final other = WorkoutRepository(otherDb, repo.ownerId);
    await other.initialize();
    return other;
  }

  Future<Json> cloudRoot(String id) async {
    final manifest = await transport.bootstrap(repo.newId());
    final roots = <Json>[];
    for (var i = 0; i < manifest.pageCount; i++) {
      roots.addAll(
        (await transport.page(manifest.token, i)).roots.cast<Json>(),
      );
    }
    return roots.singleWhere((r) => r['aggregate_id'] == id);
  }

  test('real signed JWT, restricted PostgreSQL upload, own echo and second-device bootstrap', () async {
    final routine = await repo.saveRoutine(
      id: repo.newId(),
      expectedRevision: 0,
      plan: RoutinePlan.fromJson(fixture()['payload'] as Json),
    );
    final id = await repo.startRoutine(
      routineId: routine.id,
      templateId: routine.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final activeSnapshot = (await repo.workout(id))!;
    final futurePlan = routine.plan.json..['name'] = 'Future routine edit';
    futurePlan['exercises'][0]['sets'][0]['planned']['reps'] = 8;
    await repo.saveRoutine(
      id: routine.id,
      expectedRevision: 1,
      plan: RoutinePlan.fromJson(futurePlan),
    );
    expect(await repo.workout(id), activeSnapshot);
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
    expect((await cloudRoot(id))['revision'], 2);
    final otherDb = TrainingDatabase(NativeDatabase.memory());
    final other = await device(otherDb);
    final otherSync = SyncCoordinator(other, transport);
    try {
      await otherSync.synchronize(force: true);
      expect(
        await other.routines(),
        isEmpty,
        reason: 'Local routine content is not part of workout synchronization.',
      );
      expect((await other.workout(id))!['name'], routine.plan.name);
      expect((await other.workout(id))!['timezone'], 'UTC');
      expect(allSets((await other.workout(id))!).first['planned']['reps'], 5);
      expect(
        allSets((await other.workout(id))!)
            .first['observation']['actual']['reps'],
        5,
      );
      expect((await other.syncMetadata())['position'], greaterThanOrEqualTo(2));

      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1, status: 'skipped'),
      );
      await repo.commit(id, 'complete_session', {});
      final recorded = recordPayload((await repo.workout(id))!);
      await repo.commit(id, 'correct_set', {
        ...recorded,
        'completion_seq': 1,
        'execution_status': 'skipped',
        'actual': null,
        'correction_reason': 'The set was recorded by mistake.',
      });
      await sync.synchronize(force: true);
      expect(
        sync.status.phase,
        SyncPhase.synchronized,
        reason: sync.status.code,
      );
      final corrected = await cloudRoot(id);
      expect(corrected['revision'], 5);
      expect(corrected['status'], 'completed');
      expect(
        allSets(corrected).first['observation']['execution_status'],
        'skipped',
      );

      final manifest = await transport.bootstrap(
        (await other.syncMetadata())['installation_id'] as String,
      );
      await other.stageBootstrap(manifest);
      for (var index = 0; index < manifest.pageCount; index++) {
        await other.stageBootstrapPage(
          index,
          await transport.page(manifest.token, index),
        );
      }
      await other.activateBootstrap(
        await transport.validateSnapshot(manifest.token),
      );
      final restored = (await other.workout(id))!;
      expect(restored['status'], 'completed');
      expect(
        allSets(restored).first['observation']['execution_status'],
        'skipped',
      );
      expect(allSets(restored).first['observation']['actual'], isNull);
      expect(
        allSets(restored).first['observation']['correction_reason'],
        'The set was recorded by mistake.',
      );
      final originalSkip =
          allSets(restored).elementAt(1)['observation'] as Json;
      expect(originalSkip['execution_status'], 'skipped');
      expect(originalSkip['actual'], isNull);
      expect(originalSkip['correction_reason'], isNull);
      expect(originalSkip['completion_seq'], 2);
      expect(restored['revision'], 5);
      expect((await other.syncMetadata())['position'], greaterThanOrEqualTo(5));
    } finally {
      await otherSync.close();
      other.dispose();
      await otherDb.close();
    }

    // Exercise the production UI command controller against the real HTTP feed
    // with a separate multi-exercise routine. Keep the corrected-skipped-only
    // bootstrap controls above intact.
    final multi = copyJson(fixture()['payload'] as Json);
    multi['name'] = 'Connected multi-exercise snapshot';
    final originalExercise = (multi['exercises'] as List).first as Json;
    multi['exercises'] = [
      for (var i = 0; i < 3; i++)
        {
          ...copyJson(originalExercise),
          'session_exercise_id': repo.newId(),
          'variant_id': repo.newId(),
          'name': ['Single-arm row', 'Push-up', 'Assisted pull-up'][i],
          'loading_basis': [
            'per_implement',
            'bodyweight_only',
            'assistance',
          ][i],
          'rep_convention': i == 0 ? 'per_side' : 'bilateral',
          'side': i == 0 ? 'left' : 'both',
          'sets': [
            {
              ...copyJson((originalExercise['sets'] as List).first as Json),
              'set_id': repo.newId(),
              'planned': {
                'reps': 5,
                'load': i == 1
                    ? null
                    : {
                        'value': i == 0 ? '20' : '5',
                        'unit': 'kg',
                        'basis': i == 0 ? 'per_implement' : 'assistance',
                      },
                'rest_seconds': 120,
              },
            },
          ],
        },
    ];
    final multiRoutine = await repo.saveRoutine(
      id: repo.newId(),
      expectedRevision: 0,
      plan: RoutinePlan.fromJson(multi),
    );
    final multiId = await repo.startRoutine(
      routineId: multiRoutine.id,
      templateId: multiRoutine.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    final controllerScope = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final thirdDb = TrainingDatabase(NativeDatabase.memory());
    final third = await device(thirdDb);
    final thirdSync = SyncCoordinator(third, transport);
    try {
      await controllerScope.read(workoutsProvider.future);
      final controller = controllerScope.read(workoutsProvider.notifier);
      final initial = (await repo.workout(multiId))!;
      for (final i in [2, 0, 1]) {
        final e = initial['exercises'][i] as Json;
        await controller.record(multiId, e, e['sets'][0] as Json, {
          'execution_status': i == 2
              ? 'failed'
              : i == 0
              ? 'partial'
              : 'completed',
          'load': i == 0
              ? '20'
              : i == 2
              ? '5'
              : '',
          'unit': 'kg',
          'reps': i == 2 ? '0' : '3',
          'effort': '',
          'effort_scale': 'rir',
        });
      }
      await controller.finish(multiId);
      final bodyweight = initial['exercises'][1] as Json;
      // The query uses real HTTP/PostgreSQL-installed projections, both before
      // and after a correction. No alternative history store or report oracle.
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.synchronized);
      await thirdSync.synchronize(force: true);
      expect(thirdSync.status.phase, SyncPhase.synchronized);
      final beforeCorrection = buildExerciseHistory(await third.workouts());
      final reference = beforeCorrection.byExercise[exerciseKey(bodyweight)]!
          .previous()!;
      expect(reference.workout['aggregate_id'], multiId);
      expect(
        reference.completedWorking.single.$2['observation']['actual']['reps'],
        3,
      );
      expect(
        reference.completedWorking.single.$2['observation']['actual']['load'],
        isNull,
      );
      await controller.record(
        multiId,
        bodyweight,
        bodyweight['sets'][0] as Json,
        {
          'execution_status': 'skipped',
          'load': '',
          'unit': 'kg',
          'reps': '',
          'effort': '',
          'effort_scale': 'rir',
        },
        reason: 'This bodyweight entry was accidental.',
      );
      final completed = (await repo.workout(multiId))!;
      final nextPlan = multiRoutine.plan.json
        ..['name'] = 'Later multi-exercise plan';
      nextPlan['exercises'][2]['sets'][0]['planned']['reps'] = 99;
      await repo.saveRoutine(
        id: multiRoutine.id,
        expectedRevision: 1,
        plan: RoutinePlan.fromJson(nextPlan),
      );
      expect(await repo.workout(multiId), completed);
      await sync.synchronize(force: true);
      expect(
        sync.status.phase,
        SyncPhase.synchronized,
        reason: sync.status.code,
      );
      expect((await cloudRoot(multiId))['revision'], 6);
      await thirdSync.synchronize(force: true);
      expect(
        thirdSync.status.phase,
        SyncPhase.synchronized,
        reason: thirdSync.status.code,
      );
      final restored = (await third.workout(multiId))!;
      expect(restored['exercises'], completed['exercises']);
      expect(restored['status'], 'completed');
      expect(restored['name'], 'Connected multi-exercise snapshot');
      expect(restored['timezone'], 'UTC');
      expect(restored['revision'], 6);
      expect(
        (restored['exercises'] as List)
            .map((e) => e['sets'][0]['observation']['completion_seq'])
            .toList(),
        [2, 3, 1],
      );
      expect(
        restored['exercises'][0]['sets'][0]['observation']['execution_status'],
        'partial',
      );
      expect(
        restored['exercises'][1]['sets'][0]['observation']['actual'],
        isNull,
      );
      expect(
        restored['exercises'][1]['sets'][0]['observation']['correction_reason'],
        'This bodyweight entry was accidental.',
      );
      expect(
        restored['exercises'][2]['sets'][0]['observation']['actual']['reps'],
        0,
      );
      expect(await third.routines(), isEmpty);
      final history = buildExerciseHistory(await third.workouts());
      for (final exercise in (restored['exercises'] as List).cast<Json>()) {
        final group = history.byExercise[exerciseKey(exercise)]!;
        final visit = group.visits.singleWhere(
          (v) => v.workout['aggregate_id'] == multiId,
        );
        expect(visit.occurrences.single.exercise, exercise);
        expect(group.previous(), isNull); // partial, corrected-skipped, failed
      }
    } finally {
      controllerScope.dispose();
      await thirdSync.close();
      third.dispose();
      await thirdDb.close();
    }

    // A separate catalog-based session preserves the earlier skipped-only and
    // multi-exercise controls. Reusable catalog rows stay local; self-contained
    // workout snapshots use the unchanged owner-scoped workout protocol.
    final curated = curatedExercises[1]; // per-implement dumbbell bench press
    final custom = CatalogDefinition(
      movementId: curated.movementId,
      variantId: repo.newId(),
      revision: 1,
      name: 'Private machine press',
      equipment: CatalogEquipment.machine,
      setup: 'Synthetic machine A; seat 3',
      category: MovementCategory.push,
      loading: CatalogLoading.machineStack,
      repetitions: CatalogRepetitions.bilateral,
      side: null,
      source: CatalogSource.privateCustom,
    );
    await repo.saveCustomExercise(definition: custom, expectedRevision: 0);
    final catalogRoutine = await repo.saveRoutine(
      id: repo.newId(),
      expectedRevision: 0,
      plan: RoutinePlan(
        name: 'Connected catalog snapshot',
        exercises: [
          curated.prescription(repo.newId, plannedSets: 1),
          custom.prescription(repo.newId, plannedSets: 1),
        ],
      ),
    );
    expect(
      await repo.pendingCount(),
      0,
      reason: 'Catalog definitions and routines have no cloud write path.',
    );
    final catalogId = await repo.startRoutine(
      routineId: catalogRoutine.id,
      templateId: catalogRoutine.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    final catalogScope = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final catalogDb = TrainingDatabase(NativeDatabase.memory());
    final catalogOther = await device(catalogDb);
    final catalogSync = SyncCoordinator(catalogOther, transport);
    try {
      await catalogScope.read(workoutsProvider.future);
      final controller = catalogScope.read(workoutsProvider.notifier);
      final source = (await repo.workout(catalogId))!;
      for (var i = 0; i < 2; i++) {
        final e = source['exercises'][i] as Json;
        await controller.record(catalogId, e, e['sets'][0] as Json, {
          'execution_status': 'completed',
          'load': i == 0 ? '12.5' : '40',
          'unit': 'kg',
          'reps': i == 0 ? '7' : '8',
          'effort': '',
          'effort_scale': 'rir',
        });
      }
      await controller.finish(catalogId);
      final snapshot = (await repo.workout(catalogId))!;
      await repo.saveCustomExercise(
        definition: custom.displayRevision(
          name: 'Renamed private machine',
          archived: true,
        ),
        expectedRevision: 1,
      );
      final renamed = curated.displayRevision(name: 'Renamed curated display');
      await repo.saveRoutine(
        id: catalogRoutine.id,
        expectedRevision: 1,
        plan: RoutinePlan(
          name: 'Future catalog plan',
          exercises: [renamed.prescription(repo.newId)],
        ),
      );
      expect(await repo.workout(catalogId), snapshot);
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.synchronized);
      await catalogSync.synchronize(force: true);
      expect(catalogSync.status.phase, SyncPhase.synchronized);
      expect(await catalogOther.routines(), isEmpty);
      expect(
        (await catalogOther.exerciseCatalog()).where(
          (d) => d.source == CatalogSource.privateCustom,
        ),
        isEmpty,
      );
      final restored = (await catalogOther.workout(catalogId))!;
      // The existing server Prescription contract materializes an omitted
      // optional planned load as null. Preserve the sparse frozen local request
      // and compare every snapshot field against that documented default.
      final expectedExercises = (copyJson(snapshot)['exercises'] as List)
          .cast<Json>();
      for (final exercise in expectedExercises) {
        for (final set in (exercise['sets'] as List).cast<Json>()) {
          (set['planned'] as Json).putIfAbsent('load', () => null);
        }
      }
      expect(restored['exercises'], expectedExercises);
      final history = buildExerciseHistory(await catalogOther.workouts());
      for (final (i, e)
          in (restored['exercises'] as List).cast<Json>().indexed) {
        final points = buildMeasuredProgress(
          history.byExercise[exerciseKey(e)]!,
        );
        expect(points.repetitions.single.workoutId, catalogId);
        expect(
          points.loads['kg']!.single.load!.original,
          i == 0 ? '12.5' : '40',
        );
        expect(
          points.identity.variant,
          i == 0 ? curated.variantId : custom.variantId,
        );
      }
      final e = source['exercises'][0] as Json;
      await controller.record(catalogId, e, e['sets'][0] as Json, {
        'execution_status': 'completed',
        'load': '12.5',
        'unit': 'kg',
        'reps': '9',
        'effort': '',
        'effort_scale': 'rir',
      }, reason: 'Corrected connected catalog set');
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.synchronized);
      await catalogSync.synchronize(force: true);
      expect(catalogSync.status.phase, SyncPhase.synchronized);
      final current = buildExerciseHistory(await catalogOther.workouts());
      final measured = buildMeasuredProgress(
        current.byExercise[exerciseKey(e)]!,
      );
      expect(measured.repetitions.single.repetitions, 9);
      expect(measured.repetitions.single.exerciseName, curated.name);
      expect(measured.repetitions.single.identity, exerciseKey(e));
    } finally {
      catalogScope.dispose();
      await catalogSync.close();
      catalogOther.dispose();
      await catalogDb.close();
    }
  }, skip: !enabled);

  test('contract defaults and arbitrary supported IANA timezone survive real feed and snapshot', () async {
    await sync.synchronize(force: true);
    final op = fixture();
    op['mutation_id'] = repo.newId();
    op['aggregate_id'] = repo.newId();
    op['installation_id'] = repo.newId();
    op['payload']['timezone'] = 'America/New_York';
    op['payload']['name'] = List.filled(80, '🏋').join();
    for (final exercise in op['payload']['exercises'] as List) {
      exercise['name'] = List.filled(80, '🏋').join();
      exercise['session_exercise_id'] = repo.newId();
      exercise.remove('side');
      for (final item in exercise['sets'] as List) {
        item['set_id'] = repo.newId();
        item.remove('set_class');
        item.remove('set_purpose');
        item['planned'].remove('rest_seconds');
      }
    }
    final raw = canonicalJson(op);
    final response = await transport.push(
      '{"schema_version":1,"operations":[$raw]}',
    );
    expect(response.results.single['status'], 'accepted');
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
    final root = (await repo.workout(op['aggregate_id'] as String))!;
    expect(root['timezone'], 'America/New_York');
    expect(root['name'], op['payload']['name']);
    expect(allSets(root).first['set_class'], 'working');
    expect(allSets(root).first['planned']['rest_seconds'], 120);
    final feed = await transport.pull(null);
    expect(
      canonicalJson(
        feed.changes.singleWhere(
          (c) => c['operation']?['mutation_id'] == op['mutation_id'],
        )['operation'],
      ),
      raw,
    );
    expect(
      allSets(await cloudRoot(op['aggregate_id'] as String))
          .first['set_purpose'],
      'regular',
    );
  }, skip: !enabled);

  test('real receipt after dropped committed response is exact and replay-safe', () async {
    final id = await recorded();
    await sync.close();
    final dropped = DroppedResponseTransport(
      Uri.parse(endpoint!),
      () async => Platform.environment['DM_SYNC_TOKEN'],
    );
    sync = SyncCoordinator(repo, dropped);
    try {
      await sync.synchronize(force: true);
      expect((await cloudRoot(id))['revision'], 1);
      expect(await repo.pendingCount(), 2);
      final frozen = await repo.prepareHead(id);
      await sync.synchronize(force: true);
      expect((await cloudRoot(id))['revision'], 2);
      final delivered = dropped.requests
          .expand((s) => (jsonDecode(s)['operations'] as List).cast<Json>())
          .where((op) => op['command'] == 'create_session')
          .map(canonicalJson)
          .toSet();
      // Recovery can acknowledge through its own pulled echo before resending.
      expect(delivered, {frozen});
      expect(await repo.pendingCount(), 0);
    } finally {
      dropped.close();
    }
  }, skip: !enabled);

  test('real digest mismatch and exact duplicate results', () async {
    final id = await recorded();
    final frozen = (await repo.prepareHead(id))!;
    final batch = '{"schema_version":1,"operations":[$frozen]}';
    expect((await transport.push(batch)).results.single['status'], 'accepted');
    expect((await transport.push(batch)).results.single['status'], 'duplicate');
    final changed = jsonDecode(frozen) as Json;
    changed['payload']['name'] = 'Changed under same mutation';
    final rejected = await transport.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [changed],
      }),
    );
    expect(
      rejected.results.single['error']['code'],
      'mutation_digest_mismatch',
    );
  }, skip: !enabled);

  test('two real devices conflict without losing either branch', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    final otherDb = TrainingDatabase(NativeDatabase.memory());
    final other = await device(otherDb);
    final otherSync = SyncCoordinator(other, transport);
    try {
      await otherSync.synchronize(force: true);
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1, reps: 6),
      );
      await other.commit(
        id,
        'record_set',
        recordPayload((await other.workout(id))!, index: 1, reps: 9),
      );
      await otherSync.synchronize(force: true);
      await sync.synchronize(force: true);
      expect(sync.status.phase, SyncPhase.attention);
      expect(
        allSets((await repo.workout(id))!)
            .elementAt(1)['observation']['actual']['reps'],
        6,
      );
      expect(
        allSets(await cloudRoot(id))
            .elementAt(1)['observation']['actual']['reps'],
        9,
      );
    } finally {
      await otherSync.close();
      other.dispose();
      await otherDb.close();
    }
  }, skip: !enabled);

  test('real deletion retires pending branch, redacts feed and invalidates snapshot', () async {
    final id = await recorded();
    await sync.synchronize(force: true);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    final stale = (await repo.prepareHead(id))!;
    final snapshot = await transport.bootstrap(repo.newId());
    final delete = {
      'mutation_id': repo.newId(),
      'installation_id': repo.newId(),
      'aggregate_type': 'workout_session',
      'aggregate_id': id,
      'expected_revision': 2,
      'command': 'delete_session',
      'occurred_at': '2026-10-13T07:00:00Z',
      'recorded_at': '2026-10-13T07:00:00Z',
      'payload': <String, dynamic>{},
    };
    await transport.push(
      canonicalJson({
        'schema_version': 1,
        'operations': [delete],
      }),
    );
    await expectLater(
      transport.page(snapshot.token, 0),
      throwsA(isA<SyncFailure>()),
    );
    await sync.synchronize(force: true);
    expect(await repo.workout(id), null, reason: sync.status.code);
    expect(
      (await transport.push('{"schema_version":1,"operations":[$stale]}'))
          .results
          .single['error']['code'],
      'retired_id',
    );
    final feed = await transport.pull(null);
    expect(
      feed.changes
          .where((c) => c['aggregate_id'] == id)
          .every((c) => c['redacted'] == true),
      isTrue,
    );
  }, skip: !enabled);

  test('expired signed credentials pause cloud synchronization while logging continues', () async {
    final id = await recorded();
    await sync.close();
    transport.close();
    transport = HttpSyncTransport(
      Uri.parse(endpoint!),
      () async => Platform.environment['DM_SYNC_EXPIRED_TOKEN'],
      allowLoopbackHttp: true,
    );
    sync = SyncCoordinator(repo, transport);
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.authenticationRequired);
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!, index: 1),
    );
    expect(await repo.pendingCount(), 3);
  }, skip: !enabled);

  test('real SQLite restart after delivered request recovers through real HTTP receipt/echo', () async {
    await sync.close();
    await db.close();
    final dir = await Directory.systemTemp.createTemp('connected-restart-');
    final file = File('${dir.path}/db.sqlite');
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    sync = SyncCoordinator(repo, transport);
    final id = await recorded();
    final frozen = (await repo.prepareHead(id))!;
    await transport.push('{"schema_version":1,"operations":[$frozen]}');
    await sync.close();
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, Platform.environment['DM_SYNC_OWNER']!);
    await repo.initialize();
    sync = SyncCoordinator(repo, transport);
    expect(await repo.prepareHead(id), frozen);
    await sync.synchronize(force: true);
    expect((await cloudRoot(id))['revision'], 2);
    expect(await repo.pendingCount(), 0);
    await sync.close();
    await db.close();
    await dir.delete(recursive: true);
  }, skip: !enabled);
  test('account initialization and A to B to A recovery use real authenticated HTTP and separate SQLite stores', () async {
    final configuration = AuthConfiguration(
      supabaseUrl: 'https://identity.daily-motion.test',
      apiUrl: endpoint!,
      publishableKey: 'sb_publishable_synthetic',
      environment: 'development',
      release: false,
    );
    final secure = MemoryProtectedStorage();
    final protected = SecureSessionStorage(secure, configuration.namespace);
    final directory = await Directory.systemTemp.createTemp('http-auth-owner-');
    final a = Platform.environment['DM_SYNC_OWNER']!;
    final b = Platform.environment['DM_SYNC_OWNER_B']!;
    final provider = FakeOtpProvider(
      testSession(
        a,
        DateTime.now().toUtc(),
        token: Platform.environment['DM_SYNC_TOKEN'],
      ),
    );
    final account = AccountController(
      provider: provider,
      gateway: HttpAccountGateway(configuration),
      storage: protected,
      stores: LocalOwnerStores(directory),
      syncTransport: (_, token) =>
          HttpSyncTransport(configuration.api, token, allowLoopbackHttp: true),
    );
    account.foreground(false);
    Future<void> login(String subject, String token) async {
      provider.session = testSession(
        subject,
        DateTime.now().toUtc(),
        token: token,
      );
      await account.requestOtp('synthetic@example.test');
      await account.verifyOtp('123456');
      expect(
        account.state.phase,
        AccountPhase.authenticated,
        reason: account.state.code,
      );
    }

    try {
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      final local = account.local!.repository;
      expect(await local.workouts(), isEmpty);
      final id = await local.startFoundationWorkout();
      await local.commit(
        id,
        'record_set',
        recordPayload((await local.workout(id))!),
      );
      final frozen = await local.prepareHead(id);
      await account.signOut();
      await login(b, Platform.environment['DM_SYNC_TOKEN_B']!);
      expect(await account.local!.repository.workouts(), isEmpty);
      expect(await account.local!.repository.pendingCount(), 0);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect((await account.local!.repository.syncMetadata())['position'], 0);
      await account.signOut();
      account.foreground(false);
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      expect(await account.local!.repository.prepareHead(id), frozen);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect(await account.local!.repository.pendingCount(), 0);
      expect((await cloudRoot(id))['revision'], 2);
    } finally {
      await account.close();
      await directory.delete(recursive: true);
    }
  }, skip: !enabled);
}
