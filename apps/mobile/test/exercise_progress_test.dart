import 'dart:async';

import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/exercise_history_provider.dart';
import 'package:daily_motion/features/exercise_progress.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'multi_exercise_test.dart' show Harness, entry;
import 'exercise_history_provider_test.dart' show LargeProjection;
import 'exercise_history_test.dart' show exercise, workout;

Future<(String, Json)> recorded(
  Harness h, {
  String reps = '6',
  String? routine,
  String? template,
  bool abandon = false,
}) async {
  final saved = routine == null ? await h.saveRoutine() : null;
  final id = await h.repo.startRoutine(
    routineId: routine ?? saved!.id,
    templateId: template ?? saved!.templateId,
    attemptId: h.repo.newId(),
    timezone: 'UTC',
  );
  final c = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(h.repo)],
  );
  try {
    await c.read(workoutsProvider.future);
    final w = (await h.repo.workout(id))!;
    final e = w['exercises'][0] as Json;
    await c
        .read(workoutsProvider.notifier)
        .record(id, e, e['sets'][0] as Json, entry(reps: reps));
    await c.read(workoutsProvider.notifier).finish(id, abandon: abandon);
    return (id, e);
  } finally {
    c.dispose();
  }
}

void main() {
  testWidgets(
    'filters reset later pages and paginate all matching sources in either date order',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final e = exercise(unit: 'lb');
      final source = [
        for (var i = 1; i <= 25; i++)
          workout('ordered-$i', [
            exercise(
              unit: i <= 14 ? 'lb' : 'kg',
              status: i <= 14 ? 'completed' : 'partial',
            ),
          ], date: DateTime.utc(2026, 9, i).toIso8601String()),
      ];
      final repo = LargeProjection(db, 'synthetic-owner', source);
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        repo.dispose();
        await db.close();
      });
      await c.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: ExerciseHistoryScreen(
              identity: exerciseKey(e),
              onOpenWorkout: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts 21–25 of 25'), findsOneWidget);
      Future<void> reveal(Finder target) async {
        final scroll = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(target, 250, scrollable: scroll);
        await tester.pumpAndSettle();
      }

      final completedToggle = find.widgetWithText(
        SwitchListTile,
        'Completed working sets only',
      );
      await reveal(completedToggle);
      await tester.tap(completedToggle);
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 14'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-ordered-14')));
      final dateToggle = find.widgetWithText(
        SwitchListTile,
        'Oldest workouts first',
      );
      await reveal(dateToggle);
      await tester.tap(dateToggle);
      await tester.pumpAndSettle();
      await reveal(find.byKey(const ValueKey('source-workout-ordered-1')));
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts 11–14 of 14'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-ordered-11')));
      final dropdown = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Recorded load unit',
      );
      await reveal(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 14'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-ordered-1')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final filter in ['completed working', 'recorded unit']) {
    testWidgets('$filter filters matching source workouts before pagination', (
      tester,
    ) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final partial = exercise(status: 'partial');
      final completed = exercise(unit: 'lb');
      completed['session_exercise_id'] = 'second-instance';
      completed['sets'][0]['set_id'] = 'second-set';
      final source = [
        workout('older-match', [
          copyJson(partial),
          completed,
        ], date: '2026-09-01T12:00:00Z'),
        for (var i = 2; i <= 15; i++)
          workout('newer-$i', [
            exercise(
              status: i.isEven ? 'partial' : 'completed',
              setClass: i.isEven ? 'working' : 'warmup',
            ),
          ], date: DateTime.utc(2026, 9, i).toIso8601String()),
      ];
      final repo = LargeProjection(db, 'synthetic-owner', source);
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final opened = <String>[];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        repo.dispose();
        await db.close();
      });
      await c.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: ExerciseHistoryScreen(
              identity: exerciseKey(completed),
              onOpenWorkout: opened.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 15'), findsOneWidget);
      Future<void> reveal(Finder target) async {
        final scroll = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(target, 250, scrollable: scroll);
        await tester.pumpAndSettle();
      }

      Future<void> chooseUnit(String text) async {
        final dropdown = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Recorded load unit',
        );
        await reveal(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
      }

      if (filter == 'completed working') {
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Completed working sets only'),
        );
        await tester.pumpAndSettle();
      } else {
        await chooseUnit('lb');
      }
      expect(find.text('Workouts 1–1 of 1'), findsOneWidget);
      final older = find.byKey(const ValueKey('source-workout-older-match'));
      await reveal(older);
      await tester.tap(older);
      expect(opened, ['older-match']);
      final value = find.byKey(
        const ValueKey('performance-older-match-second-set'),
      );
      await reveal(value);
      expect(
        find.descendant(
          of: value,
          matching: find.textContaining('0 lb · 5 reps'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('observation-older-match-set-variant-a-both'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next page'))
            .onPressed,
        isNull,
      );
      // No completed working kg observations exist, despite newer kg contexts.
      if (filter == 'recorded unit') {
        await reveal(
          find.widgetWithText(SwitchListTile, 'Completed working sets only'),
        );
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Completed working sets only'),
        );
        await tester.pumpAndSettle();
      }
      await chooseUnit('kg');
      expect(find.text('Workouts 0 of 0'), findsOneWidget);
      await reveal(
        find.text(
          'No source workouts match these filters. Show all outcomes or choose another recorded unit.',
        ),
      );
      expect(
        find.byKey(const ValueKey('source-workout-older-match')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next page'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Previous page'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a real historical correction clamps the filtered last page and preserves all outcomes',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      var now = DateTime.utc(2026, 9, 1);
      final owner = h.repo.ownerId;
      h.repo.dispose();
      h.repo = WorkoutRepository(h.db, owner, clock: () => now);
      final routine = await h.saveRoutine();
      late String oldest;
      late Json firstExercise;
      for (var i = 1; i <= 11; i++) {
        now = DateTime.utc(2026, 9, i);
        final (id, e) = await recorded(
          h,
          routine: routine.id,
          template: routine.templateId,
        );
        if (i == 1) {
          oldest = id;
          firstExercise = e;
        }
      }
      await h.mount(
        ExerciseHistoryScreen(
          identity: exerciseKey(firstExercise),
          onOpenWorkout: (_) {},
        ),
      );
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Completed working sets only',
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts 11–11 of 11'), findsOneWidget);
      final before = copyJson((await h.repo.workout(oldest))!);
      await h.container!
          .read(workoutsProvider.notifier)
          .record(
            oldest,
            firstExercise,
            firstExercise['sets'][0] as Json,
            entry(status: 'skipped'),
            reason: 'This historical set was not performed',
          );
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 10'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next page'))
            .onPressed,
        isNull,
      );
      expect(find.byKey(ValueKey('source-workout-$oldest')), findsNothing);
      await h.reveal(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 11'), findsOneWidget);
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      final skipped = find.byKey(
        ValueKey('observation-$oldest-${firstExercise['sets'][0]['set_id']}'),
      );
      await h.reveal(skipped);
      expect(
        find.descendant(
          of: skipped,
          matching: find.textContaining('skipped · No performance recorded'),
        ),
        findsOneWidget,
      );
      expect(
        (await h.repo.workout(oldest))!['exercises'][0]['sets'][0]['planned'],
        before['exercises'][0]['sets'][0]['planned'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'previous performance retains the source workout conflict warning',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final routine = await h.saveRoutine();
      final (id, _) = await recorded(
        h,
        routine: routine.id,
        template: routine.templateId,
      );
      // The query consumes the existing persisted conflict marker. This fixture
      // tests its presentation, not the protocol that establishes that marker.
      await h.db.customStatement(
        'UPDATE sessions SET has_conflict=1 WHERE id=?',
        [id],
      );
      final active = await h.start(routine);
      await h.mount(WorkoutScreen(sessionId: active));
      final reference = find.byType(PreviousPerformance).first;
      await h.reveal(reference);
      expect(
        find.descendant(
          of: reference,
          matching: find.text('Saved on this device · sync needs review'),
        ),
        findsOneWidget,
      );
      expect((await h.repo.workout(id))!['conflict'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'exercise browsing bounds entries while search reaches later identities',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final source = workout('many-exercises', [
        for (var i = 0; i < 85; i++)
          exercise(variant: 'variant-$i', name: 'Exercise $i'),
      ]);
      final repo = LargeProjection(db, 'synthetic-owner', [source]);
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        repo.dispose();
        await db.close();
      });
      await c.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseProgress(onOpenWorkout: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(30));
      await tester.enterText(
        find.byKey(const ValueKey('exercise-search')),
        'Exercise 84',
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Exercise 84'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exercise pages bound rendered sources and navigate chronologically without dropping observations',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final e = exercise();
      final source = [
        for (var i = 1; i <= 25; i++)
          workout('root-$i', [
            copyJson(e),
          ], date: DateTime.utc(2026, 9, i).toIso8601String()),
      ];
      final repo = LargeProjection(db, 'synthetic-owner', source);
      final c = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        repo.dispose();
        await db.close();
      });
      await c.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: ExerciseHistoryScreen(
              identity: exerciseKey(e),
              onOpenWorkout: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 25'), findsOneWidget);
      expect(find.byType(Card).evaluate().length, lessThan(20));
      Future<void> reveal(Finder target) async {
        final scroll = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(target, 250, scrollable: scroll);
        await tester.pumpAndSettle();
      }

      await reveal(find.byKey(const ValueKey('source-workout-root-25')));
      expect(
        find.byKey(const ValueKey('source-workout-root-25')),
        findsOneWidget,
      );
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts 11–20 of 25'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-root-15')));
      expect(
        find.byKey(const ValueKey('source-workout-root-25')),
        findsNothing,
      );
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts 21–25 of 25'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-root-5')));
      await reveal(
        find.widgetWithText(SwitchListTile, 'Oldest workouts first'),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Oldest workouts first'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Workouts 1–10 of 25'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('source-workout-root-1')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Progress navigates an exercise from real saved workout history',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      await h.mount(const HomeScreen(syntheticFixture: false));
      final w = (await h.repo.workout(id))!;
      final e = w['exercises'][0] as Map<String, dynamic>;
      final c = h.container!.read(workoutsProvider.notifier);
      await c.record(
        id,
        e,
        e['sets'][0] as Map<String, dynamic>,
        entry(load: '0'),
      );
      await c.finish(id);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(exerciseKey(e))), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(exerciseKey(e))));
      await tester.pumpAndSettle();
      await h.reveal(
        find.byKey(ValueKey('performance-$id-${e['sets'][0]['set_id']}')),
      );
      expect(find.textContaining('completed · 0 kg · 6 reps'), findsOneWidget);
    },
  );

  testWidgets(
    'source correction refreshes chronological exercise history and survives SQLite reopening offline',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final routine = await h.saveRoutine();
      final (oldId, _) = await recorded(
        h,
        routine: routine.id,
        template: routine.templateId,
        reps: '5',
      );
      final (id, e) = await recorded(
        h,
        routine: routine.id,
        template: routine.templateId,
        reps: '8',
      );
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 recorded workouts'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(exerciseKey(e))));
      await tester.pumpAndSettle();
      final source = find.byKey(ValueKey('source-workout-$id'));
      await h.reveal(source);
      await tester.tap(source);
      await tester.pumpAndSettle();
      final frozen = copyJson((await h.repo.workout(id))!);
      final setId = e['sets'][0]['set_id'] as String;
      await h.correct(
        setId,
        reps: '9',
        reason: 'Read the original training log',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('performance-$id-$setId'));
      await h.reveal(row);
      expect(
        find.descendant(of: row, matching: find.textContaining('9 reps')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('8 reps')),
        findsNothing,
      );
      expect(
        h.container!
            .read(exerciseHistoryProvider)
            .requireValue
            .byExercise[exerciseKey(e)]!
            .visits,
        hasLength(2),
      );
      final after = (await h.repo.workout(id))!;
      expect(
        after['exercises'][0]['sets'][0]['planned'],
        frozen['exercises'][0]['sets'][0]['planned'],
      );
      expect(after['aggregate_id'], id);
      await h.reopen();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(exerciseKey(e))));
      await tester.pumpAndSettle();
      await h.reveal(row);
      expect(
        find.descendant(of: row, matching: find.textContaining('9 reps')),
        findsOneWidget,
      );
      final index = h.container!.read(exerciseHistoryProvider).requireValue;
      expect(
        index.byExercise[exerciseKey(e)]!.visits.map(
          (v) => v.workout['aggregate_id'],
        ),
        [id, oldId],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'previous reference excludes current work and remains separate from actual editor drafts',
    (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final routine = await h.saveRoutine();
      final (previousId, _) = await recorded(
        h,
        routine: routine.id,
        template: routine.templateId,
        reps: '12',
      );
      final frozen = copyJson((await h.repo.workout(previousId))!);
      final editedPlan = routine.plan.json;
      editedPlan['exercises'][0]['sets'][0]['planned']['reps'] = 99;
      final edited = await h.repo.saveRoutine(
        id: routine.id,
        expectedRevision: 1,
        plan: RoutinePlan.fromJson(editedPlan),
      );
      final active = await h.start(edited);
      expect(await h.repo.workout(previousId), frozen);
      final w = (await h.repo.workout(active))!;
      final e = w['exercises'][0] as Json;
      final setId = e['sets'][0]['set_id'] as String;
      await h.mount(WorkoutScreen(sessionId: active));
      final reference = find.byType(PreviousPerformance).first;
      await h.reveal(reference);
      expect(
        find.descendant(
          of: reference,
          matching: find.textContaining('12 reps'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No previous comparable'), findsNWidgets(2));
      expect(
        find.descendant(
          of: reference,
          matching: find.textContaining('99 reps'),
        ),
        findsNothing,
      );
      final editor = find.byWidgetPredicate(
        (w) => w is SetEditor && w.item['set_id'] == setId,
      );
      await h.reveal(editor);
      final field = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextField, 'Actual reps'),
      );
      await h.reveal(field);
      await tester.enterText(field, '3');
      await tester.pumpAndSettle();
      expect((await h.repo.draft(setId))!['reps'], '3');
      expect(
        allSets((await h.repo.workout(active))!)
            .every((s) => s['observation'] == null),
        isTrue,
      );
      await h.reveal(reference);
      await tester.tap(
        find.descendant(of: reference, matching: find.text('Source workout')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('completed ·'), findsWidgets);
      final source = (await h.repo.workout(previousId))!;
      await h.correct(
        source['exercises'][0]['sets'][0]['set_id'] as String,
        reps: '13',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await h.reveal(reference);
      expect(
        find.descendant(
          of: reference,
          matching: find.textContaining('13 reps'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: reference,
          matching: find.textContaining('12 reps'),
        ),
        findsNothing,
      );
      await h.reveal(field);
      expect(tester.widget<TextField>(field).controller!.text, '3');
      await h.record(setId, reps: '3');
      await h.reveal(reference);
      expect(
        find.descendant(
          of: reference,
          matching: find.textContaining('13 reps'),
        ),
        findsOneWidget,
      );
      expect(await h.repo.timerDeadline(active), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slow or failed history indexing never prevents actual set entry and retry',
    (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      final gate = Completer<ExerciseHistoryIndex>();
      var first = true;
      h.container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(h.repo),
          exerciseHistoryProvider.overrideWith((ref) {
            if (first) {
              first = false;
              return gate.future;
            }
            return h.repo.workouts().then(buildExerciseHistory);
          }),
        ],
      );
      await h.container!.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container!,
          child: MaterialApp(home: WorkoutScreen(sessionId: id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading previous performance…'), findsNWidgets(3));
      final w = (await h.repo.workout(id))!;
      await h.record(
        w['exercises'][1]['sets'][0]['set_id'] as String,
        load: '',
        reps: '7',
      );
      expect(
        (await h.repo.workout(
          id,
        ))!['exercises'][1]['sets'][0]['observation']['actual']['reps'],
        7,
      );
      gate.completeError(StateError('private fixture storage detail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('private fixture'), findsNothing);
      expect(find.byType(HistoryReadError), findsNWidgets(3));
      await h.record(
        w['exercises'][2]['sets'][0]['set_id'] as String,
        load: '6',
        reps: '0',
        status: 'Failed attempt',
      );
      expect(completionSequence((await h.repo.workout(id))!), 2);
      await tester.tap(find.text('Retry exercise history').first);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryReadError), findsNothing);
      expect(find.textContaining('No previous comparable'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty search and large text exercise navigation fit a narrow offline screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final (_, e) = await recorded(h);
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('exercise-search'));
      await h.reveal(search);
      await tester.enterText(search, 'missing');
      await tester.pumpAndSettle();
      expect(
        find.text('No recorded exercise matches this search.'),
        findsOneWidget,
      );
      await tester.enterText(search, 'single');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey(exerciseKey(e)));
      await h.reveal(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await h.reveal(find.text('Next page'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open exercise route hides cached observations on sign-out and authoritative disable',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final (id, e) = await recorded(h);
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      final row = find.byKey(
        ValueKey('performance-$id-${e['sets'][0]['set_id']}'),
      );
      await h.reveal(row);
      expect(row, findsOneWidget);
      await h.repo.signOut();
      await h.container!.read(workoutsProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(
        find.textContaining('Exercise history could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('25 kg'), findsNothing);
      await h.repo.unlockVerifiedOwner(h.repo.ownerId);
      await h.container!.read(workoutsProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await h.reveal(row);
      expect(row, findsOneWidget);
      await h.repo.disableRemoteAccount();
      await h.container!.read(workoutsProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.textContaining('25 kg'), findsNothing);
      expect(
        find.textContaining('Exercise history could not be loaded'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a corrected unit cannot leave an invisible stale load-unit filter',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final (id, e) = await recorded(h);
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      final filter = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Recorded load unit',
      );
      await h.reveal(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();
      await h.container!.read(workoutsProvider.notifier).record(
        id,
        e,
        e['sets'][0] as Json,
        {...entry(load: '55'), 'unit': 'lb'},
        reason: 'Original note was in pounds',
      );
      await tester.pumpAndSettle();
      final row = find.byKey(
        ValueKey('performance-$id-${e['sets'][0]['set_id']}'),
      );
      await h.reveal(row);
      expect(
        find.descendant(of: row, matching: find.textContaining('55 lb')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
