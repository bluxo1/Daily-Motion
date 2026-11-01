import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/routine_screen.dart';
import 'package:daily_motion/features/sync_provider.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner;
import 'routine_repository_test.dart' show routineId, routinePlan;
import 'support/owned_fixture.dart';

const generation = 'a0000000-0000-4000-8000-000000000001';

/// Controls UI scheduling only. Actual transport acceptance has separate real
/// HTTP/JWT/PostgreSQL connected controls, not this widget test double.
class UiCoordinator extends SyncCoordinator {
  final phases = StreamController<SyncStatus>.broadcast();
  final installed = StreamController<void>.broadcast();
  Completer<void>? retryGate;
  int retries = 0;
  UiCoordinator(WorkoutRepository repository)
    : super(
        repository,
        HttpSyncTransport(
          Uri.parse('http://127.0.0.1:1'),
          () async => null,
          allowLoopbackHttp: true,
          routineSyncEnabled: true,
        ),
      );
  @override
  Stream<SyncStatus> get statuses => phases.stream;
  @override
  Stream<void> get installations => installed.stream;
  void phase(SyncPhase phase, [String? code]) {
    status = SyncStatus(phase, code);
    if (!phases.isClosed) phases.add(status);
  }

  void changed() {
    if (!installed.isClosed) installed.add(null);
  }

  @override
  Future<void> synchronize({bool force = false}) async {
    retries++;
    phase(SyncPhase.syncing);
    await retryGate?.future;
    phase(SyncPhase.pending);
    changed();
  }

  @override
  Future<void> close() async {
    if (retryGate != null && !retryGate!.isCompleted) retryGate!.complete();
    await super.close();
    (transport as HttpSyncTransport).close();
    await phases.close();
    await installed.close();
  }
}

class UiStore {
  final TrainingDatabase db;
  final WorkoutRepository repo;
  late final UiCoordinator coordinator = UiCoordinator(repo);
  UiStore._(this.db, this.repo);
  static Future<UiStore> open(File file, String owner) async {
    final db = TrainingDatabase(NativeDatabase(file));
    final store = UiStore._(db, WorkoutRepository(db, owner));
    await store.repo.initialize();
    await db.customStatement('UPDATE sync_metadata SET generation=?', [
      generation,
    ]);
    return store;
  }

  Future<void> close() async {
    await coordinator.close();
    repo.dispose();
    await db.close();
  }
}

