import 'dart:async';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/rest_timer.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/owned_fixture.dart';

const ownerA = '20000000-0000-4000-8000-000000000001';
const ownerB = '20000000-0000-4000-8000-000000000002';

RoutinePlan multiPlan(
  WorkoutRepository repo, {
  String name = 'Three exercise routine',
}) => RoutinePlan(
  name: name,
  exercises: [
    for (var i = 0; i < 3; i++)
      {
        'session_exercise_id': repo.newId(),
        'variant_id': repo.newId(),
        'name': ['Single-arm row', 'Push-up', 'Assisted pull-up'][i],
        'loading_basis': ['per_implement', 'bodyweight_only', 'assistance'][i],
        'rep_convention': i == 0 ? 'per_side' : 'bilateral',
        'side': i == 0 ? 'left' : 'both',
        'sets': [
          for (var j = 0; j < 2; j++)
            {
              'set_id': repo.newId(),
              'set_class': j == 0 && i == 2 ? 'warmup' : 'working',
              'set_purpose': 'regular',
              'planned': {
                'reps': 5 + i,
                'load': i == 1
                    ? null
                    : {
                        'value': i == 0 ? '25' : '5',
                        'unit': 'kg',
                        'basis': i == 0 ? 'per_implement' : 'assistance',
                      },
                'rest_seconds': 120,
              },
            },
        ],
      },
  ],
);

Json entry({
  String status = 'completed',
  String reps = '6',
  String load = '25',
}) => {
  'load': load,
  'unit': 'kg',
  'reps': reps,
  'execution_status': status,
  'effort': '',
  'effort_scale': 'rir',
};

class HeldReadRepository extends WorkoutRepository {
  HeldReadRepository(super.db, super.ownerId);
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Json?> workout(String id) async {
    final result = await super.workout(id);
    if (hold) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return result;
  }
}

class HeldTimerRepository extends WorkoutRepository {
  HeldTimerRepository(super.db, super.ownerId);
  final entered = Completer<void>();
  final release = Completer<void>();
  bool first = true;
  var reads = 0;
  var failCancellation = false;
  @override
  Future<RestDisplay?> restDisplay(String id) async {
    reads++;
    final result = await super.restDisplay(id);
    if (first) {
      first = false;
      entered.complete();
      await release.future;
    }
    return result;
  }

  @override
  Future<void> cancelTimer(String id) async {
    if (failCancellation) {
      throw const FileSystemException('synthetic private cancellation detail');
    }
    await super.cancelTimer(id);
  }
}

class Harness {
  final WidgetTester tester;
  final directory = Directory.systemTemp.createTempSync('multi-exercise-ui-');
  late TrainingDatabase db;
  late WorkoutRepository repo;
  ProviderContainer? container;
  Harness(this.tester);
  Future<void> open() async {
    db = TrainingDatabase(
      NativeDatabase(File('${directory.path}/training.sqlite')),
    );
    repo = WorkoutRepository(db, ownerA);
    await repo.initialize();
  }

