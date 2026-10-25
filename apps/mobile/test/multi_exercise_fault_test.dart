import 'dart:async';

import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'multi_exercise_test.dart' show Harness, ownerA, entry, multiPlan;

class UnavailableReads extends WorkoutRepository {
  UnavailableReads(super.db, super.ownerId);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<List<Json>> workouts() async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic private storage details');
    return super.workouts();
  }
}

void main() {
  testWidgets(
    'empty and skipped-only completion remain rejected while a failed attempt permits finishing',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('Resume workout'));
      await tester.pumpAndSettle();
      Future<void> finish() async {
        await h.reveal(find.text('Finish workout'));
        await tester.tap(find.text('Finish workout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
      }

      await finish();
      expect(
        find.text('Record an attempted set before finishing.'),
        findsOneWidget,
      );
      expect((await h.repo.workout(id))!['status'], 'active');
      final w = (await h.repo.workout(id))!;
      await h.record(
        w['exercises'][1]['sets'][0]['set_id'] as String,
        status: 'Skipped',
        load: '',
      );
      await finish();
      expect((await h.repo.workout(id))!['status'], 'active');
      await h.record(
        w['exercises'][2]['sets'][0]['set_id'] as String,
        status: 'Failed attempt',
        load: '5',
        reps: '0',
      );
      await finish();
      expect((await h.repo.workout(id))!['status'], 'completed');
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1 attempted sets · 1 skipped · 4 unperformed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a failed later-exercise correction retains its reason and original observation until retry',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      await h.mount(WorkoutScreen(sessionId: id));
      final w = (await h.repo.workout(id))!;
      final setId = w['exercises'][2]['sets'][0]['set_id'] as String;
      await h.record(setId, load: '5', reps: '7');
      final before = (await h.repo.workout(id))!;
      final pending = await h.repo.pendingCount();
      await h.db.customStatement(
        "CREATE TRIGGER reject_correction BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic correction fault'); END",
      );
      await h.correct(setId, reps: '8', reason: 'Corrected third exercise');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('Local save failed. Your entry is still here; retry.'),
        findsOneWidget,
      );
      expect(find.text('Corrected third exercise'), findsOneWidget);
      expect(await h.repo.workout(id), before);
      expect(await h.repo.pendingCount(), pending);
      await h.db.customStatement('DROP TRIGGER reject_correction');
      final save = find.text('Save correction');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final corrected =
          (await h.repo.workout(id))!['exercises'][2]['sets'][0]['observation']
              as Json;
      expect(corrected['actual']['reps'], 8);
      expect(corrected['completion_seq'], 1);
      expect(corrected['correction_reason'], 'Corrected third exercise');
      expect(await h.repo.pendingCount(), pending + 1);
    },
  );

  testWidgets(
    'performance keeps incompatible and repeated variants separate and excludes unperformed outcomes',
    (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final source = multiPlan(h.repo).json;
      final exercises = <Json>[];
      const bases = [
        'total_external',
        'per_implement',
        'machine_stack',
        'added_bodyweight',
        'assistance',
        'bodyweight_only',
        'total_external',
      ];
      const values = ['0', '20', '15', '5', '7', '', '0'];
      for (var i = 0; i < bases.length; i++) {
        final e = copyJson(source['exercises'][0] as Json);
        e['session_exercise_id'] = h.repo.newId();
        e['variant_id'] = i == 6 ? exercises[0]['variant_id'] : h.repo.newId();
        e['name'] = 'Shared exercise name';
        e['loading_basis'] = bases[i];
        e['rep_convention'] = i == 1
            ? 'per_side'
            : i == 2
            ? 'alternating_total'
            : 'bilateral';
        e['side'] = i == 1 ? 'right' : 'both';
        for (final (j, item) in (e['sets'] as List).cast<Json>().indexed) {
          item['set_id'] = h.repo.newId();
          item['set_class'] = i == 5 && j == 0 ? 'warmup' : 'working';
          item['planned']['load'] = i == 5
              ? null
              : {
                  'value': values[i],
                  'unit': i == 2 ? 'lb' : 'kg',
                  'basis': bases[i],
                };
        }
        exercises.add(e);
      }
      source['exercises'] = exercises;
      final routine = await h.repo.saveRoutine(
        id: h.repo.newId(),
        expectedRevision: 0,
        plan: RoutinePlan.fromJson(source),
      );
      final id = await h.start(routine);
      await h.mount(const HomeScreen(syntheticFixture: false));
      final c = h.container!.read(workoutsProvider.notifier);
      final snapshot = (await h.repo.workout(id))!;
      for (final (i, e)
          in (snapshot['exercises'] as List).cast<Json>().indexed) {
        await c.record(id, e, e['sets'][0] as Json, {
          ...entry(load: values[i]),
          'unit': i == 2 ? 'lb' : 'kg',
        });
        if (i == 5) {
          await c.record(id, e, e['sets'][1] as Json, entry(load: ''));
        }
        if (i < 3) {
          await c.record(
            id,
            e,
            e['sets'][1] as Json,
            entry(
              load: values[i],
              status: ['failed', 'partial', 'skipped'][i],
              reps: i == 0 ? '0' : '2',
            ),
          );
        }
      }
      await c.finish(id);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards.length, 7);
      expect(
        find.textContaining(RegExp(r'\n0 kg \u00b7 6 reps$')),
        findsNWidgets(2),
      );
      expect(find.textContaining('15 lb'), findsOneWidget);
      expect(
        find.textContaining('per implement \u00b7 reps per side \u00b7 right'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'machine stack \u00b7 alternating total reps \u00b7 both',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('positive assistance'), findsOneWidget);
      expect(find.textContaining('added bodyweight'), findsOneWidget);
      expect(find.textContaining('bodyweight only'), findsOneWidget);
      final bodyweightId = snapshot['exercises'][5]['sets'][1]['set_id'];
      final bodyweightCard = find.byKey(
        ValueKey('performance-$id-$bodyweightId'),
      );
      expect(
        find.descendant(
          of: bodyweightCard,
          matching: find.textContaining('kg'),
        ),
        findsNothing,
      );
      final after = (await h.repo.workout(id))!;
      for (final e in (after['exercises'] as List).cast<Json>()) {
        for (final set in (e['sets'] as List).cast<Json>()) {
          final expected =
              set['set_class'] == 'working' &&
              set['observation']?['execution_status'] == 'completed';
          expect(
            find.byKey(ValueKey('performance-$id-${set['set_id']}')),
            expected ? findsOneWidget : findsNothing,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed third-exercise writes roll back and rapid retry records exactly once',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      await h.mount(WorkoutScreen(sessionId: id));
      final before = (await h.repo.workout(id))!;
      final setId = before['exercises'][2]['sets'][0]['set_id'] as String;
      final pending = await h.repo.pendingCount();
      await h.db.customStatement(
        "CREATE TRIGGER reject_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic write fault'); END",
      );
      await h.record(setId, reps: '11', load: '4', twice: true);
      expect(
        find.text('Local save failed. Your entry is still here; retry.'),
        findsOneWidget,
      );
      expect(find.textContaining('synthetic write fault'), findsNothing);
      expect(await h.repo.workout(id), before);
      expect(await h.repo.pendingCount(), pending);
      expect(await h.repo.timerDeadline(id), isNull);
      expect((await h.repo.draft(setId))!['reps'], '11');
      await h.db.customStatement('DROP TRIGGER reject_outbox');
      await h.record(setId, reps: '11', load: '4', twice: true);
      final after = (await h.repo.workout(id))!;
      expect(
        after['exercises'][2]['sets'][0]['observation']['actual']['reps'],
        11,
      );
      expect(allSets(after).where((s) => s['observation'] != null).length, 1);
      expect(await h.repo.pendingCount(), pending + 1);
      expect(await h.repo.draft(setId), isNull);
      expect(await h.repo.timerDeadline(id), isNotNull);
      final e = after['exercises'][1] as Json;
      expect(
        await h.container!
            .read(workoutsProvider.notifier)
            .record(id, e, e['sets'][0] as Json, entry(load: '', reps: '8')),
        true,
      );
      expect(completionSequence((await h.repo.workout(id))!), 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('later-exercise drafts reopen without becoming performed work', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.open();
    addTearDown(h.close);
    final id = await h.start(await h.saveRoutine());
    await h.mount(WorkoutScreen(sessionId: id));
    final original = (await h.repo.workout(id))!;
    final ids = [
      for (final i in [1, 2])
        original['exercises'][i]['sets'][0]['set_id'] as String,
    ];
    for (final (i, id) in ids.indexed) {
      final editor = find.byWidgetPredicate(
        (w) => w is SetEditor && w.item['set_id'] == id,
      );
      await h.reveal(editor);
      final reps = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextField, 'Actual reps'),
      );
      await tester.ensureVisible(reps);
      await tester.enterText(reps, '${14 + i}');
      await tester.pumpAndSettle();
      expect((await h.repo.draft(id))!['reps'], '${14 + i}');
    }
    await h.reopen();
    await tester.tap(find.text('Resume workout'));
    await tester.pumpAndSettle();
    for (final (i, id) in ids.indexed) {
      final editor = find.byWidgetPredicate(
        (w) => w is SetEditor && w.item['set_id'] == id,
      );
      await h.reveal(editor);
      final reps = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextField, 'Actual reps'),
      );
      expect(tester.widget<TextField>(reps).controller!.text, '${14 + i}');
    }
    expect(await h.repo.workout(id), original);
    expect(await h.repo.pendingCount(), 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your recorded workouts will appear here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Complete a workout with a completed working set'),
      findsOneWidget,
    );
  });

  testWidgets(
    'history sorts by workout date and separates abandoned work from plans',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      h.repo.dispose();
      var now = DateTime.utc(2026, 10, 20);
      h.repo = WorkoutRepository(h.db, ownerA, clock: () => now);
      final saved = await h.saveRoutine();
      final ids = <String>[];
      for (final day in [22, 20, 21]) {
        now = DateTime.utc(2026, 10, day);
        final id = await h.start(saved);
        ids.add(id);
        final c = await h.repo.workout(id);
        // Use the same real controller payload path as the UI.
        await h.mount(const HomeScreen(syntheticFixture: false));
        final e = c!['exercises'][0] as Json;
        await h.container!
            .read(workoutsProvider.notifier)
            .record(id, e, e['sets'][0] as Json, entry());
        await h.container!
            .read(workoutsProvider.notifier)
            .finish(id, abandon: day == 21);
        await tester.pumpWidget(const SizedBox.shrink());
        h.container!.dispose();
        h.container = null;
      }
      await h.mount(const HomeScreen(syntheticFixture: false));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards.map((c) => c.key), [
        ValueKey('history-${ids[0]}'),
        ValueKey('history-${ids[2]}'),
        ValueKey('history-${ids[1]}'),
      ]);
      expect(find.textContaining('abandoned'), findsOneWidget);
      expect(
        find.textContaining(
          '1 attempted sets \u00b7 0 skipped \u00b7 5 unperformed',
        ),
        findsNWidgets(3),
      );
      await tester.tap(find.byKey(ValueKey('history-${ids[2]}')));
      await tester.pumpAndSettle();
      await h.reveal(find.text('Assisted pull-up'));
      expect(
        find.textContaining('Planned 5 kg \u00b7 7 reps \u00b7 unperformed'),
        findsNWidgets(2),
      );
      expect(find.text('Record next set'), findsNothing);
    },
  );

  testWidgets(
    'loading and storage errors hide observations and offer a safe retry',
    (tester) async {
      final h = Harness(tester);
      await h.open();
      addTearDown(h.close);
      final id = await h.start(await h.saveRoutine());
      h.repo.dispose();
      final unavailable = UnavailableReads(h.db, ownerA);
      h.repo = unavailable;
      await h.mount(WorkoutScreen(sessionId: id));
      unavailable.fail = true;
      await h.container!.read(workoutsProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('Workout could not be loaded.'), findsOneWidget);
      expect(find.text('Single-arm row'), findsNothing);
      expect(
        find.textContaining('synthetic private storage details'),
        findsNothing,
      );
      unavailable.fail = false;
      unavailable.gate = Completer<void>();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Single-arm row'), findsNothing);
      unavailable.gate!.complete();
      await tester.pumpAndSettle();
      unavailable.gate = null;
      expect(find.text('Single-arm row'), findsOneWidget);
      await h.repo.signOut();
      await h.container!.read(workoutsProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('Workout could not be loaded.'), findsOneWidget);
      expect(find.text('Single-arm row'), findsNothing);
      await h.repo.unlockVerifiedOwner(ownerA);
      expect(
        allSets((await h.repo.workout(id))!)
            .every((s) => s['observation'] == null),
        true,
      );
    },
  );

  testWidgets(
    'third-exercise entry and correction fit narrow large-text keyboard layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        final h = Harness(tester);
        await h.open();
        addTearDown(h.close);
        final id = await h.start(await h.saveRoutine());
        await h.mount(WorkoutScreen(sessionId: id));
        final original = (await h.repo.workout(id))!;
        final setId = original['exercises'][2]['sets'][0]['set_id'] as String;
        await h.record(setId, status: 'Failed attempt', load: '5', reps: '0');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await h.correct(
          setId,
          status: 'Partial',
          reps: '2',
          reason: 'Corrected failed attempt',
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(
          (await h.repo.workout(
            id,
          ))!['exercises'][2]['sets'][0]['observation']['execution_status'],
          'partial',
        );
        expect(
          allSets((await h.repo.workout(id))!)
              .where((s) => s['observation'] != null)
              .length,
          1,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
}