void main() {
  late Directory directory;
  final stores = <UiStore>[];
  ProviderContainer? container;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routine-sync-ui-');
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    for (final store in stores.reversed) {
      await store.close();
    }
    stores.clear();
    await deleteOwnedTemporaryDirectory(directory, 'routine-sync-ui-');
  });
  Future<UiStore> store(String name, {String selectedOwner = owner}) async {
    final value = await UiStore.open(
      File('${directory.path}/$name.sqlite'),
      selectedOwner,
    );
    stores.add(value);
    return value;
  }

  Future<void> mount(
    WidgetTester tester,
    UiStore store, {
    Brightness brightness = Brightness.light,
    double scale = 1,
    Future<List<SavedRoutine>> Function(WorkoutRepository)? load,
  }) async {
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(store.repo),
        syncCoordinatorProvider.overrideWithValue(store.coordinator),
        if (load != null)
          routinesProvider.overrideWith(
            (ref) => load(ref.watch(repositoryProvider)),
          ),
      ],
    );
    await container!.read(workoutsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          theme: motionTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RoutineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<Json> accepted(UiStore store, String id) async {
    final op = jsonDecode((await store.repo.prepareRoutineHead(id))!) as Json;
    await store.repo.installRoutineAcknowledgements(
      PushResponse3Dto.fromJson({
        'schema_version': 3,
        'owner_id': store.repo.ownerId,
        'generation': generation,
        'erasure_epoch': 0,
        'results': [
          {
            'mutation_id': op['mutation_id'],
            'aggregate_id': id,
            'status': 'accepted',
            'accepted_revision': op['expected_revision'] + 1,
            'accepted_at': '2026-10-29T00:00:00Z',
          },
        ],
      }),
      [op['mutation_id'] as String],
    );
    store.coordinator.changed();
    return op;
  }

  Future<void> visible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
  }

  for (final acknowledged in [false, true]) {
    for (final (phase, code, label) in [
      (SyncPhase.attention, 'upgrade_required', 'App update required to sync'),
      (
        SyncPhase.attention,
        'routine_sync_unavailable',
        'Cloud sync capability unavailable',
      ),
      (
        SyncPhase.pending,
        'recovery_metadata_unverified',
        'Cloud recovery needs attention',
      ),
      (SyncPhase.pending, 'http_503', 'Cloud sync temporarily unavailable'),
    ]) {
      testWidgets(
        'cloud interruption stays actionable without hiding local work: $code/$acknowledged',
        (tester) async {
          final s = await store('a');
          final saved = await s.repo.saveRoutine(
            id: routineId,
            expectedRevision: 0,
            plan: routinePlan(),
          );
          if (acknowledged) await accepted(s, routineId);
          await s.repo.recordSyncFailure(code);
          s.coordinator.phase(phase, code);
          final frozen = await s.repo.prepareRoutineHead(routineId);
          await mount(tester, s);
          expect(find.text('Synchronized'), findsNothing);
          expect(find.text(label), findsOneWidget);
          expect(
            s.coordinator.status.label.toLowerCase(),
            contains(label.toLowerCase()),
          );
          final edit = find.widgetWithText(OutlinedButton, 'Edit routine');
          expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
          expect(
            (await s.repo.routine(routineId))!.templateId,
            saved.templateId,
          );
          expect(await s.repo.prepareRoutineHead(routineId), frozen);
          expect(await s.repo.routinePendingCount(), acknowledged ? 0 : 1);
          expect((await s.repo.syncMetadata())['last_error'], code);
          await unmount(tester);
        },
      );
    }
  }

  testWidgets(
    'a global synchronized status never labels an unacknowledged routine cloud-backed',
    (tester) async {
      final s = await store('a');
      await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      s.coordinator.phase(SyncPhase.synchronized);
      await mount(tester, s);
      expect(find.text('Pending routine sync'), findsOneWidget);
      expect(find.text('Synchronized'), findsNothing);
      await accepted(s, routineId);
      await tester.pumpAndSettle();
      expect(find.text('Synchronized'), findsOneWidget);
      expect(
        (await s.repo.routineSyncDetails(routineId))!['server_revision'],
        1,
      );
      await unmount(tester);
    },
  );

  for (final code in <String?>[null, 'malformed_response']) {
    testWidgets(
      'accepted routine distinguishes unrelated root attention from failed account feed: $code',
      (tester) async {
        final s = await store('a');
        await s.repo.saveRoutine(
          id: routineId,
          expectedRevision: 0,
          plan: routinePlan(),
        );
        await accepted(s, routineId);
        s.coordinator.phase(SyncPhase.attention, code);
        await mount(tester, s);
        expect(
          find.text(code == null ? 'Synchronized' : 'Sync needs attention'),
          findsOneWidget,
        );
        if (code != null) expect(find.text('Synchronized'), findsNothing);
        expect(
          (await s.repo.routineSyncDetails(routineId))!['server_revision'],
          1,
        );
        expect(await s.repo.routinePendingCount(), 0);
        s.coordinator.phase(SyncPhase.synchronized);
        await tester.pumpAndSettle();
        expect(find.text('Synchronized'), findsOneWidget);
        await unmount(tester);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'routine status and keyboard retry retain focus at 320px and 200 percent in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final s = await store('a');
          await s.repo.saveRoutine(
            id: routineId,
            expectedRevision: 0,
            plan: routinePlan(),
          );
          await mount(tester, s, brightness: brightness, scale: 2);
          final retry = find.byKey(
            const ValueKey('routine-sync-retry-$routineId'),
          );
          await visible(tester, find.text('Pending routine sync'));
          expect(
            find.bySemanticsLabel(
              RegExp(r'Routine synchronization: Pending routine sync\.'),
            ),
            findsOneWidget,
          );
          await visible(tester, retry);
          final button = tester.widget<OutlinedButton>(retry);
          button.focusNode!.requestFocus();
          await tester.pump();
          s.coordinator.retryGate = Completer<void>();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(s.coordinator.retries, 1);
          expect(tester.widget<OutlinedButton>(retry).onPressed, isNull);
          await tester.tap(retry);
          await tester.pump();
          expect(s.coordinator.retries, 1);
          s.coordinator.retryGate!.complete();
          await tester.pumpAndSettle();
          expect(button.focusNode!.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'cloud unavailable and sign-in-required states retain local editing',
    (tester) async {
      final s = await store('a');
      await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      s.coordinator.phase(SyncPhase.attention, 'upgrade_required');
      await mount(tester, s);
      expect(find.text('App update required to sync'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Edit routine'),
        findsOneWidget,
      );
      s.coordinator.phase(SyncPhase.authenticationRequired);
      await tester.pumpAndSettle();
      expect(find.text('Cloud sign-in required'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('routine-sync-retry-$routineId')),
            )
            .onPressed,
        isNull,
      );
      expect(await s.repo.routinePendingCount(), 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'conflict review preserves and displays both plans without resolving either',
    (tester) async {
      final s = await store('a');
      final first = await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(name: 'Original plan'),
      );
      final create = await accepted(s, routineId);
      await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: first.localRevision,
        plan: routinePlan(name: 'Local alternative'),
      );
      final pending =
          jsonDecode((await s.repo.prepareRoutineHead(routineId))!) as Json;
      final remote = {
        ...create,
        'mutation_id': s.repo.newId(),
        'expected_revision': 1,
        'command': 'publish_template',
        'payload': {
          'template_id': s.repo.newId(),
          'predecessor_template_id': first.templateId,
          'prescription': routinePlan(name: 'Cloud alternative').json,
        },
      };
      await s.repo.installRoutinePull(
        PullResponse3Dto.fromJson({
          'schema_version': 3,
          'owner_id': owner,
          'generation': generation,
          'erasure_epoch': 0,
          'changes': [
            {'position': 1, 'revision': 1, 'operation': create},
            {'position': 2, 'revision': 2, 'operation': remote},
          ],
          'next_cursor': 'cursor-2',
          'next_position': 2,
          'has_more': false,
        }),
        requestedCursor: null,
      );
      await s.repo.installRoutineAcknowledgements(
        PushResponse3Dto.fromJson({
          'schema_version': 3,
          'owner_id': owner,
          'generation': generation,
          'erasure_epoch': 0,
          'results': [
            {
              'mutation_id': pending['mutation_id'],
              'aggregate_id': routineId,
              'status': 'conflict',
              'expected_revision': 1,
              'current_revision': 2,
              'error': {'code': 'revision_conflict', 'retryable': false},
            },
          ],
        }),
        [pending['mutation_id'] as String],
      );
      await mount(tester, s);
      expect(find.text('Routine conflict'), findsOneWidget);
      final review = find.text('Review conflict');
      await visible(tester, review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text('Your saved plan'), findsOneWidget);
      expect(find.text('Cloud plan'), findsOneWidget);
      expect(find.text('Cloud alternative'), findsOneWidget);
      expect(find.text('Local alternative'), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect((await s.repo.routine(routineId))!.plan.name, 'Local alternative');
      expect(await s.repo.routinePendingCount(), 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'owner replacement hides previous private routines while an old refresh is pending',
    (tester) async {
      final a = await store('a');
      final b = await store(
        'b',
        selectedOwner: '20000000-0000-4000-8000-000000000002',
      );
      await a.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(name: 'A private routine'),
      );
      await b.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(name: 'B private routine'),
      );
      var hold = false;
      final gate = Completer<void>();
      final entered = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      Future<List<SavedRoutine>> load(WorkoutRepository target) async {
        final rows = await target.routines();
        if (identical(target, a.repo) && hold) {
          if (!entered.isCompleted) entered.complete();
          await gate.future;
        }
        return rows;
      }

      await mount(tester, a, load: load);
      expect(find.text('A private routine'), findsOneWidget);
      hold = true;
      a.coordinator.changed();
      for (var frame = 0; frame < 30 && !entered.isCompleted; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        entered.isCompleted,
        isTrue,
        reason: 'old-owner read reached barrier',
      );
      container!.updateOverrides([
        repositoryProvider.overrideWithValue(b.repo),
        syncCoordinatorProvider.overrideWithValue(b.coordinator),
        routinesProvider.overrideWith(
          (ref) => load(ref.watch(repositoryProvider)),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('A private routine'), findsNothing);
      expect(find.text('B private routine'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('A private routine'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'disposing the routine library during a held private refresh ignores its late result',
    (tester) async {
      final s = await store('a');
      await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(name: 'Private pending read'),
      );
      var hold = false;
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      Future<List<SavedRoutine>> load(WorkoutRepository target) async {
        final rows = await target.routines();
        if (hold) {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        }
        return rows;
      }

      await mount(tester, s, load: load);
      hold = true;
      s.coordinator.changed();
      for (var frame = 0; frame < 30 && !entered.isCompleted; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(entered.isCompleted, isTrue);
      await unmount(tester);
      container!.dispose();
      container = null;
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Private pending read'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing routine status during an ongoing retry does not restore a dead focus node',
    (tester) async {
      final s = await store('a');
      await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      s.coordinator.retryGate = Completer<void>();
      await mount(tester, s);
      final retry = find.byKey(const ValueKey('routine-sync-retry-$routineId'));
      await visible(tester, retry);
      tester.widget<OutlinedButton>(retry).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(s.coordinator.retries, 1);
      await unmount(tester);
      container!.dispose();
      container = null;
      s.coordinator.retryGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a missing cloud root keeps unknown variant definitions snapshot-only',
    (tester) async {
      final s = await store('a');
      final saved = await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await accepted(s, routineId);
      final page = <String, dynamic>{
        'roots': [],
        'routines': [],
        'retired_ids': [],
      };
      await s.repo.stageRoutineBootstrap(
        BootstrapManifest3Dto.fromJson({
          'schema_version': 3,
          'owner_id': owner,
          'generation': generation,
          'erasure_epoch': 0,
          'installation_id': (await s.repo.syncMetadata())['installation_id'],
          'token': 'missing-root',
          'position': 2,
          'cursor': 'missing-root-2',
          'expires_at': '2099-01-01T00:00:00Z',
          'page_count': 1,
          'checksums': [
            sha256.convert(utf8.encode(canonicalJson(page))).toString(),
          ],
        }),
      );
      await s.repo.stageRoutineBootstrapPage(
        0,
        SnapshotPage3Dto.fromJson(page),
      );
      await s.repo.activateRoutineBootstrap(
        MeResponse3Dto.fromJson({
          'schema_version': 3,
          'owner_id': owner,
          'generation': generation,
          'erasure_epoch': 0,
          'position': 2,
          'minimum_position': 0,
        }),
      );
      final details = (await s.repo.routineSyncDetails(routineId))!;
      expect(details['has_conflict'], 1);
      expect(
        details['server_revision'],
        0,
        reason: 'Missing cloud state must not be used as catalog provenance.',
      );
      s.coordinator.phase(SyncPhase.attention);
      await mount(tester, s);
      final edit = find.text('Edit routine');
      await visible(tester, edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final exercise = saved.plan.exercises.first;
      final name = find.byKey(
        ValueKey('exercise-name-${exercise['session_exercise_id']}'),
      );
      expect(tester.widget<TextField>(name).readOnly, isTrue);
      expect(
        find.byKey(const ValueKey('routine-snapshot-only')),
        findsOneWidget,
      );
      final target = find.byKey(
        ValueKey('planned-reps-${exercise['sets'][0]['set_id']}'),
      );
      await visible(tester, target);
      await tester.enterText(target, '13');
      await visible(tester, find.text('Save routine'));
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();
      final current = (await s.repo.routine(routineId))!;
      expect(
        current.plan.exercises.first['variant_id'],
        exercise['variant_id'],
      );
      expect(current.plan.exercises.first['sets'][0]['planned']['reps'], 13);
      expect(
        await s.repo.customExercise(exercise['variant_id'] as String),
        isNull,
      );
      expect((await s.repo.routineSyncDetails(routineId))!['has_conflict'], 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'unknown cloud catalog definitions stay snapshot-only while planned targets remain editable',
    (tester) async {
      final s = await store('a');
      final saved = await s.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await accepted(s, routineId);
      await mount(tester, s);
      final edit = find.text('Edit routine');
      await visible(tester, edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('routine-snapshot-only')),
        findsOneWidget,
      );
      final exercise = saved.plan.exercises.first;
      final name = find.byKey(
        ValueKey('exercise-name-${exercise['session_exercise_id']}'),
      );
      expect(tester.widget<TextField>(name).readOnly, isTrue);
      final target = find.byKey(
        ValueKey('planned-reps-${exercise['sets'][0]['set_id']}'),
      );
      await visible(tester, target);
      await tester.enterText(target, '11');
      final save = find.text('Save routine');
      await visible(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final current = (await s.repo.routine(routineId))!;
      expect(
        current.plan.exercises.first['variant_id'],
        exercise['variant_id'],
      );
      expect(current.plan.exercises.first['sets'][0]['planned']['reps'], 11);
      expect(
        await s.repo.customExercise(exercise['variant_id'] as String),
        isNull,
      );
      await unmount(tester);
    },
  );
}