  Future<SavedRoutine> saveRoutine() => repo.saveRoutine(
    id: repo.newId(),
    expectedRevision: 0,
    plan: multiPlan(repo),
  );
  Future<String> start(SavedRoutine routine) => repo.startRoutine(
    routineId: routine.id,
    templateId: routine.templateId,
    attemptId: repo.newId(),
    timezone: 'UTC',
  );
  Future<void> mount(Widget home) async {
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    await container!.read(workoutsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(theme: motionTheme(Brightness.light), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container?.dispose();
    repo.dispose();
    await db.close();
    await deleteOwnedTemporaryDirectory(directory, 'multi-exercise-ui-');
  }

  Future<void> reopen() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container?.dispose();
    container = null;
    repo.dispose();
    await db.close();
    await open();
    await mount(
      const HomeScreen(syntheticFixture: false, localRoutinesEnabled: true),
    );
  }

  Future<void> reveal(Finder target) async {
    final scroll = find.byType(Scrollable).first;
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      target,
      350,
      scrollable: scroll,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
  }

  Future<void> record(
    String setId, {
    String reps = '6',
    String load = '25',
    String status = 'Completed',
    bool twice = false,
  }) async {
    final editor = find.byWidgetPredicate(
      (w) => w is SetEditor && w.item['set_id'] == setId && !w.correction,
    );
    await reveal(editor);
    final loadField = find.descendant(
      of: editor,
      matching: find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText?.startsWith('Load (') == true,
      ),
    );
    if (loadField.evaluate().isNotEmpty) {
      await reveal(loadField);
      await tester.enterText(loadField, load);
    }
    final repField = find.descendant(
      of: editor,
      matching: find.widgetWithText(TextField, 'Actual reps'),
    );
    await reveal(repField);
    await tester.enterText(repField, reps);
    final outcome = find.descendant(
      of: editor,
      matching: find.widgetWithText(DropdownButtonFormField<String>, 'Outcome'),
    );
    await reveal(outcome);
    await tester.tap(outcome);
    await tester.pumpAndSettle();
    await tester.tap(find.text(status).last);
    await tester.pumpAndSettle();
    final save = find.descendant(
      of: editor,
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    await reveal(save);
    if (twice) {
      final action = tester.widget<FilledButton>(save).onPressed!;
      action();
      action();
    } else {
      await tester.tap(save);
    }
    await tester.pumpAndSettle();
  }

  Future<void> correct(
    String setId, {
    String reps = '8',
    String reason = 'Corrected historical entry',
    String status = 'Completed',
  }) async {
    final row = find.byKey(ValueKey('set-$setId'));
    await reveal(row);
    await tester.tap(
      find.descendant(of: row, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final repField = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextField, 'Actual reps'),
    );
    await tester.ensureVisible(repField);
    await tester.enterText(repField, reps);
    final outcome = find.descendant(
      of: sheet,
      matching: find.widgetWithText(DropdownButtonFormField<String>, 'Outcome'),
    );
    await tester.ensureVisible(outcome);
    await tester.tap(outcome);
    await tester.pumpAndSettle();
    await tester.tap(find.text(status).last);
    await tester.pumpAndSettle();
    final reasonField = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextField, 'Correction reason'),
    );
    await tester.ensureVisible(reasonField);
    await tester.enterText(reasonField, reason);
    final save = find.text('Save correction');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }
}

