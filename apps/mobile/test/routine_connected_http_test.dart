import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:daily_motion/features/exercise_progress.dart';
import 'package:daily_motion/features/exercise_history_provider.dart';
import 'package:daily_motion/features/measured_progress_provider.dart';
import 'package:daily_motion/features/measured_progress_view.dart';
import 'package:daily_motion/features/sync_provider.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter_test/flutter_test.dart';

import 'exercise_catalog_repository_test.dart' show customDefinition;
import 'repository_test.dart' show recordPayload;
import 'routine_repository_test.dart' show routinePlan;
import 'support/owned_fixture.dart';
import 'support/auth_fakes.dart';

/// The widget framework normally replaces HTTP with a 400-response fake. This
/// connected-only live binding keeps the real client/socket and event-loop
/// paths, including background SQLite reads started by actual widget routes.
class RoutineHttpWidgetsBinding extends LiveTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// Faults surround the actual HTTP transport; the target implementation remains
/// HttpSyncTransport + SyncCoordinator + the real repository/server/database.
class ObservedRoutineTransport extends HttpSyncTransport {
  bool loseResponse = false;
  final requests = <String>[];
  PushResponse3Dto? lostResponse;
  Future<void> Function()? afterResponse;
  Future<void> Function()? beforePull;
  Future<void> Function()? afterPage;
  final manifests = <BootstrapManifest3Dto>[];
  final pageBytes = <int>[];
  ObservedRoutineTransport(super.base, super.accessToken)
    : super(allowLoopbackHttp: true, routineSyncEnabled: true);
  @override
  Future<SyncTransport> beginCycle() async => this;
  @override
  Future<BootstrapManifest3Dto> bootstrapRoutines(String installation) async {
    final result = await super.bootstrapRoutines(installation);
    manifests.add(result);
    return result;
  }

  @override
  Future<SnapshotPage3Dto> routinePage(String token, int index) async {
    final result = await super.routinePage(token, index);
    pageBytes.add(utf8.encode(canonicalJson(result.json)).length);
    await afterPage?.call();
    return result;
  }

  @override
  Future<PullResponse3Dto> pullRoutines(String? cursor) async {
    await beforePull?.call();
    return super.pullRoutines(cursor);
  }

  @override
  Future<PushResponse3Dto> pushRoutines(String body) async {
    requests.add(body);
    final response = await super.pushRoutines(body);
    await afterResponse?.call();
    if (loseResponse) {
      loseResponse = false;
      lostResponse = response;
      throw const SyncFailure('response_lost', retryable: true);
    }
    return response;
  }
}

class RoutinePeer {
  final File file;
  final Uri endpoint;
  final String token;
  final String owner;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  late ObservedRoutineTransport transport;
  late SyncCoordinator sync;
  RoutinePeer(this.file, this.endpoint, this.token, this.owner) {
    _attach();
  }
  void _attach() {
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, owner);
    transport = ObservedRoutineTransport(endpoint, () async => token);
    sync = SyncCoordinator(repo, transport, jitter: () => 0.5);
  }

  Future<void> initialize() async {
    final verified = await transport.initializeAccount();
    expect(verified.ownerId, owner);
    await repo.initialize();
  }

  Future<void> reopen() async {
    await close();
    _attach();
    // Previously verified ownership opens its existing file while offline.
    await repo.initialize();
  }

  Future<void> close() async {
    await sync.close();
    transport.close();
    repo.dispose();
    await db.close();
  }

  Future<void> synchronize() async {
    await sync.synchronize(force: true);
    expect(sync.status.phase, SyncPhase.synchronized, reason: sync.status.code);
  }
}

