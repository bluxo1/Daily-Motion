import 'dart:async';
import 'dart:io';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/auth_app.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:daily_motion/features/internal_routine_access.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/owned_fixture.dart';
import 'support/sync_server.dart';
import 'multi_exercise_test.dart' show multiPlan;

class ActivationRepository extends WorkoutRepository {
  ActivationRepository(super.db, super.ownerId);
  bool failReads = false;
  bool holdReads = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Json>> workouts() async {
    if (failReads) throw const FileSystemException('PRIVATE READ DETAIL');
    final values = await super.workouts();
    if (holdReads) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return values;
  }

  Future<List<Json>> durableWorkouts() => super.workouts();
}

/// Real per-owner files; synchronous SQLite only avoids widget fake-clock /
/// background-isolate scheduling. Production factory lifecycle tests remain.
class ActivationStores extends LocalOwnerStores {
  ActivationStores(super.directory);
  @override
  Future<LocalOwner> open(String owner, {bool existing = false}) async {
    directory.createSync(recursive: true);
    final file = File('${directory.path}/owner-$owner.sqlite');
    if (existing && !file.existsSync()) {
      throw const AuthFailure('local_identity_unavailable');
    }
    final db = TrainingDatabase(
      NativeDatabase(
        file,
        setup: (sqlite) => sqlite.execute(
          'PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;',
        ),
      ),
    );
    return LocalOwner(db, ActivationRepository(db, owner));
  }
}

class AccountHarness {
  final WidgetTester tester;
  final directory = Directory.systemTemp.createTempSync('activation-owner-');
  final protected = MemoryProtectedStorage();
  late final storage = SecureSessionStorage(protected, 'activation-fixture');
  var now = DateTime.utc(2026, 10, 26, 12);
  late final provider = FakeOtpProvider(testSession(testOwner, now));
  final servers = {
    testOwner: SyncServer(),
    ownerB: SyncServer()..owner = ownerB,
  };
  late final gateway = FakeAccountGateway(servers);
  late AccountController account;
  AccountHarness(this.tester);
  ActivationRepository get repo =>
      account.local!.repository as ActivationRepository;
  AccountController controller() => AccountController(
    provider: provider,
    gateway: gateway,
    storage: storage,
    stores: ActivationStores(directory),
    syncTransport: (owner, _) => servers[owner]!,
    clock: () => now,
  )..foreground(false);
  Future<void> open() async {
    account = controller();
    await tester.runAsync(account.restore);
    await tester.pumpWidget(AccountApplication(controller: account));
    await tester.pumpAndSettle();
  }

  Future<void> signIn({String owner = testOwner}) async {
    provider.session = testSession(owner, now);
    await tester.runAsync(() async {
      await account.requestOtp('synthetic@example.test');
      await account.verifyOtp('123456');
    });
    await tester.pumpAndSettle();
    expect(account.owner, owner);
  }

  // Account shutdown crosses real file IO and async* provider cancellation.
  // Advance both schedulers until the observed operation completes; do not
  // infer completion from a frame count or weaken the account-state assertion.
  Future<void> drain(Future<void> work) async {
    var finished = false;
    Object? failure;
    StackTrace? trace;
    work.then(
      (_) => finished = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        finished = true;
      },
    );
    for (var i = 0; i < 1000 && !finished; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
    expect(finished, isTrue, reason: 'Account/file operation must complete.');
    if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(account.close());
    await deleteOwnedTemporaryDirectory(directory, 'activation-owner-');
  }