void main() {
  Future<(Harness, HeldTimerRepository, String, Json)> persistedRest(
    WidgetTester tester,
  ) async {
    final h = Harness(tester);
    await h.open();
    addTearDown(h.close);
    final id = await h.start(await h.saveRoutine());
    h.repo.dispose();
    final held = HeldTimerRepository(h.db, ownerA)..first = false;
    h.repo = held;
    addTearDown(() {
      if (!held.release.isCompleted) held.release.complete();
    });
    final workout = (await h.repo.workout(id))!;
    final setup = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(held)],
    );
    try {
      await setup.read(workoutsProvider.future);
      final exercise = workout['exercises'][0] as Json;
      await setup
          .read(workoutsProvider.notifier)
          .record(id, exercise, exercise['sets'][0] as Json, entry());
    } finally {
      setup.dispose();
    }
    expect(await held.timerDeadline(id), isNotNull);
    await h.mount(WorkoutScreen(sessionId: id));
    await h.reveal(find.text('Cancel'));
    expect(await held.timerDeadline(id), isNotNull);
    held.first = true;
    await tester.pump(const Duration(seconds: 1));
    await held.entered.future;
    return (h, held, id, workout);
  }

  testWidgets('successful UI cancellation wins over a held old timer response', (
    tester,
  ) async {
    final (h, held, id, workout) = await persistedRest(tester);
    final reads = held.reads;
    await tester.tap(find.text('Cancel'));
    expect(await held.timerDeadline(id), isNull);
    await tester.pump();
    expect(find.text('Cancel'), findsNothing);

    // Do not advance the fake clock: an automatic follow-up tick must not hide
    // a transient resurrection from this response.
    held.release.complete();
    await tester.pump();
    expect(await held.timerDeadline(id), isNull);
    expect(find.text('Cancel'), findsNothing);
    expect(find.textContaining('Rest timer'), findsNothing);
    expect(held.reads, reads);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cancel'), findsNothing);
    expect(held.reads, reads);

    await h.record(
      workout['exercises'][1]['sets'][0]['set_id'] as String,
      load: '',
    );
    expect(await held.timerDeadline(id), isNotNull);
    await h.reveal(find.text('Cancel'));
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a set recorded after cancellation refreshes behind the held old read',
    (tester) async {
      final (h, held, id, workout) = await persistedRest(tester);
      final reads = held.reads;
      await tester.tap(find.text('Cancel'));
      expect(await held.timerDeadline(id), isNull);
      await tester.pump();
      await h.record(
        workout['exercises'][1]['sets'][0]['set_id'] as String,
        load: '',
      );
      expect(await held.timerDeadline(id), isNotNull);
      expect(held.reads, reads);
      held.release.complete();
      await tester.pumpAndSettle();
      await h.reveal(find.text('Cancel'));
      expect(find.text('Cancel'), findsOneWidget);
      expect(held.reads, greaterThan(reads));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed UI cancellation retains rest and permits retry and a new timer',
    (tester) async {
      final (h, held, id, workout) = await persistedRest(tester);
      final deadline = await held.timerDeadline(id);
      held.failCancellation = true;
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await held.timerDeadline(id), deadline);
      expect(
        find.text('Rest timer could not be cancelled. Retry.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('synthetic private cancellation detail'),
        findsNothing,
      );
      held.release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(await held.timerDeadline(id), deadline);

      held.failCancellation = false;
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await held.timerDeadline(id), isNull);
      expect(find.text('Cancel'), findsNothing);
      await h.record(
        workout['exercises'][2]['sets'][0]['set_id'] as String,
        load: '5',
      );
      expect(await held.timerDeadline(id), isNotNull);
      await h.reveal(find.text('Cancel'));
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a slow initial timer read cannot hide rest started by a later exercise',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      h.repo.dispose();
      final held = HeldTimerRepository(h.db, ownerA);
      h.repo = held;
      addTearDown(() {
        if (!held.release.isCompleted) held.release.complete();
      });
      await h.mount(WorkoutScreen(sessionId: id));
      await held.entered.future;
      final w = (await h.repo.workout(id))!;
      final e = w['exercises'][2] as Json;
      await h.container!
          .read(workoutsProvider.notifier)
          .record(id, e, e['sets'][0] as Json, entry(load: '5'));
      held.release.complete();
      await tester.pumpAndSettle();
      expect(await h.repo.timerDeadline(id), isNotNull);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets('rapid finish taps show only one confirmation', (tester) async {
    final h = Harness(tester);
    await h.open();
    addTearDown(h.close);
    final id = await h.start(await h.saveRoutine());
    await h.mount(WorkoutScreen(sessionId: id));
    await h.reveal(find.text('Finish workout'));
    final finish = find.widgetWithText(OutlinedButton, 'Finish workout');
    final action = tester.widget<OutlinedButton>(finish).onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.text('Finish workout?'), findsOneWidget);
    await tester.tap(find.text('Continue training'));
    await tester.pumpAndSettle();
    expect((await h.repo.workout(id))!['status'], 'active');
  });

  testWidgets(
    'an unsaved draft survives scrolling away after a draft write failure',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      await h.mount(WorkoutScreen(sessionId: id));
      final w = (await h.repo.workout(id))!;
      final setId = w['exercises'][2]['sets'][0]['set_id'];
      final editor = find.byWidgetPredicate(
        (w) => w is SetEditor && w.item['set_id'] == setId,
      );
      await h.reveal(editor);
      await h.db.customStatement(
        "CREATE TRIGGER reject_draft BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT,'synthetic draft fault'); END",
      );
      final reps = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextField, 'Actual reps'),
      );
      await tester.ensureVisible(reps);
      await tester.enterText(reps, '13');
      await tester.pumpAndSettle();
      expect(find.textContaining('Draft could not be saved'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await h.reveal(editor);
      final field = tester.widget<TextField>(
        find.descendant(
          of: editor,
          matching: find.widgetWithText(TextField, 'Actual reps'),
        ),
      );
      expect(field.controller!.text, '13');
      expect(
        allSets((await h.repo.workout(id))!)
            .every((s) => s['observation'] == null),
        true,
      );
    },
  );

  testWidgets(
    'routine to all-exercise logging, correction, completion and reopened history preserves the snapshot',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final routine = await h.saveRoutine();
      await h.mount(
        const HomeScreen(syntheticFixture: false, localRoutinesEnabled: true),
      );
      await tester.tap(find.text('My routines'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTC').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();
      final initial = (await h.repo.workouts()).single;
      final id = initial['aggregate_id'] as String;
      final exercises = (initial['exercises'] as List).cast<Json>();
      String setId(int e, int s) => exercises[e]['sets'][s]['set_id'] as String;
      expect(allSets(initial).every((s) => s['observation'] == null), true);
      await h.record(setId(0, 0), load: '0', twice: true);
      await h.record(setId(1, 0), load: '', reps: '9');
      await h.record(
        setId(2, 0),
        status: 'Failed attempt',
        reps: '0',
        load: '5',
      );
      await h.record(setId(0, 1), status: 'Partial', reps: '2', load: '20');
      await h.record(setId(1, 1), status: 'Skipped', load: '');
      await h.record(setId(2, 1), load: '5', reps: '7');
      await h.correct(setId(2, 1), reps: '8');
      final recorded = (await h.repo.workout(id))!;
      expect(
        allSets(recorded)
            .map((s) => s['observation']['completion_seq'])
            .toSet(),
        {1, 2, 3, 4, 5, 6},
      );
      expect(
        recorded['exercises'][1]['sets'][0]['observation']['actual']['load'],
        isNull,
      );
      expect(
        recorded['exercises'][2]['sets'][0]['observation']['execution_status'],
        'failed',
      );
      expect(
        recorded['exercises'][2]['sets'][1]['observation']['actual']['reps'],
        8,
      );
      expect(
        recorded['exercises'][0]['sets'][0]['observation']['actual']['load']['value'],
        '0',
      );
      await h.reveal(find.text('Finish workout'));
      await tester.tap(find.text('Finish workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect((await h.repo.workout(id))!['status'], 'completed');
      final completed = (await h.repo.workout(id))!;
      final frozen = await h.repo.prepareHead(id);
      final edited = routine.plan.json..['name'] = 'A different future routine';
      edited['exercises'][0]['sets'][0]['planned']['reps'] = 99;
      await h.repo.saveRoutine(
        id: routine.id,
        expectedRevision: 1,
        plan: RoutinePlan.fromJson(edited),
      );
      expect(await h.repo.workout(id), completed);
      expect(await h.repo.prepareHead(id), frozen);
      await h.reopen();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('5 attempted sets · 1 skipped · 0 unperformed'),
        findsOneWidget,
      );
      expect(find.textContaining('A different future routine'), findsNothing);
      await tester.tap(find.text('Three exercise routine'));
      await tester.pumpAndSettle();
      await h.reveal(find.text('Assisted pull-up'));
      expect(
        find.textContaining('corrected: Corrected historical entry'),
        findsOneWidget,
      );
      expect(await h.repo.workout(id), completed);
      await h.correct(
        setId(1, 0),
        status: 'Skipped',
        reason: 'This bodyweight entry was accidental',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4 attempted sets · 2 skipped · 0 unperformed'),
        findsOneWidget,
      );
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey(exerciseKey(completed['exercises'][0] as Json))),
      );
      await tester.pumpAndSettle();
      await h.reveal(find.byKey(ValueKey('performance-$id-${setId(0, 0)}')));
      expect(
        find.byKey(ValueKey('performance-$id-${setId(0, 0)}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('performance-$id-${setId(1, 0)}')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('performance-$id-${setId(0, 0)}')),
          matching: find.textContaining('completed · 0 kg ·'),
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey(exerciseKey(completed['exercises'][1] as Json))),
      );
      await tester.pumpAndSettle();
      await h.reveal(find.byKey(ValueKey('observation-$id-${setId(1, 0)}')));
      expect(
        find.textContaining('This bodyweight entry was accidental'),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('performance-$id-${setId(1, 0)}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved routine exposes all three exercise instances and conventions',
    (tester) async {
      tester.view.physicalSize = const Size(900, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      expect(((await h.repo.workout(id))!['exercises'] as List).length, 3);
      await h.mount(WorkoutScreen(sessionId: id));
      expect(find.text('Single-arm row'), findsOneWidget);
      expect(find.text('Push-up'), findsOneWidget);
      expect(find.text('Assisted pull-up'), findsOneWidget);
      expect(
        find.textContaining('Total external load · bilateral reps'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'bodyweight-only actual observations open Progress without a fictitious load',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      final state = (await h.repo.workout(id))!;
      final e = (state['exercises'] as List)[1] as Json;
      final item = (e['sets'] as List).first as Json;
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(h.repo)],
      );
      await c.read(workoutsProvider.future);
      await c
          .read(workoutsProvider.notifier)
          .record(id, e, item, entry(load: ''));
      await c.read(workoutsProvider.notifier).finish(id);
      c.dispose();
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Bench press'), findsNothing);
      expect(find.textContaining('Push-up'), findsOneWidget);
      expect(find.textContaining('0 kg'), findsNothing);
    },
  );

  test('simultaneous controller saves read a fresh completion sequence for each exercise', () async {
    final db = TrainingDatabase(NativeDatabase.memory());
    final repo = HeldReadRepository(db, ownerA);
    await repo.initialize();
    final saved = await repo.saveRoutine(
      id: repo.newId(),
      expectedRevision: 0,
      plan: multiPlan(repo),
    );
    final id = await repo.startRoutine(
      routineId: saved.id,
      templateId: saved.templateId,
      attemptId: repo.newId(),
      timezone: 'UTC',
    );
    final state = (await repo.workout(id))!;
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(() async {
      container.dispose();
      repo.dispose();
      await db.close();
    });
    await container.read(workoutsProvider.future);
    repo.hold = true;
    final futures = [
      for (final e in (state['exercises'] as List).cast<Json>())
        container
            .read(workoutsProvider.notifier)
            .record(id, e, (e['sets'] as List).first as Json, entry()),
    ];
    await repo.entered.future;
    await db.transaction(() async {
      await db.customSelect('SELECT 1').get();
    });
    repo.release.complete();
    expect(await Future.wait(futures), [true, true, true]);
    final after = (await repo.workout(id))!;
    expect(
      allSets(after)
          .where((s) => s['observation'] != null)
          .map((s) => s['observation']['completion_seq'])
          .toList(),
      [1, 2, 3],
    );
  });

  test(
    'an in-flight save cannot switch its repository to a different owner',
    () async {
      final dbA = TrainingDatabase(NativeDatabase.memory());
      final dbB = TrainingDatabase(NativeDatabase.memory());
      final a = HeldReadRepository(dbA, ownerA);
      final b = WorkoutRepository(dbB, ownerB);
      await a.initialize();
      await b.initialize();
      final plan = multiPlan(a);
      final saved = await a.saveRoutine(
        id: a.newId(),
        expectedRevision: 0,
        plan: plan,
      );
      final id = await a.startRoutine(
        routineId: saved.id,
        templateId: saved.templateId,
        attemptId: a.newId(),
        timezone: 'UTC',
      );
      await b.commit(id, 'create_session', plan.json);
      final state = (await a.workout(id))!;
      final e = (state['exercises'] as List).first as Json;
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(a)],
      );
      addTearDown(() async {
        container.dispose();
        a.dispose();
        b.dispose();
        await dbA.close();
        await dbB.close();
      });
      await container.read(workoutsProvider.future);
      a.hold = true;
      final saving = container
          .read(workoutsProvider.notifier)
          .record(id, e, (e['sets'] as List).first as Json, entry());
      await a.entered.future;
      await a.signOut();
      container.updateOverrides([repositoryProvider.overrideWithValue(b)]);
      a.release.complete();
      await expectLater(saving, throwsA(isA<WorkoutValidation>()));
      expect(
        allSets((await b.workout(id))!).every((s) => s['observation'] == null),
        true,
      );
    },
  );
}