/// Same client endpoint before/after reconnect. Offline requests lose their TCP
/// connection; online requests forward unchanged to the actual JWT/API server.
class OfflineProxy {
  final Uri target;
  final HttpClient client = HttpClient();
  late HttpServer server;
  bool offline = false;
  bool dropPushBeforeForward = false;
  bool dropPushAfterCommit = false;
  int? refusePushStatus;
  Future<void> Function()? beforePushResponse;
  int beforeDrops = 0;
  int afterDrops = 0;
  final pushes = <String>[];
  OfflineProxy(this.target);
  Uri get endpoint => Uri.parse('http://127.0.0.1:${server.port}');
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => unawaited(_forward(request)));
  }

  Future<void> _forward(HttpRequest request) async {
    try {
      if (offline) {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      final bytes = await request.fold<List<int>>(
        [],
        (body, part) => body..addAll(part),
      );
      final push =
          request.method == 'POST' && request.uri.path == '/v3/sync/push';
      if (push) pushes.add(utf8.decode(bytes));
      if (push && dropPushBeforeForward) {
        dropPushBeforeForward = false;
        beforeDrops++;
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      final refused = refusePushStatus;
      if (push && refused != null) {
        refusePushStatus = null;
        request.response.statusCode = refused;
        request.response.write(
          refused == 503
              ? 'Temporary gateway unavailability'
              : '{"detail":{"code":"rate_limited"}}',
        );
        await request.response.close();
        return;
      }
      final upstream = await client.openUrl(
        request.method,
        target.resolve(request.uri.toString()),
      );
      for (final name in ['authorization', 'x-dm-contract', 'content-type']) {
        final value = request.headers.value(name);
        if (value != null) upstream.headers.set(name, value);
      }
      upstream.add(bytes);
      final response = await upstream.close();
      if (push) await beforePushResponse?.call();
      if (push && dropPushAfterCommit) {
        dropPushAfterCommit = false;
        afterDrops++;
        expect(response.statusCode, 200);
        await response.drain<void>();
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      request.response.statusCode = response.statusCode;
      request.response.headers.contentType = ContentType.json;
      await request.response.addStream(response);
      await request.response.close();
    } on IOException {
      await request.response.close();
    }
  }

  Future<void> close() async {
    await server.close(force: true);
    client.close(force: true);
  }
}

void main() {
  final address = Platform.environment['DM_SYNC_ENDPOINT'];
  final enabled = address != null;
  if (enabled) RoutineHttpWidgetsBinding();
  late Directory directory;
  final peers = <RoutinePeer>[];
  final proxies = <OfflineProxy>[];
  setUp(() async {
    if (!enabled) return;
    directory = await Directory.systemTemp.createTemp('routine-connected-');
  });
  tearDown(() async {
    if (!enabled) return;
    for (final peer in peers.reversed) {
      await peer.close();
    }
    peers.clear();
    for (final proxy in proxies) {
      await proxy.close();
    }
    proxies.clear();
    await deleteOwnedTemporaryDirectory(directory, 'routine-connected-');
  });
  Future<RoutinePeer> peer(
    String label, {
    Uri? endpoint,
    bool otherOwner = false,
    bool retirementOwner = false,
  }) async {
    final suffix = retirementOwner
        ? '_RETIRE'
        : otherOwner
        ? '_B'
        : '';
    final target = RoutinePeer(
      File('${directory.path}/$label.sqlite'),
      endpoint ?? Uri.parse(address!),
      Platform.environment['DM_SYNC_TOKEN$suffix']!,
      Platform.environment['DM_SYNC_OWNER$suffix']!,
    );
    peers.add(target);
    await target.initialize();
    return target;
  }

  Future<Json> cloudRoutine(RoutinePeer device, String id) async {
    final manifest = await device.transport.bootstrapRoutines(
      (await device.repo.syncMetadata())['installation_id'] as String,
    );
    final fragments = <Json>[];
    for (var index = 0; index < manifest.pageCount; index++) {
      fragments.addAll(
        (await device.transport.routinePage(
          manifest.token,
          index,
        )).routines.cast<Json>(),
      );
    }
    final parts = fragments.where((r) => r['aggregate_id'] == id).toList();
    expect(parts, isNotEmpty);
    return {
      ...parts.first,
      'templates': [for (final part in parts) ...part['templates'] as List],
    };
  }

  Future<List<Json>> frozenWorkoutRows(RoutinePeer device) async => [
    for (final row
        in await device.db
            .customSelect(
              'SELECT mutation_id,frozen_body FROM outbox ORDER BY rowid',
            )
            .get())
      row.data,
  ];
  Future<String> completedWorkout(RoutinePeer device) async {
    final id = await device.repo.startFoundationWorkout();
    await device.repo.commit(
      id,
      'record_set',
      recordPayload((await device.repo.workout(id))!),
    );
    await device.repo.commit(id, 'complete_session', {});
    return id;
  }

  test('routine offline reopen, cloud publication, second-device start and measured history', () async {
    final proxy = OfflineProxy(Uri.parse(address!));
    await proxy.start();
    proxies.add(proxy);
    final a = await peer('a', endpoint: proxy.endpoint);
    proxy.offline = true;
    final private = customDefinition();
    await a.repo.saveCustomExercise(definition: private, expectedRevision: 0);
    final curated = curatedExercises[1];
    final prescription = RoutinePlan(
      name: 'Offline cross-device plan',
      exercises: [
        curated.prescription(a.repo.newId, plannedSets: 2),
        private.prescription(a.repo.newId, plannedSets: 1),
        curated.prescription(a.repo.newId, plannedSets: 1),
      ],
    );
    final first = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: prescription,
    );
    expect(a.transport.requests, isEmpty);
    await a.sync.synchronize(force: true);
    a.sync.foreground(
      false,
    ); // Cancel persisted retry scheduling before reopen.
    expect(a.sync.status.phase, SyncPhase.pending);
    expect((await a.repo.routineSyncDetails(first.id))!['server_revision'], 0);
    final installation = (await a.repo.syncMetadata())['installation_id'];
    await a.reopen();
    expect((await a.repo.syncMetadata())['installation_id'], installation);
    expect((await a.repo.routine(first.id))!.templateId, first.templateId);
    final edit = first.plan.json..['name'] = 'Edited offline plan';
    edit['exercises'][0]['sets'][0]['planned']['reps'] = 8;
    final saved = await a.repo.saveRoutine(
      id: first.id,
      expectedRevision: first.localRevision,
      plan: RoutinePlan.fromJson(edit),
    );
    proxy.offline = false;
    await a.synchronize();
    expect(await a.repo.routinePendingCount(), 0);
    final cloud = await cloudRoutine(a, first.id);
    expect(cloud['revision'], 2);
    expect(cloud['current_template_id'], saved.templateId);
    expect((cloud['templates'] as List).first['prescription'], first.plan.json);
    final b = await peer('b');
    expect(
      (await b.repo.syncMetadata())['installation_id'],
      isNot(installation),
    );
    await b.synchronize();
    final restored = (await b.repo.routine(first.id))!;
    expect(restored.templateId, saved.templateId);
    expect(restored.plan.json, saved.plan.json);
    expect(await b.repo.customExercise(private.variantId), isNull);
    expect(
      (await b.repo.exerciseCatalog()).any(
        (e) => e.variantId == private.variantId,
      ),
      isFalse,
    );
    final workout = await b.repo.startRoutine(
      routineId: restored.id,
      templateId: restored.templateId,
      attemptId: b.repo.newId(),
      timezone: 'UTC',
    );
    final started = (await b.repo.workout(workout))!;
    final instances = (started['exercises'] as List).cast<Json>();
    expect(instances.map((e) => e['variant_id']), [
      curated.variantId,
      private.variantId,
      curated.variantId,
    ]);
    expect(
      instances.map((e) => e['session_exercise_id']).toSet(),
      hasLength(3),
    );
    expect(
      instances
          .map((e) => e['session_exercise_id'])
          .toSet()
          .intersection(
            restored.plan.exercises
                .map((e) => e['session_exercise_id'])
                .toSet(),
          ),
      isEmpty,
    );
    expect(allSets(started).every((s) => s['observation'] == null), isTrue);
    final scope = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(b.repo)],
    );
    try {
      await scope.read(workoutsProvider.future);
      final controller = scope.read(workoutsProvider.notifier);
      for (var index = 0; index < instances.length; index++) {
        final e = instances[index];
        expect(
          await controller.record(workout, e, e['sets'][0] as Json, {
            'execution_status': 'completed',
            'load': index == 1 ? '40' : '12.5',
            'unit': 'kg',
            'reps': '${7 + index}',
            'effort': '',
            'effort_scale': 'rir',
          }),
          isTrue,
        );
      }
      await controller.finish(workout);
    } finally {
      scope.dispose();
    }
    await b.synchronize();
    final originalWorkout = (await b.repo.workout(workout))!;
    final frozen = await frozenWorkoutRows(b);
    expect(frozen.every((row) => row['frozen_body'] != null), isTrue);
    await a.synchronize();
    final received = (await a.repo.workout(workout))!;
    expect(received['status'], 'completed');
    expect(
      allSets(received).where((s) => s['observation'] != null),
      hasLength(3),
    );
    final history = buildExerciseHistory(await a.repo.workouts());
    final progress = buildMeasuredProgress(
      history.byExercise[exerciseKey(instances.first)]!,
    );
    final points = progress.repetitions
        .where((p) => p.workoutId == workout)
        .toList();
    expect(points.map((p) => p.repetitions).toSet(), {7, 9});
    expect(points.map((p) => p.exerciseId).toSet(), {
      instances[0]['session_exercise_id'],
      instances[2]['session_exercise_id'],
    });
    expect(points.every((p) => p.load!.original == '12.5'), isTrue);
    final correction = copyJson(allSets(received).first['observation'] as Json)
      ..remove('occurred_at')
      ..remove('recorded_at');
    correction['actual']['reps'] = 11;
    correction['correction_reason'] = 'Explicit historical correction';
    await a.repo.commit(workout, 'correct_set', correction);
    await a.synchronize();
    await b.synchronize();
    final corrected = (await b.repo.workout(workout))!;
    expect(corrected['status'], 'completed');
    expect(allSets(corrected).first['observation']['actual']['reps'], 11);
    expect(
      canonicalJson([
        for (final item in allSets(corrected))
          copyJson(item)..remove('observation'),
      ]),
      canonicalJson([
        for (final item in allSets(originalWorkout))
          copyJson(item)..remove('observation'),
      ]),
      reason: 'An explicit observation correction cannot rewrite prescriptions or set identities.',
    );
    final correctedHistory = buildExerciseHistory(await a.repo.workouts());
    expect(
      buildMeasuredProgress(
            correctedHistory.byExercise[exerciseKey(instances.first)]!,
          ).repetitions
          .where((p) => p.workoutId == workout)
          .map((p) => p.repetitions)
          .toSet(),
      {11, 9},
    );
    final immutableWorkout = canonicalJson(corrected);
    final current = (await a.repo.routine(first.id))!;
    final changed = current.plan.json..['name'] = 'Later plan';
    changed['exercises'][0]['sets'][0]['planned']['reps'] = 14;
    await a.repo.saveCustomExercise(
      definition: private.displayRevision(name: 'Renamed private machine'),
      expectedRevision: 1,
    );
    await a.repo.saveRoutine(
      id: current.id,
      expectedRevision: current.localRevision,
      plan: RoutinePlan.fromJson(changed),
    );
    await a.synchronize();
    await b.synchronize();
    expect(canonicalJson((await b.repo.workout(workout))!), immutableWorkout);
    expect(await frozenWorkoutRows(b), frozen);
    expect(await b.repo.customExercise(private.variantId), isNull);
    expect(
      (await a.repo.routines()).where((r) => r.id == first.id),
      hasLength(1),
    );
    expect(
      (await b.repo.workouts()).where((w) => w['aggregate_id'] == workout),
      hasLength(1),
    );
  }, skip: !enabled);

  test('routine concurrent edits retain both branches and independent workout delivery', () async {
    final a = await peer('a');
    final first = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(),
    );
    await a.synchronize();
    final b = await peer('b');
    await b.synchronize();
    final baseB = (await b.repo.routine(first.id))!;
    final accepted = await a.repo.saveRoutine(
      id: first.id,
      expectedRevision: first.localRevision,
      plan: routinePlan(name: 'Device A accepted'),
    );
    final pending = await b.repo.saveRoutine(
      id: first.id,
      expectedRevision: baseB.localRevision,
      plan: routinePlan(name: 'Device B durable branch'),
    );
    final workout = await completedWorkout(b);
    await a.synchronize();
    await b.sync.synchronize(force: true);
    expect(b.sync.status.phase, SyncPhase.attention);
    expect((await b.repo.routine(first.id))!.templateId, pending.templateId);
    final detail = (await b.repo.routineSyncDetails(first.id))!;
    expect(detail['has_conflict'], 1);
    expect(detail['server_revision'], 2);
    expect(
      jsonDecode(detail['server_shadow'] as String)['current_template_id'],
      accepted.templateId,
    );
    expect(
      await b.repo.pendingCount(),
      0,
      reason: 'Routine conflict must not block a workout root.',
    );
    expect(await b.repo.routinePendingCount(), 1);
    await b.reopen();
    expect((await b.repo.routine(first.id))!.templateId, pending.templateId);
    expect((await b.repo.routineSyncDetails(first.id))!['has_conflict'], 1);
    await a.synchronize();
    expect((await a.repo.workout(workout))!['status'], 'completed');
    expect(
      (await cloudRoutine(a, first.id))['current_template_id'],
      accepted.templateId,
    );
  }, skip: !enabled);

  test('routine response loss and restart preserve frozen requests and newer server shadow', () async {
    final a = await peer('a');
    final saved = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(),
    );
    a.transport.loseResponse = true;
    await a.sync.synchronize(force: true);
    a.sync.foreground(false);
    expect(a.sync.status.phase, SyncPhase.pending);
    final batch = a.transport.requests.single;
    final originalResult = a.transport.lostResponse!.results.single as Json;
    final operation = (jsonDecode(batch) as Json)['operations'][0] as Json;
    expect(await a.repo.prepareRoutineHead(saved.id), canonicalJson(operation));
    final b = await peer('b');
    await b.synchronize();
    final base = (await b.repo.routine(saved.id))!;
    final newer = await b.repo.saveRoutine(
      id: saved.id,
      expectedRevision: base.localRevision,
      plan: routinePlan(name: 'Newer remote revision'),
    );
    await b.synchronize();
    await a.reopen();
    expect(await a.repo.prepareRoutineHead(saved.id), canonicalJson(operation));
    await a.synchronize();
    expect((await a.repo.routine(saved.id))!.templateId, newer.templateId);
    expect((await a.repo.routineSyncDetails(saved.id))!['server_revision'], 2);
    final duplicate = await a.transport.pushRoutines(batch);
    final acknowledgement = duplicate.results.single as Json;
    expect(acknowledgement['status'], 'duplicate');
    expect(acknowledgement['accepted_revision'], 1);
    expect(acknowledgement['accepted_at'], originalResult['accepted_at']);
    await a.repo.installRoutineAcknowledgements(duplicate, [
      operation['mutation_id'] as String,
    ]);
    expect((await a.repo.routine(saved.id))!.templateId, newer.templateId);
    expect((await a.repo.routineSyncDetails(saved.id))!['server_revision'], 2);
    final row = await a.db
        .customSelect('SELECT frozen_body FROM routine_mutations')
        .getSingle();
    expect(row.read<String>('frozen_body'), canonicalJson(operation));
  }, skip: !enabled);

  test(
    'routine bootstrap activation preserves an edit committed during download',
    () async {
      final a = await peer('a');
      final first = await a.repo.saveRoutine(
        id: a.repo.newId(),
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await a.synchronize();
      final b = await peer('b');
      await b.synchronize();
      final manifest = await b.transport.bootstrapRoutines(
        (await b.repo.syncMetadata())['installation_id'] as String,
      );
      await b.repo.stageRoutineBootstrap(manifest);
      final base = (await b.repo.routine(first.id))!;
      // Select the coordinator's existing staged-bootstrap retry path. Hold
      // a real HTTP page response before delivery to staging, so the save is
      // concurrent with an outstanding page future, not after all downloads.
      await b.repo.recordSyncFailure('bootstrap_required');
      final pageArrived = Completer<void>();
      final releasePage = Completer<void>();
      late SavedRoutine local;
      var activationObserved = false;
      b.transport.afterPage = () async {
        if (!pageArrived.isCompleted) {
          pageArrived.complete();
          await releasePage.future;
        }
      };
      b.transport.beforePull = () async {
        activationObserved = true;
        expect(await b.repo.stagedRoutineBootstrap(), isNull);
        expect((await b.repo.routine(first.id))!.templateId, local.templateId);
        expect(await b.repo.routinePendingCount(), 1);
        expect(b.transport.requests, isEmpty);
        final frozen =
            jsonDecode((await b.repo.prepareRoutineHead(first.id))!) as Json;
        expect(frozen['expected_revision'], 1);
        expect(frozen['payload']['template_id'], local.templateId);
        throw const SyncFailure('download_edit_observed', retryable: true);
      };
      final cycle = b.sync.synchronize(force: true);
      try {
        await pageArrived.future.timeout(const Duration(seconds: 20));
        expect(await b.repo.stagedPageIndices(), isEmpty);
        local = await b.repo.saveRoutine(
          id: first.id,
          expectedRevision: base.localRevision,
          plan: routinePlan(name: 'Saved during bootstrap'),
        );
      } finally {
        releasePage.complete();
      }
      await cycle.timeout(const Duration(seconds: 20));
      b.sync.foreground(false);
      expect(activationObserved, true);
      expect(b.sync.status.code, 'download_edit_observed');
      expect((await b.repo.routine(first.id))!.templateId, local.templateId);
      expect(await b.repo.routinePendingCount(), 1);
      await b.reopen();
      await b.synchronize();
      expect(
        (await cloudRoutine(b, first.id))['current_template_id'],
        local.templateId,
      );
    },
    skip: !enabled,
  );

  test('routine post-activation failure preserves installed state and both pending outboxes after restart', () async {
    final a = await peer('a');
    final remote = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'Accepted before B bootstrap'),
    );
    await a.synchronize();
    final b = await peer('b');
    final local = await b.repo.saveRoutine(
      id: b.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'Pending before B bootstrap'),
    );
    final frozenRoutine = await b.repo.prepareRoutineHead(local.id);
    final workout = await completedWorkout(b);
    final frozenWorkout = await b.repo.prepareHead(workout);
    final installation = (await b.repo.syncMetadata())['installation_id'];
    var boundaryReached = false;
    Json? activatedMetadata;
    b.transport.beforePull = () async {
      // This is the coordinator's first pull after real HTTP bootstrap and
      // successful SQLite activation, before any queued upload is sent.
      expect(boundaryReached, false);
      boundaryReached = true;
      expect(b.transport.manifests, hasLength(1));
      final manifest = b.transport.manifests.single;
      expect(await b.repo.stagedRoutineBootstrap(), isNull);
      expect((await b.repo.routine(remote.id))!.templateId, remote.templateId);
      expect(
        (await b.repo.routineSyncDetails(remote.id))!['server_revision'],
        1,
      );
      activatedMetadata = await b.repo.syncMetadata();
      expect(activatedMetadata!['cursor'], manifest.cursor);
      expect(activatedMetadata!['position'], manifest.position);
      expect(await b.repo.prepareRoutineHead(local.id), frozenRoutine);
      expect(await b.repo.prepareHead(workout), frozenWorkout);
      throw const SyncFailure('post_activation_disconnect', retryable: true);
    };
    await b.sync.synchronize(force: true);
    b.sync.foreground(false);
    expect(boundaryReached, true);
    expect(b.sync.status.phase, SyncPhase.pending);
    expect(b.sync.status.code, 'post_activation_disconnect');
    expect(b.transport.requests, isEmpty);
    await b.reopen();
    final reopened = await b.repo.syncMetadata();
    expect(reopened['installation_id'], installation);
    for (final field in ['cursor', 'position', 'generation', 'erasure_epoch']) {
      expect(reopened[field], activatedMetadata![field]);
    }
    expect(await b.repo.stagedRoutineBootstrap(), isNull);
    expect((await b.repo.routine(remote.id))!.templateId, remote.templateId);
    expect((await b.repo.routine(local.id))!.templateId, local.templateId);
    expect(await b.repo.prepareRoutineHead(local.id), frozenRoutine);
    expect(await b.repo.prepareHead(workout), frozenWorkout);
    expect(await b.repo.routinePendingCount(), 1);
    expect(await b.repo.pendingCount(), 3);
    await b.synchronize();
    expect(await b.repo.routinePendingCount(), 0);
    expect(await b.repo.pendingCount(), 0);
    final cloud = await cloudRoutine(b, local.id);
    expect(cloud['revision'], 1);
    expect(cloud['current_template_id'], local.templateId);
    expect(cloud['templates'], hasLength(1));
    expect(
      (await b.repo.workouts()).where((row) => row['aggregate_id'] == workout),
      hasLength(1),
    );
    expect(
      (await b.repo.routines()).where((row) => row.id == remote.id),
      hasLength(1),
    );
  }, skip: !enabled);

  test('routine owner isolation and unavailable capability preserve private local work', () async {
    final a = await peer('a');
    final b = await peer('other-owner', otherOwner: true);
    final secret = await b.repo.saveRoutine(
      id: b.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'Other owner private plan'),
    );
    await b.synchronize();
    await a.synchronize();
    expect(await a.repo.routine(secret.id), isNull);
    final body = {
      'schema_version': 3,
      'operations': [
        {
          'mutation_id': a.repo.newId(),
          'installation_id': (await a.repo.syncMetadata())['installation_id'],
          'aggregate_type': 'routine',
          'aggregate_id': secret.id,
          'expected_revision': 1,
          'command': 'publish_template',
          'occurred_at': '2026-10-29T12:00:00Z',
          'recorded_at': '2026-10-29T12:00:00Z',
          'payload': {
            'template_id': a.repo.newId(),
            'predecessor_template_id': secret.templateId,
            'prescription': secret.plan.json,
          },
        },
      ],
    };
    final denied = await a.transport.pushRoutines(canonicalJson(body));
    expect((denied.results.single as Json)['status'], 'conflict');
    expect((denied.results.single as Json)['current_revision'], 0);
    expect(
      (await cloudRoutine(b, secret.id))['current_template_id'],
      secret.templateId,
    );
    final own = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'Own private plan'),
    );
    await a.synchronize();
    final local = await a.repo.saveRoutine(
      id: own.id,
      expectedRevision: own.localRevision,
      plan: routinePlan(name: 'Retain unsupported pending edit'),
    );
    final legacy = HttpSyncTransport(
      a.endpoint,
      () async => a.token,
      allowLoopbackHttp: true,
    );
    final oldCoordinator = SyncCoordinator(a.repo, legacy);
    try {
      final cursor = (await a.repo.syncMetadata())['cursor'];
      await oldCoordinator.synchronize(force: true);
      expect(oldCoordinator.status.phase, SyncPhase.attention);
      expect(oldCoordinator.status.code, 'upgrade_required');
      expect((await a.repo.syncMetadata())['cursor'], cursor);
      expect((await a.repo.routine(own.id))!.templateId, local.templateId);
      expect(await a.repo.routinePendingCount(), 1);
    } finally {
      await oldCoordinator.close();
      legacy.close();
    }
    await a.repo.signOut();
    await expectLater(
      a.repo.routine(own.id),
      throwsA(isA<WorkoutValidation>()),
    );
    await a.repo.unlockVerifiedOwner(a.owner);
    expect((await a.repo.routine(own.id))!.templateId, local.templateId);
  }, skip: !enabled);

  test('routine TCP interruptions and acknowledgement rollback recover exact frozen publications', () async {
    for (final boundary in [
      'before_forward',
      'after_commit',
      'ack_transaction',
    ]) {
      final proxy = OfflineProxy(Uri.parse(address!));
      proxies.add(proxy);
      await proxy.start();
      final a = await peer(boundary, endpoint: proxy.endpoint);
      await a.synchronize();
      final saved = await a.repo.saveRoutine(
        id: a.repo.newId(),
        expectedRevision: 0,
        plan: routinePlan(name: boundary),
      );
      final frozen = (await a.repo.prepareRoutineHead(saved.id))!;
      final operation = jsonDecode(frozen) as Json;
      if (boundary == 'before_forward') proxy.dropPushBeforeForward = true;
      if (boundary == 'after_commit') proxy.dropPushAfterCommit = true;
      if (boundary == 'ack_transaction') {
        await a.db.customStatement(
          "CREATE TRIGGER fail_ack BEFORE UPDATE ON routine_mutations WHEN new.state='acknowledged' BEGIN SELECT RAISE(ABORT,'controlled ack transaction loss'); END",
        );
      }
      await a.sync.synchronize(force: true);
      a.sync.foreground(false);
      expect(a.sync.status.phase, isNot(SyncPhase.synchronized));
      expect(await a.repo.routinePendingCount(), 1);
      expect(await a.repo.prepareRoutineHead(saved.id), frozen);
      expect(
        (await a.repo.routineSyncDetails(saved.id))!['server_revision'],
        0,
      );
      final observer = await peer('observer-$boundary');
      final feed = await observer.transport.pullRoutines(null);
      final published = feed.changes.where(
        (c) => c['operation']?['mutation_id'] == operation['mutation_id'],
      );
      expect(published, hasLength(boundary == 'before_forward' ? 0 : 1));
      if (boundary == 'before_forward') expect(proxy.beforeDrops, 1);
      if (boundary == 'after_commit') expect(proxy.afterDrops, 1);
      if (boundary == 'ack_transaction') {
        await a.db.customStatement('DROP TRIGGER fail_ack');
      }
      await a.reopen();
      expect(await a.repo.prepareRoutineHead(saved.id), frozen);
      await a.synchronize();
      final cloud = await cloudRoutine(a, saved.id);
      expect(cloud['revision'], 1);
      expect((cloud['templates'] as List), hasLength(1));
      expect(cloud['current_template_id'], saved.templateId);
      final sent = proxy.pushes
          .expand(
            (body) => (jsonDecode(body)['operations'] as List).cast<Json>(),
          )
          .where((op) => op['mutation_id'] == operation['mutation_id'])
          .map(canonicalJson)
          .toSet();
      expect(sent, {frozen});
      final duplicate = await a.transport.pushRoutines(
        '{"schema_version":3,"operations":[$frozen]}',
      );
      expect((duplicate.results.single as Json)['status'], 'duplicate');
      expect((duplicate.results.single as Json)['accepted_revision'], 1);
      expect(await a.repo.routinePendingCount(), 0);
    }
  }, skip: !enabled);

  test(
    'routine HTTP failures and partial sends retain mixed frozen heads through restart',
    () async {
      for (final boundary in ['partial_send', 'http_503', 'rate_limited']) {
        final proxy = OfflineProxy(Uri.parse(address!));
        proxies.add(proxy);
        await proxy.start();
        final a = await peer('mixed-$boundary', endpoint: proxy.endpoint);
        await a.synchronize();
        final saved = await a.repo.saveRoutine(
          id: a.repo.newId(),
          expectedRevision: 0,
          plan: routinePlan(name: boundary),
        );
        final routineBody = (await a.repo.prepareRoutineHead(saved.id))!;
        final mutation = jsonDecode(routineBody)['mutation_id'];
        final workout = await completedWorkout(a);
        final workoutBody = (await a.repo.prepareHead(workout))!;
        if (boundary == 'partial_send') {
          final body = utf8.encode(
            '{"schema_version":3,"operations":[$routineBody,$workoutBody]}',
          );
          final socket = await Socket.connect(a.endpoint.host, a.endpoint.port);
          socket.add(
            utf8.encode(
              'POST /v3/sync/push HTTP/1.1\r\nHost: ${a.endpoint.host}\r\n'
              'Authorization: Bearer ${a.token}\r\nX-DM-Contract: 3\r\n'
              'Content-Type: application/json\r\nContent-Length: ${body.length}\r\n\r\n',
            ),
          );
          socket.add(body.sublist(0, body.length ~/ 2));
          await socket.flush();
          socket.destroy();
          proxy.offline = true;
        } else {
          proxy.refusePushStatus = boundary == 'http_503' ? 503 : 429;
        }
        await a.sync.synchronize(force: true);
        a.sync.foreground(false);
        expect(a.sync.status.phase, SyncPhase.pending);
        expect(
          a.sync.status.cloudInterruptionLabel,
          'Cloud sync temporarily unavailable',
        );
        expect(await a.repo.remoteDisabled(), isFalse);
        expect(await a.repo.prepareRoutineHead(saved.id), routineBody);
        expect(await a.repo.prepareHead(workout), workoutBody);
        expect(await a.repo.pendingCount(), 3);
        expect(await a.repo.routinePendingCount(), 1);
        expect(
          (await a.repo.routineSyncDetails(saved.id))!['server_revision'],
          0,
        );
        final observer = await peer('failure-observer-$boundary');
        String? cursor;
        var accepted = 0;
        while (true) {
          final feed = await observer.transport.pullRoutines(cursor);
          accepted += feed.changes
              .where((c) => c['operation']?['mutation_id'] == mutation)
              .length;
          if (!feed.hasMore) break;
          cursor = feed.nextCursor;
        }
        expect(
          accepted,
          0,
          reason: 'A partial body or refused gateway request cannot commit.',
        );
        final edited = await a.repo.saveRoutine(
          id: saved.id,
          expectedRevision: saved.localRevision,
          plan: routinePlan(name: 'Local edit during $boundary'),
        );
        expect(await a.repo.prepareRoutineHead(saved.id), routineBody);
        proxy.offline = false;
        await a.reopen();
        expect(await a.repo.prepareHead(workout), workoutBody);
        expect(await a.repo.prepareRoutineHead(saved.id), routineBody);
        await a.synchronize();
        expect(
          (await cloudRoutine(a, saved.id))['current_template_id'],
          edited.templateId,
        );
        expect((await cloudRoutine(a, saved.id))['revision'], 2);
        expect((await a.repo.workout(workout))!['status'], 'completed');
        expect(await a.repo.pendingCount(), 0);
        expect(await a.repo.routinePendingCount(), 0);
        final sent = proxy.pushes
            .expand(
              (body) => (jsonDecode(body)['operations'] as List).cast<Json>(),
            )
            .where((op) => op['mutation_id'] == mutation)
            .map(canonicalJson)
            .toSet();
        expect(sent, {routineBody});
        final duplicate = await a.transport.pushRoutines(
          '{"schema_version":3,"operations":[$routineBody]}',
        );
        expect(duplicate.results.single['status'], 'duplicate');
        expect(duplicate.results.single['accepted_revision'], 1);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('routine local edit during a held HTTP acknowledgement preserves both publications', () async {
    final proxy = OfflineProxy(Uri.parse(address!));
    proxies.add(proxy);
    await proxy.start();
    final a = await peer('held-ack-a', endpoint: proxy.endpoint);
    await a.synchronize();
    final first = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'First in-flight plan'),
    );
    final frozen = (await a.repo.prepareRoutineHead(first.id))!;
    final firstMutation = jsonDecode(frozen)['mutation_id'];
    final workout = await completedWorkout(a);
    late SavedRoutine edited;
    var editedWhileHeld = false;
    proxy.beforePushResponse = () async {
      proxy.beforePushResponse = null;
      expect(a.sync.status.phase, SyncPhase.syncing);
      expect(
        (await a.repo.routineSyncDetails(first.id))!['server_revision'],
        0,
      );
      edited = await a.repo.saveRoutine(
        id: first.id,
        expectedRevision: first.localRevision,
        plan: routinePlan(
          name: 'Edit saved while HTTP acknowledgement is held',
        ),
      );
      expect(await a.repo.prepareRoutineHead(first.id), frozen);
      expect(await a.repo.routinePendingCount(), 2);
      editedWhileHeld = true;
    };
    await a.synchronize();
    expect(editedWhileHeld, isTrue);
    final cloud = await cloudRoutine(a, first.id);
    expect(cloud['revision'], 2);
    expect(cloud['current_template_id'], edited.templateId);
    expect(cloud['templates'][0]['template_id'], first.templateId);
    expect(cloud['templates'][0]['prescription'], first.plan.json);
    expect(cloud['templates'][1]['predecessor_template_id'], first.templateId);
    expect(cloud['templates'][1]['prescription'], edited.plan.json);
    final sent = proxy.pushes
        .expand((body) => (jsonDecode(body)['operations'] as List).cast<Json>())
        .where((op) => op['mutation_id'] == firstMutation)
        .map(canonicalJson)
        .toList();
    expect(sent, [frozen]);
    expect((await a.repo.workout(workout))!['status'], 'completed');
    expect(await a.repo.pendingCount(), 0);
    expect(await a.repo.routinePendingCount(), 0);
    final b = await peer('held-ack-b');
    await b.synchronize();
    expect((await b.repo.routine(first.id))!.templateId, edited.templateId);
    expect((await b.repo.workout(workout))!['status'], 'completed');
    await a.reopen();
    expect((await a.repo.routine(first.id))!.templateId, edited.templateId);
    expect(await a.repo.routinePendingCount(), 0);
  }, skip: !enabled);

  test('routine expired JWT preserves offline edits and resumes the original publication chain', () async {
    final a = await peer('expired');
    await a.synchronize();
    final first = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(),
    );
    final frozen = (await a.repo.prepareRoutineHead(first.id))!;
    final expired = ObservedRoutineTransport(
      a.endpoint,
      () async => Platform.environment['DM_SYNC_EXPIRED_TOKEN'],
    );
    final unauthorized = SyncCoordinator(a.repo, expired);
    try {
      await unauthorized.synchronize(force: true);
      expect(unauthorized.status.phase, SyncPhase.authenticationRequired);
      expect(expired.requests, isEmpty);
      final edited = await a.repo.saveRoutine(
        id: first.id,
        expectedRevision: first.localRevision,
        plan: routinePlan(name: 'Still saved while signed token expired'),
      );
      expect(await a.repo.routinePendingCount(), 2);
      expect(await a.repo.prepareRoutineHead(first.id), frozen);
      await a.reopen();
      await a.synchronize();
      final cloud = await cloudRoutine(a, first.id);
      expect(cloud['current_template_id'], edited.templateId);
      expect(cloud['revision'], 2);
      expect(cloud['templates'][0]['template_id'], first.templateId);
      expect(await a.repo.routinePendingCount(), 0);
    } finally {
      await unauthorized.close();
      expired.close();
    }
  }, skip: !enabled);

  test('routine in-flight account sign-out drains A before B and restores A with verified ownership', () async {
    final configuration = AuthConfiguration(
      supabaseUrl: 'https://identity.daily-motion.test',
      apiUrl: address!,
      publishableKey: 'sb_publishable_synthetic',
      environment: 'development',
      release: false,
    );
    final a = Platform.environment['DM_SYNC_OWNER']!;
    final b = Platform.environment['DM_SYNC_OWNER_B']!;
    final provider = FakeOtpProvider(
      testSession(
        a,
        DateTime.now().toUtc(),
        token: Platform.environment['DM_SYNC_TOKEN'],
      ),
    );
    final transports = <String, ObservedRoutineTransport>{};
    final account = AccountController(
      provider: provider,
      gateway: HttpAccountGateway(configuration),
      storage: SecureSessionStorage(
        MemoryProtectedStorage(),
        configuration.namespace,
      ),
      stores: LocalOwnerStores(directory),
      syncTransport: (owner, token) {
        final transport = ObservedRoutineTransport(configuration.api, token);
        transports[owner] = transport;
        return transport;
      },
    );
    account.foreground(false);
    Future<void> login(String owner, String token) async {
      provider.session = testSession(
        owner,
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

    final responseArrived = Completer<void>();
    final releaseResponse = Completer<void>();
    try {
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      final original = account.local!.repository;
      final saved = await original.saveRoutine(
        id: original.newId(),
        expectedRevision: 0,
        plan: routinePlan(name: 'A private in-flight routine'),
      );
      final frozen = (await original.prepareRoutineHead(saved.id))!;
      final transport = transports[a]!;
      transport.afterResponse = () async {
        transport.afterResponse = null;
        responseArrived.complete();
        await releaseResponse.future;
      };
      account.foreground(true);
      final running = account.coordinator!.synchronize();
      await responseArrived.future.timeout(const Duration(seconds: 20));
      final signingOut = account.signOut();
      expect(account.state.phase, AccountPhase.signingOut);
      releaseResponse.complete();
      await running;
      await signingOut;
      expect(account.state.phase, AccountPhase.signedOut);
      expect(account.local, isNull);
      account.foreground(false);
      await login(b, Platform.environment['DM_SYNC_TOKEN_B']!);
      expect(await account.local!.repository.routine(saved.id), isNull);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect(await account.local!.repository.routine(saved.id), isNull);
      expect(
        transports[b]!.requests.every(
          (body) => !(jsonDecode(body)['operations'] as List).any(
            (op) => op['aggregate_id'] == saved.id,
          ),
        ),
        isTrue,
      );
      await account.signOut();
      account.foreground(false);
      await login(a, Platform.environment['DM_SYNC_TOKEN']!);
      final restored = account.local!.repository;
      expect((await restored.routine(saved.id))!.templateId, saved.templateId);
      final row = await account.local!.database
          .customSelect(
            "SELECT frozen_body FROM routine_mutations WHERE routine_id='${saved.id}'",
          )
          .getSingle();
      expect(row.read<String>('frozen_body'), frozen);
      account.foreground(true);
      await account.coordinator!.synchronize(force: true);
      expect(await restored.routinePendingCount(), 0);
      expect(
        (await restored.routineSyncDetails(saved.id))!['server_revision'],
        1,
      );
    } finally {
      if (!releaseResponse.isCompleted) releaseResponse.complete();
      await account.close();
    }
  }, skip: !enabled);

  testWidgets(
    'routine real HTTP restore renders History, measured charts and exact source workout routes',
    (tester) async {
      ProviderContainer? ui;
      ProviderSubscription<AsyncValue<MeasuredProgress>>? chartLease;
      late RoutinePeer a;
      late String workout;
      late Json recorded;
      void stage(String value) {
        File('${directory.path}/ui-route-stages.log')
            .writeAsStringSync('$value\n', mode: FileMode.append);
        debugPrintSynchronously('Connected UI stage: $value');
      }

      try {
        final prepared = await tester.runAsync(() async {
          stage('network-setup');
          a = await peer('ui-a');
          final plan = RoutinePlan(
            name: 'Cloud-restored route workout',
            exercises: [
              curatedExercises.first.prescription(a.repo.newId, plannedSets: 1),
            ],
          );
          final saved = await a.repo.saveRoutine(
            id: a.repo.newId(),
            expectedRevision: 0,
            plan: plan,
          );
          await a.synchronize();
          final b = await peer('ui-b');
          await b.synchronize();
          final restored = (await b.repo.routine(saved.id))!;
          workout = await b.repo.startRoutine(
            routineId: restored.id,
            templateId: restored.templateId,
            attemptId: b.repo.newId(),
            timezone: 'UTC',
          );
          final state = (await b.repo.workout(workout))!;
          await b.repo.commit(
            workout,
            'record_set',
            recordPayload(state, reps: 8),
          );
          await b.repo.commit(workout, 'complete_session', {});
          await b.synchronize();
          await a.synchronize();
          a.sync.foreground(false);
          recorded = (await a.repo.workout(workout))!;
          expect(recorded['status'], 'completed');
          stage('received-completed-workout');
          ui = ProviderContainer(
            overrides: [
              repositoryProvider.overrideWithValue(a.repo),
              syncCoordinatorProvider.overrideWithValue(a.sync),
            ],
          );
          stage('read-workouts');
          await ui!
              .read(workoutsProvider.future)
              .timeout(const Duration(seconds: 20));
          stage('read-exercise-history');
          await ui!
              .read(exerciseHistoryProvider.future)
              .timeout(const Duration(seconds: 20));
          final identity = exerciseKey(
            (recorded['exercises'] as List).first as Json,
          );
          chartLease = ui!.listen(
            measuredProgressProvider(identity),
            (_, _) {},
          );
          stage('read-measured-progress');
          await ui!
              .read(measuredProgressProvider(identity).future)
              .timeout(const Duration(seconds: 20));
          stage('prepared');
          return true;
        });
        expect(
          prepared,
          isTrue,
          reason: 'Actual HTTP/SQLite setup must finish before rendering.',
        );
        stage('mount-home');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ui!,
            child: MaterialApp(
              theme: motionTheme(Brightness.light),
              home: const HomeScreen(
                syntheticFixture: false,
                localRoutinesEnabled: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        stage('open-history');
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        final history = find.byKey(ValueKey('history-$workout'));
        await tester.scrollUntilVisible(
          history,
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
        await tester.tap(history);
        await tester.pumpAndSettle();
        stage('read-history-timer');
        await tester.runAsync(
          () => a.repo
              .timerDeadline(workout)
              .timeout(const Duration(seconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).sessionId,
          workout,
        );
        expect(find.textContaining('8 reps'), findsWidgets);
        stage('history-rendered');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Progress').last);
        stage('open-progress');
        await tester.pumpAndSettle();
        final exercise = (recorded['exercises'] as List).first as Json;
        final variant = find.byKey(ValueKey(exerciseKey(exercise)));
        await tester.scrollUntilVisible(
          variant,
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
        await tester.tap(variant);
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
        await tester.tap(find.text('Measured charts'));
        stage('open-measured-charts');
        await tester.pumpAndSettle();
        expect(find.byType(MeasuredScatter), findsOneWidget);
        final source = find.byKey(
          ValueKey((
            'measured-point',
            (
              workout,
              exercise['session_exercise_id'] as String,
              exercise['sets'][0]['set_id'] as String,
            ),
          )),
        );
        await tester.scrollUntilVisible(
          source,
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
        expect(
          find.descendant(of: source, matching: find.textContaining('8 reps')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: source, matching: find.byType(ListTile)),
        );
        await tester.pumpAndSettle();
        stage('read-source-timer');
        await tester.runAsync(
          () => a.repo
              .timerDeadline(workout)
              .timeout(const Duration(seconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<WorkoutScreen>(find.byType(WorkoutScreen)).sessionId,
          workout,
        );
        expect(find.textContaining('8 reps'), findsWidgets);
        expect(tester.takeException(), isNull);
        stage('source-rendered');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        chartLease?.close();
        ui?.dispose();
      }
    },
    skip: !enabled,
  );

  test('routine authoritative retirement purges local planning and rejects stale JWT resurrection', () async {
    final device = await peer('retired-owner', retirementOwner: true);
    final custom = customDefinition();
    await device.repo.saveCustomExercise(
      definition: custom,
      expectedRevision: 0,
    );
    final first = await device.repo.saveRoutine(
      id: device.repo.newId(),
      expectedRevision: 0,
      plan: RoutinePlan(
        name: 'Retired private plan',
        exercises: [custom.prescription(device.repo.newId, plannedSets: 1)],
      ),
    );
    await device.synchronize();
    final snapshot = await device.transport.bootstrapRoutines(
      (await device.repo.syncMetadata())['installation_id'] as String,
    );
    final edited = await device.repo.saveRoutine(
      id: first.id,
      expectedRevision: first.localRevision,
      plan: routinePlan(name: 'Pending private alternative'),
    );
    final frozen = (await device.repo.prepareRoutineHead(edited.id))!;
    final workout = await device.repo.startFoundationWorkout();
    final set =
        allSets((await device.repo.workout(workout))!).first['set_id']
            as String;
    await device.repo.saveDraft(set, {'load': '62.5', 'reps': '7'});
    await device.repo.prepareHead(workout);
    expect(
      await device.db
          .customSelect('SELECT * FROM routine_cloud_templates')
          .get(),
      isNotEmpty,
    );
    expect(await device.repo.routinePendingCount(), 1);
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        device.endpoint.resolve('/__test__/retire'),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${device.token}',
      );
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
    await device.sync.synchronize(force: true);
    expect(device.sync.status.phase, SyncPhase.accountDisabled);
    expect(await device.repo.remoteDisabled(), isTrue);
    for (final table in [
      'routines',
      'workout_templates',
      'routine_mutations',
      'routine_sync_state',
      'routine_cloud_templates',
      'custom_exercise_definitions',
      'sessions',
      'outbox',
      'drafts',
      'rest_timers',
      'bootstrap_pages',
      'bootstrap_stage',
    ]) {
      expect(
        await device.db.customSelect('SELECT * FROM $table').get(),
        isEmpty,
        reason: '$table must not retain retired private payloads',
      );
    }
    await expectLater(
      device.repo.routine(first.id),
      throwsA(isA<WorkoutValidation>()),
    );
    await expectLater(
      device.transport.pushRoutines(
        '{"schema_version":3,"operations":[$frozen]}',
      ),
      throwsA(
        isA<SyncFailure>().having((e) => e.code, 'code', 'account_inactive'),
      ),
    );
    await expectLater(
      device.transport.routinePage(snapshot.token, 0),
      throwsA(isA<SyncFailure>()),
    );
    await expectLater(
      device.transport.initializeAccount(),
      throwsA(
        isA<SyncFailure>().having((e) => e.code, 'code', 'account_inactive'),
      ),
    );
    await expectLater(device.reopen(), throwsA(isA<WorkoutValidation>()));
    expect(await device.repo.remoteDisabled(), isTrue);
    await expectLater(
      device.repo.unlockVerifiedOwner(device.owner),
      throwsA(isA<WorkoutValidation>()),
    );
  }, skip: !enabled);

  test('routine valid workout erasure preserves planning roots on both installations', () async {
    final a = await peer('erasure-a', otherOwner: true);
    await a.synchronize();
    final routine = await a.repo.saveRoutine(
      id: a.repo.newId(),
      expectedRevision: 0,
      plan: routinePlan(name: 'Retained plan'),
    );
    final workout = await completedWorkout(a);
    await a.synchronize();
    final b = await peer('erasure-b', otherOwner: true);
    await b.synchronize();
    expect((await b.repo.routine(routine.id))!.templateId, routine.templateId);
    final state = (await a.repo.workout(workout))!;
    final stamp = DateTime.now().toUtc().toIso8601String();
    final deletion = {
      'mutation_id': a.repo.newId(),
      'installation_id': (await a.repo.syncMetadata())['installation_id'],
      'aggregate_type': 'workout_session',
      'aggregate_id': workout,
      'expected_revision': state['revision'],
      'command': 'delete_session',
      'occurred_at': stamp,
      'recorded_at': stamp,
      'payload': <String, dynamic>{},
    };
    final response = await a.transport.pushRoutines(
      canonicalJson({
        'schema_version': 3,
        'operations': [deletion],
      }),
    );
    expect(response.results.single['status'], 'accepted');
    await a.synchronize();
    await b.synchronize();
    for (final device in [a, b]) {
      expect(await device.repo.workout(workout), isNull);
      expect(
        (await device.repo.routine(routine.id))!.templateId,
        routine.templateId,
      );
      expect(
        (await device.repo.routineSyncDetails(routine.id))!['has_conflict'],
        0,
      );
      expect(
        (await device.repo.routineSyncDetails(routine.id))!['server_revision'],
        1,
      );
      final retired =
          (await device.db.customSelect('SELECT id FROM retired_ids').get())
              .map((row) => row.read<String>('id'))
              .toSet();
      expect(retired, contains(workout));
      expect(retired, isNot(contains(routine.id)));
      expect(retired, isNot(contains(routine.templateId)));
      expect(await device.repo.routinePendingCount(), 0);
    }
  }, skip: !enabled);

  test(
    'routine hundreds-of-roots offline journal restores paged immutable history with stable variants',
    () async {
      const count = 500;
      final proxy = OfflineProxy(Uri.parse(address!));
      proxies.add(proxy);
      await proxy.start();
      final a = await peer(
        'volume-a',
        endpoint: proxy.endpoint,
        otherOwner: true,
      );
      proxy.offline = true;
      final rssBefore = ProcessInfo.currentRss;
      final savedTemplates = <String, List<String>>{};
      final prescriptions = <String, String>{};
      final saveWatch = Stopwatch()..start();
      final localMeasurements = <Json>[];
      for (var index = 0; index < count; index++) {
        final id = a.repo.newId();
        var saved = await a.repo.saveRoutine(
          id: id,
          expectedRevision: 0,
          plan: RoutinePlan(
            name: 'Bulk $index revision 1',
            exercises: [
              for (final definition in curatedExercises.take(2))
                definition.prescription(a.repo.newId, plannedSets: 3),
            ],
          ),
        );
        savedTemplates[id] = [saved.templateId];
        prescriptions[saved.templateId] = canonicalJson(saved.plan.json);
        for (var revision = 2; revision <= 3; revision++) {
          final next = saved.plan.json
            ..['name'] = 'Bulk $index revision $revision';
          next['exercises'][0]['sets'][0]['planned']['reps'] = 5 + revision;
          saved = await a.repo.saveRoutine(
            id: id,
            expectedRevision: saved.localRevision,
            plan: RoutinePlan.fromJson(next),
          );
          savedTemplates[id]!.add(saved.templateId);
          prescriptions[saved.templateId] = canonicalJson(saved.plan.json);
        }
        if ([1, 20, 100, 500].contains(index + 1)) {
          final readWatch = Stopwatch()..start();
          final read = await a.repo.routines();
          readWatch.stop();
          expect(read, hasLength(index + 1));
          localMeasurements.add({
            'roots': index + 1,
            'templates': (index + 1) * 3,
            'cumulative_save_ms': saveWatch.elapsedMilliseconds,
            'routine_read_ms': readWatch.elapsedMilliseconds,
            'process_rss_bytes': ProcessInfo.currentRss,
          });
        }
      }
      saveWatch.stop();
      expect(a.transport.requests, isEmpty);
      expect(await a.repo.routinePendingCount(), count * 3);
      final installation = (await a.repo.syncMetadata())['installation_id'];
      await a.reopen();
      expect((await a.repo.syncMetadata())['installation_id'], installation);
      expect((await a.repo.routines()).length, count);
      for (final restored in await a.repo.routines()) {
        expect(restored.templateId, savedTemplates[restored.id]!.last);
      }
      proxy.offline = false;
      final syncWatch = Stopwatch()..start();
      await a.synchronize();
      syncWatch.stop();
      expect(await a.repo.routinePendingCount(), 0);
      final b = await peer('volume-b', otherOwner: true);
      final bootstrapWatch = Stopwatch()..start();
      await b.synchronize();
      bootstrapWatch.stop();
      final imported = (await b.repo.routines())
          .where((r) => savedTemplates.containsKey(r.id))
          .toList();
      expect(imported, hasLength(count));
      expect(imported.map((r) => r.id).toSet(), savedTemplates.keys.toSet());
      for (final routine in imported) {
        expect(routine.templateId, savedTemplates[routine.id]!.last);
        expect(
          routine.localRevision,
          1,
          reason: 'The first imported editor CAS is independent of accepted server revision 3.',
        );
        expect(
          canonicalJson(routine.plan.json),
          prescriptions[routine.templateId],
        );
        expect(
          routine.plan.exercises.map((e) => e['variant_id']).toList(),
          curatedExercises.take(2).map((d) => d.variantId).toList(),
        );
      }
      final cache = await b.db
          .customSelect(
            'SELECT routine_id,template_id,template_json FROM routine_cloud_templates',
          )
          .get();
      final bulk = cache
          .where(
            (row) => savedTemplates.containsKey(row.read<String>('routine_id')),
          )
          .toList();
      expect(bulk, hasLength(count * 3));
      expect(
        bulk.map((row) => row.read<String>('template_id')).toSet(),
        savedTemplates.values.expand((ids) => ids).toSet(),
      );
      for (final row in bulk) {
        final template = jsonDecode(row.read<String>('template_json')) as Json;
        expect(
          canonicalJson(template['prescription']),
          prescriptions[row.read<String>('template_id')],
        );
        final versions = savedTemplates[row.read<String>('routine_id')]!;
        final revision = versions.indexOf(row.read<String>('template_id')) + 1;
        expect(template['revision'], revision);
        expect(
          template['predecessor_template_id'],
          revision == 1 ? null : versions[revision - 2],
        );
      }
      expect(b.transport.manifests, hasLength(1));
      final pages = b.transport.manifests.single.pageCount;
      expect(pages, greaterThan(1));
      expect(b.transport.pageBytes, hasLength(pages));
      expect(b.transport.pageBytes.every((size) => size <= 524288), isTrue);
      expect(
        b.transport.requests,
        isEmpty,
        reason: 'Restoring immutable history must not republish it.',
      );
      expect(await b.repo.routinePendingCount(), 0);
      expect(
        await b.repo.workouts(),
        isEmpty,
        reason: 'Hundreds of plans must not invent performed sessions or observations.',
      );
      final selected = imported.first;
      final changedPlan = selected.plan.json
        ..['name'] = 'Explicit first edit after cloud import';
      final edited = await b.repo.saveRoutine(
        id: selected.id,
        expectedRevision: selected.localRevision,
        plan: RoutinePlan.fromJson(changedPlan),
      );
      expect(edited.localRevision, 2);
      final head =
          jsonDecode((await b.repo.prepareRoutineHead(selected.id))!) as Json;
      expect(head['expected_revision'], 3);
      expect(head['payload']['predecessor_template_id'], selected.templateId);
      await b.synchronize();
      expect(
        (await b.repo.routineSyncDetails(selected.id))!['server_revision'],
        4,
      );
      expect((await b.repo.routine(selected.id))!.localRevision, 2);
      await a.synchronize();
      expect(
        (await a.repo.routine(selected.id))!.templateId,
        edited.templateId,
      );
      debugPrintSynchronously(
        'Desktop routine-volume observations: ${jsonEncode({'roots': count, 'immutable_templates': count * 3, 'local_measurements': localMeasurements, 'snapshot_pages': pages, 'maximum_page_bytes': b.transport.pageBytes.reduce((a, b) => a > b ? a : b), 'offline_save_ms': saveWatch.elapsedMilliseconds, 'upload_ms': syncWatch.elapsedMilliseconds, 'bootstrap_ms': bootstrapWatch.elapsedMilliseconds, 'process_rss_before_bytes': rssBefore, 'process_rss_after_bytes': ProcessInfo.currentRss, 'limits': 'Windows desktop test-process RSS includes framework/caches and is not peak memory; no phone performance qualification'})}',
      );
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
