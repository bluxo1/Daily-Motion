import 'dart:async';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/routine_screen.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner;
import 'routine_repository_test.dart' show routineId, routinePlan;
import 'support/owned_fixture.dart';

class _InterruptedReadRepository extends WorkoutRepository {
  _InterruptedReadRepository(super.db, super.ownerId);
  Completer<List<Json>>? readGate;
  final entered = Completer<void>();
  @override
  Future<List<Json>> workouts() {
    final gate = readGate;
    if (gate == null) return super.workouts();
    if (!entered.isCompleted) entered.complete();
    return gate.future;
  }

  Future<List<Json>> durableWorkouts() => super.workouts();
}

class _Harness {
  final WidgetTester tester;
  final Directory directory;
  late TrainingDatabase db;
  late WorkoutRepository repo;
  ProviderContainer? container;
  _Harness(this.tester)
    : directory = Directory.systemTemp.createTempSync('routine-ui-');
  Future<void> open() async {
    // Widget tests use a real file with a synchronous executor. Repository
    // lifecycle tests separately exercise the production background factory.
    db = TrainingDatabase(NativeDatabase(File('${directory.path}/ui.sqlite')));
    repo = _InterruptedReadRepository(db, owner);
    await repo.initialize();
  }

  Future<void> mount({
    Widget home = const RoutineScreen(),
    bool settle = true,
    Future<List<SavedRoutine>> Function()? load,
  }) async {
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        if (load != null) routinesProvider.overrideWith((_) => load()),
      ],
    );
    await container!.read(workoutsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(theme: motionTheme(Brightness.light), home: home),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> reopen() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container?.dispose();
    container = null;
    repo.dispose();
    await db.close();
    await open();
    await mount();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container?.dispose();
    repo.dispose();
    await db.close();
    await deleteOwnedTemporaryDirectory(directory, 'routine-ui-');
  }

  Future<void> reveal(Finder target) async {
    final scroll = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: scroll,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(String text) async {
    final target = find.text(text);
    await reveal(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(Finder target, String value) async {
    // Pin the field identity before scrolling can lazily unmount another card.
    final key = target.evaluate().isEmpty ? null : tester.widget(target).key;
    final stable = key == null ? target : find.byKey(key);
    await reveal(stable);
    await tester.enterText(stable, value);
    await tester.pump();
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<_Harness> _harness(WidgetTester tester) async {
  final h = _Harness(tester);
  await h.open();
  addTearDown(h.close);
  return h;
}

void main() {
  testWidgets(
    'interrupted post-commit start reopens as an active workout without a UI attempt',
    (tester) async {
      final h = await _harness(tester);
      await h.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await h.mount();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTC').last);
      await tester.pumpAndSettle();
      final repo = h.repo as _InterruptedReadRepository;
      repo.readGate = Completer<List<Json>>();
      await tester.tap(find.text('Start workout'));
      await tester.runAsync(() => repo.entered.future);
      final committed = (await repo.durableWorkouts()).single;
      final body = await repo.prepareHead(committed['aggregate_id'] as String);
      // Destroy the screen before refresh/navigation returns. The attempts map
      // disappears; no persistent screen retry identity is being simulated.
      await tester.pumpWidget(const SizedBox.shrink());
      repo.readGate!.complete([committed]);
      await tester.pumpAndSettle();
      await h.reopen();
      expect((await h.repo.workouts()).single, committed);
      expect(
        await h.repo.prepareHead(committed['aggregate_id'] as String),
        body,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start workout'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('Resume or finish your active workout'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h.container!.dispose();
      await h.mount(
        home: const HomeScreen(
          syntheticFixture: false,
          localRoutinesEnabled: true,
        ),
      );
      await h.tap('Resume workout');
      expect((await h.repo.workouts()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('routine start requires an explicit workout timezone', (
    tester,
  ) async {
    final h = await _harness(tester);
    await h.repo.saveRoutine(
      id: routineId,
      expectedRevision: 0,
      plan: routinePlan(),
    );
    await h.mount();
    await h.tap('Start workout');
    expect(
      await h.repo.workouts(),
      isEmpty,
      reason: 'No timezone was chosen; do not silently assign India.',
    );
    expect(
      find.text('Choose the workout timezone before starting.'),
      findsOneWidget,
    );
  });

  for (final action in ['move', 'exercise removal', 'set removal']) {
    testWidgets('rapid repeated $action preserves distinct planned items', (
      tester,
    ) async {
      final h = await _harness(tester);
      final payload = routinePlan().json;
      if (action != 'set removal') {
        final base = (payload['exercises'] as List).first as Json;
        payload['exercises'] = [
          for (final name in ['First', 'Second', 'Third'])
            {
              ...copyJson(base),
              'session_exercise_id': h.repo.newId(),
              'variant_id': h.repo.newId(),
              'name': name,
              'sets': [
                for (final item in (base['sets'] as List).cast<Json>())
                  {...copyJson(item), 'set_id': h.repo.newId()},
              ],
            },
        ];
      }
      final original = await h.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: RoutinePlan.fromJson(payload),
      );
      await h.mount();
      await h.tap('Edit routine');
      final target = action == 'move'
          ? find.byTooltip('Move exercise 2 up')
          : action == 'exercise removal'
          ? find.byTooltip('Remove exercise 2')
          : find.text('Remove planned set 2');
      await h.reveal(target);
      // Activate the same rendered control twice before a frame can replace
      // its callback. An ordinal finder after reflow could select another row.
      final VoidCallback activate;
      if (action == 'set removal') {
        final button = find
            .ancestor(
              of: target,
              matching: find.byWidgetPredicate((w) => w is TextButton),
            )
            .first;
        activate = tester.widget<TextButton>(button).onPressed!;
      } else {
        final tooltip = action == 'move'
            ? 'Move exercise 2 up'
            : 'Remove exercise 2';
        activate = tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == tooltip,
              ),
            )
            .onPressed!;
      }
      activate();
      activate();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await h.tap('Save routine');
      final saved = (await h.repo.routines()).single;
      if (action == 'move') {
        expect(saved.plan.exercises.map((e) => e['name']), [
          'Second',
          'First',
          'Third',
        ]);
      } else if (action == 'exercise removal') {
        expect(saved.plan.exercises.map((e) => e['name']), ['First', 'Third']);
      } else {
        expect(
          (saved.plan.exercises.single['sets'] as List).map((s) => s['set_id']),
          [
            original.plan.exercises.single['sets'][0]['set_id'],
            original.plan.exercises.single['sets'][2]['set_id'],
          ],
        );
      }
    });
  }

  testWidgets('create and edit through UI survive SQLite close and reopen', (
    tester,
  ) async {
    final h = await _harness(tester);
    await h.mount();
    await h.tap('New routine');
    await h.enter(
      find.byKey(const ValueKey('routine-name')),
      'My saved routine',
    );
    await h.tap('Add exercise');
    await h.enter(field('Exercise name'), 'Dumbbell row');
    await h.enter(field('Planned load').first, '22.5');
    await h.tap('Save routine');
    expect(find.text('My saved routine'), findsOneWidget);
    expect(
      (await h.repo.routines())
          .single
          .plan
          .exercises
          .first['sets'][0]['planned']['load']['value'],
      '22.5',
    );
    expect(await h.repo.workouts(), isEmpty);
    await h.reopen();
    expect(find.text('My saved routine'), findsOneWidget);
    await h.tap('Edit routine');
    await h.enter(find.byKey(const ValueKey('routine-name')), 'Edited routine');
    await h.enter(field('Planned reps').first, '8');
    await h.tap('Save routine');
    await h.reopen();
    expect(find.text('Edited routine'), findsOneWidget);
    final saved = (await h.repo.routines()).single;
    expect(saved.localRevision, 2);
    expect(saved.plan.exercises.first['sets'][0]['planned']['reps'], 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid content and SQLite write failure retain unsaved form input',
    (tester) async {
      final h = await _harness(tester);
      await h.mount();
      await h.tap('New routine');
      await h.enter(
        find.byKey(const ValueKey('routine-name')),
        'Unsaved input',
      );
      await h.tap('Save routine');
      expect(find.byKey(const ValueKey('routine-error')), findsOneWidget);
      expect(await h.repo.routines(), isEmpty);
      await h.tap('Add exercise');
      await h.enter(field('Exercise name'), 'Bench press');
      await h.db.customStatement(
        "CREATE TRIGGER fail_ui BEFORE INSERT ON workout_templates BEGIN SELECT RAISE(ABORT,'PRIVATE SQL DETAIL'); END",
      );
      await h.tap('Save routine');
      expect(
        find.text(
          'Could not save on this device. Your edits are still here. Retry.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE SQL DETAIL'), findsNothing);
      await h.reveal(find.byKey(const ValueKey('routine-name')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('routine-name')))
            .controller!
            .text,
        'Unsaved input',
      );
      expect(await h.repo.routines(), isEmpty);
      await h.db.customStatement('DROP TRIGGER fail_ui');
      await h.tap('Save routine');
      expect(find.text('Unsaved input'), findsOneWidget);
      expect((await h.repo.routines()).single.localRevision, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid save taps publish one version and keep the routines route',
    (tester) async {
      final h = await _harness(tester);
      await h.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await h.mount();
      await h.tap('Edit routine');
      await h.enter(find.byKey(const ValueKey('routine-name')), 'One change');
      final button = find.text('Save routine');
      await h.reveal(button);
      await tester.tap(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Routines'), findsOneWidget);
      expect(find.text('One change'), findsOneWidget);
      expect((await h.repo.routines()).single.localRevision, 2);
      expect(
        (await h.db
                .customSelect('SELECT count(*) AS n FROM workout_templates')
                .getSingle())
            .read<int>('n'),
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back preserves a draft until discard is explicitly confirmed', (
    tester,
  ) async {
    final h = await _harness(tester);
    await h.mount();
    await h.tap('New routine');
    await h.enter(
      find.byKey(const ValueKey('routine-name')),
      'Keep this draft',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('routine-name')))
          .controller!
          .text,
      'Keep this draft',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Routines'), findsOneWidget);
    expect(await h.repo.routines(), isEmpty);
  });

  testWidgets(
    'starting through UI opens an unperformed workout and preserves history on edit',
    (tester) async {
      final h = await _harness(tester);
      await h.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await h.mount();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTC').last);
      await tester.pumpAndSettle();
      await h.tap('Start workout');
      final original = (await h.repo.workouts()).single;
      expect(original['timezone'], 'UTC');
      expect(allSets(original).every((s) => s['observation'] == null), true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start workout'),
      );
      expect(start.onPressed, isNull);
      await h.tap('Edit routine');
      await h.enter(find.byKey(const ValueKey('routine-name')), 'Future plan');
      await h.tap('Save routine');
      expect(
        await h.repo.workout(original['aggregate_id'] as String),
        original,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reordering, removing and adding exercises retains their edited prescriptions',
    (tester) async {
      final h = await _harness(tester);
      await h.repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await h.mount();
      await h.tap('Edit routine');
      await h.tap('Add exercise');
      await h.reveal(find.text('Exercise 2'));
      await h.enter(field('Exercise name').last, 'Second exercise');
      final up = find.byTooltip('Move exercise 2 up');
      await h.reveal(up);
      await tester.tap(up);
      await tester.pumpAndSettle();
      final remove = find.byTooltip('Remove exercise 2');
      await h.reveal(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await h.tap('Save routine');
      final saved = (await h.repo.routines()).single;
      expect(saved.plan.exercises.single['name'], 'Second exercise');
      expect(saved.plan.exercises.single['sets'].length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px 200 percent text and keyboard inset remain editable with labelled controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      final semantics = tester.ensureSemantics();
      try {
        final h = await _harness(tester);
        await h.repo.saveRoutine(
          id: routineId,
          expectedRevision: 0,
          plan: routinePlan(),
        );
        await h.mount();
        await h.tap('Edit routine');
        await h.enter(
          find.byKey(const ValueKey('routine-name')),
          'Large text edit',
        );
        await h.enter(field('Planned rest (seconds)').last, '0');
        final save = find.text('Save routine');
        await h.reveal(save);
        expect(
          tester
              .getSize(find.widgetWithText(FilledButton, 'Save routine'))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(find.bySemanticsLabel('Save routine'), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect((await h.repo.routines()).single.plan.name, 'Large text edit');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'loading and failed reads expose retry without raw storage details',
    (tester) async {
      final h = await _harness(tester);
      final waiting = Completer<List<SavedRoutine>>();
      var recovered = false;
      await h.mount(
        settle: false,
        load: () => recovered ? h.repo.routines() : waiting.future,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      waiting.completeError(StateError('PRIVATE STORAGE DETAIL'));
      await tester.pumpAndSettle();
      expect(
        find.text('Routines could not be loaded. Saved work is retained.'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE STORAGE DETAIL'), findsNothing);
      // Refresh with the actual repository after the controlled read failure.
      recovered = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('New routine'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'routine authoring is opt-in and remains inside the existing owner scope',
    (tester) async {
      final h = await _harness(tester);
      await h.mount(home: const HomeScreen(syntheticFixture: false));
      expect(find.text('My routines'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h.container?.dispose();
      await h.mount(
        home: const HomeScreen(
          syntheticFixture: false,
          localRoutinesEnabled: true,
        ),
      );
      await h.tap('My routines');
      expect(find.text('New routine'), findsOneWidget);
      expect(await h.repo.workouts(), isEmpty);
    },
  );
}