  Future<void> reopen() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(account.close());
    await open();
  }

  Future<void> reveal(Finder target) async {
    final scroll = find.byType(Scrollable).first;
    if (target.evaluate().isEmpty) {
      tester.state<ScrollableState>(scroll).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: scroll,
        maxScrolls: 100,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(String label) async {
    final target = find.text(label);
    await reveal(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> timezone() async {
    final target = find.byType(DropdownButtonFormField<String>);
    await reveal(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTC').last);
    await tester.pumpAndSettle();
  }

  Future<void> savePlan({String name = 'Local training'}) async {
    await repo.saveRoutine(
      id: repo.newId(),
      expectedRevision: 0,
      plan: multiPlan(repo, name: name),
    );
    // Restore the actual account route, rather than overriding its providers.
    await reopen();
  }

  Future<void> record(String setId, String reps) async {
    final editor = find.byWidgetPredicate(
      (w) => w is SetEditor && w.item['set_id'] == setId && !w.correction,
    );
    await reveal(editor);
    final load = find.descendant(
      of: editor,
      matching: find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText?.startsWith('Load (') == true,
      ),
    );
    if (load.evaluate().isNotEmpty) {
      await reveal(load);
      await tester.enterText(load, '20');
    }
    final field = find.descendant(
      of: editor,
      matching: find.widgetWithText(TextField, 'Actual reps'),
    );
    await reveal(field);
    await tester.enterText(field, reps);
    final save = find.descendant(
      of: editor,
      matching: find.byType(FilledButton),
    );
    await reveal(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }
}

void main() {
  const enabled = bool.fromEnvironment('DM_LOCAL_ROUTINES');
  test('routine access rejects release mode even with an explicit request', () {
    expect(internalRoutineAccess(false), isFalse);
    expect(internalRoutineAccess(true), !kReleaseMode);
  });
  testWidgets(
    enabled
        ? 'verified internal account discovers first routine creation on Train'
        : 'default account route keeps unfinished routine authoring unavailable',
    (tester) async {
      final h = AccountHarness(tester);
      await h.open();
      addTearDown(h.close);
      await h.signIn();
      expect(await h.repo.workouts(), isEmpty);
      expect(await h.repo.routines(), isEmpty);
      expect(await h.repo.pendingCount(), 0);
      expect(find.text('Train'), findsWidgets);
      expect(
        find.text('Development fixture · synthetic account'),
        findsNothing,
      );
      expect(find.textContaining('Barbell bench press'), findsNothing);
      if (enabled) {
        expect(
          find.widgetWithText(FilledButton, 'Create routine'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Saved only on this device'),
          findsOneWidget,
        );
        await h.reveal(find.widgetWithText(FilledButton, 'Create routine'));
        await tester.tap(find.widgetWithText(FilledButton, 'Create routine'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('routine-name')), findsOneWidget);
      } else {
        expect(find.text('Create routine'), findsNothing);
        expect(find.text('My routines'), findsNothing);
      }
    },
  );
  if (enabled) {
    testWidgets(
      'verified owner creates three-exercise routine, records, finishes and reopens history offline',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.tap('Create routine');
        await tester.enterText(
          find.byKey(const ValueKey('routine-name')),
          'My first workout',
        );
        for (var i = 1; i <= 3; i++) {
          await h.tap('Add exercise');
          final heading = find.text('Exercise $i');
          await h.reveal(heading);
          final card = find
              .ancestor(of: heading, matching: find.byType(Card))
              .first;
          final name = find.descendant(
            of: card,
            matching: find.widgetWithText(TextField, 'Exercise name'),
          );
          await h.reveal(name);
          await tester.enterText(name, ['Row', 'Press', 'Squat'][i - 1]);
        }
        await h.tap('Save routine');
        expect(find.text('Choose a routine'), findsOneWidget);
        expect(find.text('3 exercises · 9 planned sets'), findsOneWidget);
        expect(await h.repo.workouts(), isEmpty);
        expect(
          await h.repo.pendingCount(),
          0,
          reason:
              'Planning is not recorded training or a remote routine command.',
        );
        await h.tap('Start workout');
        expect(await h.repo.workouts(), isEmpty, reason: 'No timezone chosen.');
        await h.timezone();
        await h.tap('Start workout');
        final created = (await h.repo.workouts()).single;
        final id = created['aggregate_id'] as String;
        expect(created['timezone'], 'UTC');
        final exercises = (created['exercises'] as List).cast<Json>();
        expect(exercises.map((e) => e['name']), ['Row', 'Press', 'Squat']);
        expect(
          exercises.every(
            (e) => (e['sets'] as List).every((s) => s['observation'] == null),
          ),
          isTrue,
        );
        for (var i = 0; i < 3; i++) {
          await h.record(
            exercises[i]['sets'][0]['set_id'] as String,
            '${5 + i}',
          );
        }
        await h.tap('Finish workout');
        await tester.tap(find.widgetWithText(TextButton, 'Finish'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutScreen), findsNothing);
        expect(find.text('Resume workout'), findsNothing);
        expect(
          find.text('Choose a routine'),
          findsOneWidget,
          reason: 'Finish returns directly to Train.',
        );
        expect((await h.repo.workout(id))!['status'], 'completed');
        expect(await h.repo.pendingCount(), 5);
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        final source = find.byKey(ValueKey('history-$id'));
        await h.reveal(source);
        expect(find.textContaining('3 attempted sets'), findsOneWidget);
        await tester.tap(source);
        await tester.pumpAndSettle();
        await h.reveal(find.text('Squat'));
        expect(find.text('Squat'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Progress').last);
        await tester.pumpAndSettle();
        await h.reveal(find.text('Press'));
        await tester.tap(find.text('Press'));
        await tester.pumpAndSettle();
        await h.reveal(find.textContaining('6 reps'));
        expect(find.textContaining('6 reps'), findsWidgets);
        final before = await h.repo.workouts();
        await h.reopen();
        expect(await h.repo.workouts(), before);
        expect((await h.repo.routines()).single.plan.name, 'My first workout');
        expect(await h.repo.pendingCount(), 5);
        expect(
          h.servers[testOwner]!.pushed,
          isEmpty,
          reason: 'Local workflow made no cloud request.',
        );
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        await h.reveal(find.byKey(ValueKey('history-$id')));
        expect(find.byKey(ValueKey('history-$id')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'saved routines show factual counts; rapid start and resume cannot duplicate sessions or routes',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        for (var i = 1; i <= 3; i++) {
          await h.repo.saveRoutine(
            id: h.repo.newId(),
            expectedRevision: 0,
            plan: multiPlan(h.repo, name: 'Routine $i'),
          );
        }
        await h.reopen();
        for (var i = 1; i <= 3; i++) {
          await h.reveal(find.text('Routine $i'));
          expect(find.text('Routine $i'), findsOneWidget);
        }
        await h.timezone();
        await h.reveal(find.text('Start workout').first);
        final start = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start workout').first,
            )
            .onPressed!;
        start();
        start();
        await tester.pumpAndSettle();
        expect((await h.repo.workouts()).length, 1);
        expect(await h.repo.pendingCount(), 1);
        expect(find.byType(WorkoutScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await h.reveal(find.text('Resume workout'));
        final resume = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Resume workout'),
            )
            .onPressed!;
        resume();
        resume();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byType(WorkoutScreen),
          findsNothing,
          reason: 'Only one resume route was pushed.',
        );
        await h.reveal(find.text('Start workout').first);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start workout').first,
              )
              .onPressed,
          isNull,
        );
        expect((await h.repo.workouts()).length, 1);
        await h.reopen();
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(await h.repo.pendingCount(), 1);
      },
    );

    testWidgets(
      'acknowledged start with failed refresh is saved and safely resumes after retry',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.timezone();
        h.repo.onLocalCommit = (_) => h.repo.failReads = true;
        await h.tap('Start workout');
        expect((await h.repo.durableWorkouts()).single['status'], 'active');
        expect(await h.repo.pendingCount(), 1);
        expect(
          find.textContaining('Workout saved on this device.'),
          findsOneWidget,
        );
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(find.textContaining('could not be saved'), findsNothing);
        expect(find.text('Open saved workout'), findsOneWidget);
        h.repo.failReads = false;
        h.repo.onLocalCommit = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect((await h.repo.workouts()).length, 1);
      },
    );

    testWidgets(
      'interrupted acknowledged start restores through real account SQLite reopen without replay',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.timezone();
        final old = h.repo;
        old.onLocalCommit = (_) => old.holdReads = true;
        await h.reveal(find.text('Start workout'));
        await tester.tap(find.text('Start workout'));
        await tester.runAsync(() => old.entered.future);
        final committed = (await old.durableWorkouts()).single;
        final envelope = await old.prepareHead(
          committed['aggregate_id'] as String,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        old.release.complete();
        await tester.pumpAndSettle();
        await h.reopen();
        expect((await h.repo.workouts()).single, committed);
        expect(
          await h.repo.prepareHead(committed['aggregate_id'] as String),
          envelope,
        );
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(await h.repo.pendingCount(), 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed routine start rolls back all writes and retains a safe explicit retry',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.timezone();
        await h.repo.db.customStatement(
          "CREATE TRIGGER activation_reject BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'PRIVATE WRITE DETAIL'); END",
        );
        await h.tap('Start workout');
        expect(await h.repo.workouts(), isEmpty);
        expect(await h.repo.pendingCount(), 0);
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(find.textContaining('could not be confirmed'), findsOneWidget);
        await h.repo.db.customStatement('DROP TRIGGER activation_reject');
        await h.tap('Start workout');
        expect((await h.repo.workouts()).single['status'], 'active');
        expect(await h.repo.pendingCount(), 1);
      },
    );

    testWidgets(
      'unsaved first routine can be kept or discarded through the real Train route',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.tap('Create routine');
        await tester.enterText(
          find.byKey(const ValueKey('routine-name')),
          'Unsaved plan',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('Unsaved plan'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(await h.repo.routines(), isEmpty);
        expect(find.text('Start your first workout'), findsOneWidget);
        expect(await h.repo.workouts(), isEmpty);
      },
    );
    testWidgets(
      'expired cloud token preserves cached local routine start and logging',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        h.now = h.now.add(const Duration(hours: 2));
        h.provider.refreshFailure = const AuthFailure(
          'network_unavailable',
          retryable: true,
        );
        await tester.runAsync(() => h.account.refresh(force: true));
        await tester.pumpAndSettle();
        expect(h.account.state.phase, AccountPhase.offline);
        await h.timezone();
        await h.tap('Start workout');
        final session = (await h.repo.workouts()).single;
        await h.record(
          session['exercises'][1]['sets'][0]['set_id'] as String,
          '8',
        );
        expect(await h.repo.pendingCount(), 2);
        await h.reopen();
        expect(h.account.owner, testOwner);
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(
          (await h.repo.workouts())
              .single['exercises'][1]['sets'][0]['observation']['actual']['reps'],
          8,
        );
        expect(h.servers[testOwner]!.pushed, isEmpty);
      },
    );

    testWidgets(
      'sign-out locks pending training; switching owner does not reveal plans or workout routes',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan(name: 'Owner A private routine');
        await h.timezone();
        await h.tap('Start workout');
        final previous = await h.repo.workouts();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Sign out'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Let the account root detach its paused stream listeners before
        // waiting for the controller's real SQLite / coordinator shutdown.
        await h.drain(h.account.signOut());
        await tester.pumpAndSettle();
        expect(h.account.local, isNull);
        expect(find.text('Owner A private routine'), findsNothing);
        expect(find.text('Resume workout'), findsNothing);
        final locked = await ActivationStores(h.directory)
            .open(testOwner, existing: true);
        await expectLater(
          locked.repository.workouts(),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(
          (await locked.database
                  .customSelect('SELECT COUNT(*) AS n FROM outbox')
                  .getSingle())
              .read<int>('n'),
          1,
        );
        await locked.close();
        await h.signIn(owner: ownerB);
        expect(await h.repo.workouts(), isEmpty);
        expect(await h.repo.routines(), isEmpty);
        expect(find.text('Start your first workout'), findsOneWidget);
        final signOut = h.account.signOut();
        await tester.pump();
        await h.drain(signOut);
        await tester.pumpAndSettle();
        await h.signIn();
        expect(await h.repo.workouts(), previous);
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(await h.repo.pendingCount(), 1);
        expect(h.servers[ownerB]!.pushed, isEmpty);
      },
    );

    testWidgets(
      'authoritative disable removes real-account routine and active workout UI and payloads',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan(name: 'Erased private routine');
        await h.timezone();
        await h.tap('Start workout');
        final done = Completer<void>();
        void changed() {
          if (h.account.state.phase == AccountPhase.disabled &&
              !done.isCompleted) {
            done.complete();
          }
        }

        h.account.addListener(changed);
        h.servers[testOwner]!.disabled = true;
        h.account.foreground(true);
        await h.drain(done.future);
        h.account.removeListener(changed);
        await tester.pumpAndSettle();
        expect(h.account.local, isNull);
        expect(find.byType(WorkoutScreen), findsNothing);
        expect(find.text('Erased private routine'), findsNothing);
        expect(find.text('Create routine'), findsNothing);
        final erased = await ActivationStores(h.directory)
            .open(testOwner, existing: true);
        expect(await erased.repository.remoteDisabled(), isTrue);
        for (final table in [
          'routines',
          'workout_templates',
          'routine_starts',
          'sessions',
          'outbox',
        ]) {
          expect(
            await erased.database.customSelect('SELECT * FROM $table').get(),
            isEmpty,
          );
        }
        await erased.close();
        await h.reopen();
        expect(h.account.local, isNull);
      },
    );

    testWidgets(
      'internal Train, routine start and resume remain accessible at 320 pixels and 200 percent text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final h = AccountHarness(tester);
          await h.open();
          addTearDown(h.close);
          await h.signIn();
          await h.reveal(find.text('Create routine'));
          expect(find.bySemanticsLabel('Create routine'), findsOneWidget);
          await h.tap('Create routine');
          await tester.enterText(
            find.byKey(const ValueKey('routine-name')),
            'Accessible plan',
          );
          await h.tap('Add exercise');
          final name = find.widgetWithText(TextField, 'Exercise name');
          await h.reveal(name);
          await tester.enterText(name, 'Offline row');
          await h.tap('Save routine');
          await h.reveal(find.text('1 exercises · 3 planned sets'));
          expect(find.text('1 exercises · 3 planned sets'), findsOneWidget);
          await h.timezone();
          await h.tap('Start workout');
          expect(find.byType(WorkoutScreen), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await h.reveal(find.text('Resume workout'));
          expect(find.bySemanticsLabel('Resume workout'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'routine read error retains real file and Retry restores saved plans',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan(name: 'Retained routine');
        await h.repo.db.customStatement(
          'ALTER TABLE routines RENAME TO activation_hidden_routines',
        );
        // Re-enter Train to create a fresh auto-disposed routine query.
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Train').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Routines could not be loaded. Saved work is retained.'),
          findsOneWidget,
        );
        expect(find.textContaining('no such table'), findsNothing);
        await h.repo.db.customStatement(
          'ALTER TABLE activation_hidden_routines RENAME TO routines',
        );
        await h.tap('Retry');
        await h.reveal(find.text('Retained routine'));
        expect(find.text('Retained routine'), findsOneWidget);
        expect((await h.repo.routines()).length, 1);
        expect(await h.repo.pendingCount(), 0);
      },
    );
    testWidgets(
      'navigation away during queued start still exposes the committed workout for Resume',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.timezone();
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocker = h.repo.db.transaction(() async {
          await h.repo.db.customSelect('SELECT 1').get();
          entered.complete();
          await release.future;
        });
        await entered.future;
        await h.reveal(find.text('Start workout'));
        await tester.tap(find.text('Start workout'));
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        release.complete();
        await blocker;
        await tester.pumpAndSettle();
        expect((await h.repo.workouts()).single['status'], 'active');
        expect(
          find.byType(WorkoutScreen),
          findsNothing,
          reason: 'Respect navigation away while start waited.',
        );
        await h.reveal(find.text('Resume workout'));
        expect(find.text('Resume workout'), findsOneWidget);
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(await h.repo.pendingCount(), 1);
      },
    );

    testWidgets(
      'leaving routine management during a queued start cannot pop Train or start a second workout',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.tap('My routines');
        await h.timezone();
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocker = h.repo.db.transaction(() async {
          await h.repo.db.customSelect('SELECT 1').get();
          entered.complete();
          await release.future;
        });
        await entered.future;
        await h.reveal(find.text('Start workout'));
        await tester.tap(find.text('Start workout'));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await h.reveal(find.text('Start workout'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start workout'),
              )
              .onPressed,
          isNull,
        );
        release.complete();
        await blocker;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(WorkoutScreen), findsNothing);
        await h.tap('Resume workout');
        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(await h.repo.pendingCount(), 1);
      },
    );

    testWidgets(
      'management start closes the list, finish returns to Train, and the next start is a new snapshot',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        await h.savePlan();
        await h.tap('My routines');
        await h.timezone();
        await h.tap('Start workout');
        final first = (await h.repo.workouts()).single;
        await h.record(
          first['exercises'][1]['sets'][0]['set_id'] as String,
          '7',
        );
        await h.tap('Finish workout');
        await tester.tap(find.widgetWithText(TextButton, 'Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Choose a routine'), findsOneWidget);
        expect(
          find.text('Routines'),
          findsNothing,
          reason: 'No duplicate list remains in the route stack.',
        );
        await h.timezone();
        await h.tap('Start workout');
        final sessions = await h.repo.workouts();
        expect(sessions.length, 2);
        final active = sessions.singleWhere((w) => w['status'] == 'active');
        expect(active['aggregate_id'], isNot(first['aggregate_id']));
        expect(allSets(active).every((s) => s['observation'] == null), isTrue);
        expect(
          (await h.repo.workout(first['aggregate_id'] as String))!['status'],
          'completed',
        );
        expect(await h.repo.pendingCount(), 4);
      },
    );
  }
}
