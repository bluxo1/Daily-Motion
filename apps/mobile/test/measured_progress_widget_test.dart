import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/measured_progress.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/features/exercise_progress.dart';
import 'package:daily_motion/features/exercise_history_provider.dart';
import 'package:daily_motion/features/measured_progress_provider.dart';
import 'package:daily_motion/features/measured_progress_view.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_history_provider_test.dart' show LargeProjection, HeldWorkouts;
import 'exercise_history_test.dart' show exercise, workout;
import 'multi_exercise_test.dart' show Harness, entry, multiPlan;
import 'exercise_progress_test.dart' show recorded;

Future<ProviderContainer> mountProjection(
  WidgetTester tester,
  List<Json> source,
  Json e, {
  Brightness brightness = Brightness.light,
  ValueChanged<String>? onOpen,
}) async {
  final db = TrainingDatabase(NativeDatabase.memory());
  final repo = LargeProjection(db, 'controlled-owner', source);
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
        theme: motionTheme(brightness),
        home: ExerciseHistoryScreen(
          identity: exerciseKey(e),
          onOpenWorkout: onOpen ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: scroll,
      maxScrolls: 100,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
}

// Native isolates and widget frame callbacks must both be allowed to finish.
Future<T> drain<T>(WidgetTester tester, Future<T> operation) async {
  var finished = false;
  T? result;
  Object? failure;
  StackTrace? trace;
  operation.then(
    (value) {
      result = value;
      finished = true;
    },
    onError: (Object error, StackTrace stack) {
      failure = error;
      trace = stack;
      finished = true;
    },
  );
  for (var i = 0; i < 2000 && !finished; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(finished, isTrue, reason: 'Worker/read operation must complete.');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result as T;
}

/// Wait for the current subscribed view, not a Future sampled before its build.
/// pumpAndSettle only drains scheduled frames; native workers can still be busy.
Future<MeasuredProgress> waitForMeasuredChart(
  WidgetTester tester,
  ProviderContainer container,
  ExerciseKey identity, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final elapsed = Stopwatch()..start();
  String historyState = 'not inspected';
  String measuredState = 'not inspected';
  Never fail(String reason) => throw TestFailure(
    '$reason\nExercise history: $historyState\nMeasured history: $measuredState\n'
    'Chart widgets: ${find.byType(MeasuredScatter).evaluate().length}; '
    'scrollables: ${find.byType(Scrollable).evaluate().length}\n'
    '${tester.binding.rootElement?.toStringDeep()}',
  );
  while (true) {
    // Small histories use Future() on the fake timer queue; large histories use
    // a real worker. Advance the fake clock as well as yielding below.
    await tester.pump(const Duration(milliseconds: 1));
    final pending = tester.takeException();
    if (pending != null) {
      fail('Flutter exception while waiting for measured chart: $pending');
    }
    final views = find.byType(MeasuredProgressView).evaluate().toList();
    if (views.length != 1 ||
        (views.single.widget as MeasuredProgressView).identity != identity) {
      fail('Expected measured view disappeared or changed exercise.');
    }
    final history = container.read(exerciseHistoryProvider);
    final measured = container.read(measuredProgressProvider(identity));
    historyState = 'loading=${history.isLoading}, error=${history.error}';
    measuredState =
        'loading=${measured.isLoading}, error=${measured.error}, '
        'points=${measured.asData?.value.repetitions.length}';
    if (history.hasError || measured.hasError) {
      fail('Provider failure while waiting for measured chart.');
    }
    if (!history.isLoading &&
        !measured.isLoading &&
        measured.asData != null &&
        find.byType(MeasuredScatter).evaluate().length == 1 &&
        find.byType(Scrollable).evaluate().isNotEmpty) {
      return measured.requireValue;
    }
    if (elapsed.elapsed >= timeout) {
      fail('Timed out waiting for the rendered measured chart.');
    }
    // Give real isolate/read completions an event-loop turn, then recheck UI.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
}

Future<TestFailure> chartReadinessFailure(
  Future<MeasuredProgress> Function() action,
) async {
  try {
    await action();
  } on TestFailure catch (failure) {
    return failure;
  }
  throw TestFailure('The readiness guard unexpectedly succeeded.');
}

Future<void> chooseMetric(WidgetTester tester, String label) async {
  final field = find.byType(DropdownButtonFormField<MeasuredMetric>);
  await reveal(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder row(String root, Json e, [int ordinal = 0]) => find.byKey(
  ValueKey((
    'measured-point',
    (
      root,
      e['session_exercise_id'] as String,
      e['sets'][ordinal]['set_id'] as String,
    ),
  )),
);

void main() {
  testWidgets(
    'chart readiness reports real owner-access failures without showing old data',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final (_, e) = await recorded(h);
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      await tester.tap(find.text('Measured charts'));
      await waitForMeasuredChart(tester, h.container!, exerciseKey(e));
      await h.repo.signOut();
      await h.container!.read(workoutsProvider.notifier).refresh();
      final failure = await chartReadinessFailure(
        () => waitForMeasuredChart(tester, h.container!, exerciseKey(e)),
      );
      expect(
        failure.message,
        allOf(
          contains('Provider failure'),
          contains('Exercise history:'),
          contains('Measured history:'),
        ),
      );
      expect(find.byType(MeasuredScatter), findsNothing);
      expect(find.textContaining('25 kg'), findsNothing);
    },
  );

  testWidgets(
    'chart readiness reports a removed view instead of reading a missing scrollable',
    (tester) async {
      final e = exercise();
      final c = await mountProjection(tester, [
        workout('one', [e]),
      ], e);
      await tester.tap(find.text('Measured charts'));
      await waitForMeasuredChart(tester, c, exerciseKey(e));
      await tester.pumpWidget(const SizedBox.shrink());
      final failure = await chartReadinessFailure(
        () => waitForMeasuredChart(tester, c, exerciseKey(e)),
      );
      expect(failure.message, contains('view disappeared'));
    },
  );

  testWidgets(
    'chart readiness times out diagnostically on a held real read and later recovers',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final owner = h.repo.ownerId;
      h.repo.dispose();
      final held = HeldWorkouts(h.db, owner);
      h.repo = held;
      final (_, e) = await recorded(h);
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      await tester.tap(find.text('Measured charts'));
      await waitForMeasuredChart(tester, h.container!, exerciseKey(e));
      held.hold = true;
      h.container!.invalidate(workoutsProvider);
      try {
        final failure = await chartReadinessFailure(
          () => waitForMeasuredChart(
            tester,
            h.container!,
            exerciseKey(e),
            timeout: const Duration(milliseconds: 50),
          ),
        );
        expect(
          failure.message,
          allOf(
            contains('Timed out'),
            contains('loading=true'),
            contains('scrollables: 0'),
          ),
        );
        expect(
          find.textContaining('Loading measured observations'),
          findsOneWidget,
        );
      } finally {
        held.hold = false;
        held.release.complete();
      }
      await drain(tester, h.container!.read(workoutsProvider.future));
      final recovered = await waitForMeasuredChart(
        tester,
        h.container!,
        exerciseKey(e),
      );
      expect(recovered.repetitions, hasLength(1));
    },
  );

  testWidgets(
    'chart readiness turns a pending Flutter exception into a diagnostic failure',
    (tester) async {
      final e = exercise();
      final c = await mountProjection(tester, [
        workout('one', [e]),
      ], e);
      await tester.tap(find.text('Measured charts'));
      await waitForMeasuredChart(tester, c, exerciseKey(e));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('controlled readiness exception'),
        ),
      );
      final failure = await chartReadinessFailure(
        () => waitForMeasuredChart(tester, c, exerciseKey(e)),
      );
      expect(failure.message, contains('controlled readiness exception'));
    },
  );

  testWidgets(
    'real corrections clamp the oldest page and replace a removed selected unit',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final plan = multiPlan(h.repo).json;
      final exercise = plan['exercises'][0] as Json;
      exercise['sets'] = [
        for (var i = 0; i < 81; i++)
          {...copyJson(exercise['sets'][0] as Json), 'set_id': h.repo.newId()},
      ];
      final saved = await h.repo.saveRoutine(
        id: h.repo.newId(),
        expectedRevision: 0,
        plan: RoutinePlan.fromJson({
          ...plan,
          'exercises': [exercise],
        }),
      );
      final id = await h.start(saved);
      final w = (await h.repo.workout(id))!;
      final e = w['exercises'][0] as Json;
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      final controller = h.container!.read(workoutsProvider.notifier);
      for (final set in (e['sets'] as List).cast<Json>()) {
        await controller.record(id, e, set, entry(load: '22.500000'));
      }
      await controller.finish(id);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      expect(find.text('Observations 2–81 of 81'), findsOneWidget);
      await tester.tap(find.text('Older observations'));
      await tester.pumpAndSettle();
      expect(find.text('Observations 1–1 of 81'), findsOneWidget);
      await controller.record(
        id,
        e,
        e['sets'][0] as Json,
        entry(status: 'skipped'),
        reason: 'Original notes show no attempted work for this set',
      );
      await tester.pumpAndSettle();
      expect(find.text('Observations 1–80 of 80'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Older observations'),
            )
            .onPressed,
        isNull,
      );
      final last = e['sets'][80] as Json;
      await controller.record(id, e, last, {
        ...entry(load: '49.000000'),
        'unit': 'lb',
      }, reason: 'Original notebook used pounds');
      await tester.pumpAndSettle();
      final unit = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Chart load unit',
      );
      await h.reveal(unit);
      await tester.tap(unit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();
      await h.reveal(row(id, e, 80));
      expect(find.text('49.000000 lb'), findsOneWidget);
      await controller.record(
        id,
        e,
        last,
        entry(load: '22.500000'),
        reason: 'Verified original unit was kilograms',
      );
      await tester.pumpAndSettle();
      await h.reveal(
        find.text(
          'The previous unit has no eligible measurements. Showing kg.',
        ),
      );
      expect(
        find.text(
          'The previous unit has no eligible measurements. Showing kg.',
        ),
        findsOneWidget,
      );
      expect(find.text('Observations 1–80 of 80'), findsOneWidget);
      final source = (await h.repo.workout(id))!;
      expect(
        source['exercises'][0]['sets'][0]['observation']['execution_status'],
        'skipped',
      );
      expect(
        source['exercises'][0]['sets'][80]['planned'],
        w['exercises'][0]['sets'][80]['planned'],
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      '320px and 200 percent text retain exact values in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final e = exercise(load: '9999999.999999');
        final low = exercise(load: '0.000001');
        low['session_exercise_id'] = 'low-instance';
        low['sets'][0]['set_id'] = 'low-set';
        await mountProjection(
          tester,
          [
            workout('high', [e]),
            workout('low', [low]),
          ],
          e,
          brightness: brightness,
        );
        await tester.tap(find.text('Measured charts'));
        await tester.pumpAndSettle();
        await reveal(tester, find.byType(MeasuredScatter));
        expect(find.byKey(const ValueKey('measured-scatter')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await reveal(tester, row('high', e));
        expect(find.text('9999999.999999 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await chooseMetric(tester, 'Performed repetitions');
        await reveal(tester, row('low', low));
        expect(find.textContaining('0.000001 kg'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Source history'));
        await tester.pumpAndSettle();
        expect(find.text('Completed working sets only'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keyboard traversal activates an exact source observation', (
    tester,
  ) async {
    final e = exercise(load: '14.25');
    final opened = <String>[];
    await mountProjection(
      tester,
      [
        workout('keyboard-source', [e]),
      ],
      e,
      onOpen: opened.add,
    );
    await tester.tap(find.text('Measured charts'));
    await tester.pumpAndSettle();
    final target = row('keyboard-source', e);
    await reveal(tester, target);
    final tile = find.descendant(of: target, matching: find.byType(ListTile));
    // Traverse the real Focus tree; do not invoke the callback directly.
    FocusManager.instance.primaryFocus?.unfocus();
    var focused = false;
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (Focus.of(
        tester.element(
          find.descendant(of: tile, matching: find.byType(Text)).first,
        ),
      ).hasFocus) {
        focused = true;
        break;
      }
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, ['keyboard-source']);
  });

  testWidgets(
    'opening measured history preserves the active draft and persisted rest deadline',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final saved = await h.saveRoutine();
      await recorded(h, routine: saved.id, template: saved.templateId);
      final id = await h.start(saved);
      final w = (await h.repo.workout(id))!;
      final e = w['exercises'][0] as Json;
      final first = e['sets'][0]['set_id'] as String;
      final second = e['sets'][1]['set_id'] as String;
      await h.mount(WorkoutScreen(sessionId: id));
      await h.record(first, reps: '8');
      final deadline = await h.repo.timerDeadline(id);
      expect(deadline, isNotNull);
      final editor = find.byWidgetPredicate(
        (v) => v is SetEditor && v.item['set_id'] == second,
      );
      await h.reveal(editor);
      final reps = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextField, 'Actual reps'),
      );
      await h.reveal(reps);
      await tester.enterText(reps, '17');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final draft = await h.repo.draft(second);
      expect(draft!['reps'], '17');
      await h.reveal(find.text('Exercise history').first);
      await tester.tap(find.text('Exercise history').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      await h.reveal(find.byType(MeasuredScatter));
      final measured = await h.container!.read(
        measuredProgressProvider(exerciseKey(e)).future,
      );
      expect(measured.repetitions.any((p) => p.workoutId == id), isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await h.reveal(reps);
      expect(tester.widget<TextField>(reps).controller!.text, '17');
      expect(await h.repo.draft(second), draft);
      expect(await h.repo.timerDeadline(id), deadline);
      expect(
        (await h.repo.workout(id))!['exercises'][0]['sets'][1]['observation'],
        isNull,
      );
      await h.record(second, reps: '17');
      expect(
        (await h.repo.workout(
          id,
        ))!['exercises'][0]['sets'][1]['observation']['actual']['reps'],
        17,
      );
      expect(await h.repo.draft(second), isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'recorded exercise history exposes source-backed measured charts',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final e = exercise(load: '12.500000');
      final repo = LargeProjection(db, 'controlled-owner', [
        workout('source', [e]),
      ]);
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
      expect(find.text('Measured charts'), findsOneWidget);
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      expect(find.text('Measured working sets'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('12.500000 kg'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('12.500000 kg'), findsWidgets);
    },
  );
  testWidgets('exact source rows expose an accessible navigation action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final e = exercise(load: '12.500000');
      final opened = <String>[];
      await mountProjection(
        tester,
        [
          workout('source', [e]),
        ],
        e,
        onOpen: opened.add,
      );
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      final target = row('source', e);
      await reveal(tester, target);
      final node = tester.getSemantics(target);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.getSemanticsData().label, contains('12.500000 kg'));
      expect(
        node.getSemanticsData().label,
        contains('exercise instance 1, set 1'),
      );
      expect(node.getSemanticsData().label, contains('Open source workout'));
      final title = find.descendant(
        of: target,
        matching: find.text('12.500000 kg'),
      );
      await tester.tap(title);
      expect(opened, ['source']);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'file-backed corrections replace load, unit, reps and eligibility without restarting',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final saved = await h.saveRoutine();
      final (id, e) = await recorded(
        h,
        routine: saved.id,
        template: saved.templateId,
      );
      await h.mount(
        ExerciseHistoryScreen(identity: exerciseKey(e), onOpenWorkout: (_) {}),
      );
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      final frozen = copyJson((await h.repo.workout(id))!);
      final controller = h.container!.read(workoutsProvider.notifier);
      final provider = measuredProgressProvider(exerciseKey(e));
      expect(
        (await h.container!.read(provider.future))
            .loads['kg']!
            .single
            .load!
            .original,
        '25',
      );
      await controller.record(id, e, e['sets'][0] as Json, {
        ...entry(load: '27.500000', reps: '9'),
        'unit': 'lb',
      }, reason: 'Correct original measurement and unit');
      await tester.pumpAndSettle();
      var model = await h.container!.read(provider.future);
      expect(model.loads.keys, ['lb']);
      expect(model.repetitions.single.repetitions, 9);
      expect(
        model.repetitions.single.startedAt.toIso8601String(),
        DateTime.parse(frozen['started_at'] as String).toIso8601String(),
      );
      await h.reveal(row(id, e));
      expect(find.text('27.500000 lb'), findsOneWidget);
      expect(find.textContaining('25 kg'), findsNothing);
      await chooseMetric(tester, 'Performed repetitions');
      await h.reveal(row(id, e));
      expect(find.text('9 reps'), findsOneWidget);
      expect(find.textContaining('27.500000 lb'), findsWidgets);
      final source = copyJson((await h.repo.workout(id))!);
      await h.reopen();
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      await h.reveal(find.byKey(ValueKey(exerciseKey(e))));
      await tester.tap(find.byKey(ValueKey(exerciseKey(e))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      model = await h.container!.read(provider.future);
      expect(model.loads['lb']!.single.load!.original, '27.500000');
      expect(model.repetitions.single.source, (
        id,
        e['session_exercise_id'],
        e['sets'][0]['set_id'],
      ));
      expect((await h.repo.workout(id))!, source);
      await h.container!
          .read(workoutsProvider.notifier)
          .record(
            id,
            e,
            e['sets'][0] as Json,
            entry(status: 'skipped'),
            reason: 'This historical set was not performed',
          );
      await tester.pumpAndSettle();
      expect(find.byType(MeasuredScatter), findsNothing);
      expect(find.textContaining('No eligible recorded load'), findsOneWidget);
      expect((await h.container!.read(provider.future)).repetitions, isEmpty);
      final corrected = (await h.repo.workout(id))!;
      expect(
        corrected['exercises'][0]['sets'][0]['planned'],
        frozen['exercises'][0]['sets'][0]['planned'],
      );
      await tester.tap(find.text('Source history'));
      await tester.pumpAndSettle();
      await h.reveal(
        find.byKey(ValueKey('observation-$id-${e['sets'][0]['set_id']}')),
      );
      expect(find.textContaining('skipped'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Progress search, plotted source link and actual correction UI refresh the chart',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final saved = await h.saveRoutine();
      final (older, e) = await recorded(
        h,
        routine: saved.id,
        template: saved.templateId,
        reps: '5',
      );
      final (id, current) = await recorded(
        h,
        routine: saved.id,
        template: saved.templateId,
        reps: '8',
      );
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-search')),
        'Single-arm',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await h.reveal(find.byKey(ValueKey(exerciseKey(e))));
      await tester.tap(find.byKey(ValueKey(exerciseKey(e))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      await chooseMetric(tester, 'Performed repetitions');
      final target = row(id, current);
      await h.reveal(target);
      await tester.tap(
        find.descendant(of: target, matching: find.text('8 reps')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutScreen), findsOneWidget);
      expect(find.textContaining('2 attempted'), findsNothing);
      await h.correct(
        current['sets'][0]['set_id'] as String,
        reps: '11',
        reason: 'Read the original logged set',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await h.reveal(target);
      expect(find.text('11 reps'), findsOneWidget);
      expect(find.text('8 reps'), findsNothing);
      final model = await h.container!.read(
        measuredProgressProvider(exerciseKey(e)).future,
      );
      expect(model.repetitions.map((p) => p.workoutId).toSet(), {older, id});
      expect(model.repetitions.map((p) => p.repetitions), containsAll([5, 11]));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed original units select separate plots and assistance is labelled honestly',
    (tester) async {
      final a = exercise(load: '0.000000', basis: 'assistance');
      final b = exercise(load: '17.250000', unit: 'lb', basis: 'assistance');
      b['session_exercise_id'] = 'other-instance';
      b['sets'][0]['set_id'] = 'other-set';
      final opened = <String>[];
      await mountProjection(
        tester,
        [
          workout('kg-source', [a]),
          workout('lb-source', [b]),
        ],
        a,
        onOpen: opened.add,
      );
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not external weight'), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(MeasuredProgressView)),
      );
      var model = await c.read(measuredProgressProvider(exerciseKey(a)).future);
      expect(model.loads.keys, ['kg', 'lb']);
      await reveal(tester, row('kg-source', a));
      expect(find.text('0.000000 kg'), findsOneWidget);
      expect(row('lb-source', b), findsNothing);
      final unit = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Chart load unit',
      );
      await reveal(tester, unit);
      await tester.tap(unit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();
      await reveal(tester, row('lb-source', b));
      expect(find.text('17.250000 lb'), findsOneWidget);
      expect(row('kg-source', a), findsNothing);
      await tester.tap(find.text('17.250000 lb'));
      expect(opened, ['lb-source']);
      model = await c.read(measuredProgressProvider(exerciseKey(a)).future);
      expect(model.loads['lb']!.single.load!.coordinate, 17.25);
    },
  );

  testWidgets(
    'bodyweight measurements offer repetitions and no fabricated external-load plot',
    (tester) async {
      final e = exercise(basis: 'bodyweight_only', load: null);
      await mountProjection(tester, [
        workout('body', [e]),
      ], e);
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<MeasuredMetric>));
      await tester.pumpAndSettle();
      expect(find.text('Recorded load'), findsNothing);
      expect(find.text('Positive assistance'), findsNothing);
      await tester.tap(find.text('Performed repetitions').last);
      await tester.pumpAndSettle();
      expect(find.text('Chart load unit'), findsNothing);
      await reveal(tester, row('body', e));
      expect(find.text('5 reps'), findsOneWidget);
      expect(
        find.textContaining('Bodyweight only; no external load'),
        findsOneWidget,
      );
      expect(find.textContaining('0 kg'), findsNothing);
    },
  );

  testWidgets(
    'large repeated timestamps bound both painter and lazy rows while older points remain reachable',
    (tester) async {
      final e = exercise(load: '0');
      final c = await mountProjection(tester, [
        for (var i = 0; i < 2600; i++) workout('source-$i', [copyJson(e)]),
      ], e);
      await tester.tap(find.text('Measured charts'));
      final model = await waitForMeasuredChart(tester, c, exerciseKey(e));
      expect(model.repetitions, hasLength(2600));
      expect(model.repetitions.map((p) => p.source).toSet(), hasLength(2600));
      expect(model.repetitions.map((p) => p.startedAt).toSet(), hasLength(1));
      expect(model.loads['kg']!.every((p) => p.load!.original == '0'), isTrue);
      expect(
        c
            .read(exerciseHistoryProvider)
            .requireValue
            .byExercise[exerciseKey(e)]!
            .visits,
        hasLength(2600),
      );
      await reveal(tester, find.byType(MeasuredScatter));
      final plot =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('measured-scatter')),
                  )
                  .painter!
              as MeasuredScatterPainter;
      expect(plot.points, hasLength(80));
      expect(plot.points.every((p) => p.x == 0.5 && p.y == 0.5), isTrue);
      expect(find.byType(ListTile).evaluate().length, lessThan(12));
      expect(find.text('Observations 2521–2600 of 2600'), findsOneWidget);
      final source = model.window(MeasuredMetric.load, unit: 'kg').points.first;
      final exact = row(source.workoutId, e);
      await reveal(tester, exact);
      expect(
        find.descendant(of: exact, matching: find.text('0 kg')),
        findsOneWidget,
      );
      await tester.tap(find.text('Older observations'));
      await tester.pumpAndSettle();
      expect(find.text('Observations 2441–2520 of 2600'), findsOneWidget);
      expect(find.byType(ListTile).evaluate().length, lessThan(12));
      final olderSource = model
          .window(MeasuredMetric.load, unit: 'kg', page: 1)
          .points
          .first;
      final olderExact = row(olderSource.workoutId, e);
      await reveal(tester, olderExact);
      expect(
        find.descendant(of: olderExact, matching: find.text('0 kg')),
        findsOneWidget,
      );
      expect(exact, findsNothing);
      await tester.tap(find.text('Newer observations'));
      await tester.pumpAndSettle();
      expect(find.text('Observations 2521–2600 of 2600'), findsOneWidget);
      await reveal(tester, exact);
      expect(exact, findsOneWidget);
      expect(olderExact, findsNothing);
    },
  );
}
