import 'dart:async';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/home_screen.dart';
import 'package:daily_motion/features/measured_progress_provider.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'multi_exercise_test.dart' show multiPlan, entry;
import 'support/auth_fakes.dart' show ownerB;
import 'support/sync_server.dart' show testOwner;
import 'train_activation_test.dart' show AccountHarness;

Future<
  ({
    AccountHarness h,
    ProviderContainer c,
    String id,
    Json exercise,
    RoutinePlan plan,
  })
>
ownerChart(WidgetTester tester) async {
  final h = AccountHarness(tester);
  await h.open();
  addTearDown(h.close);
  await h.signIn();
  final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  final plan = multiPlan(h.repo, name: 'Owner A private chart');
  final (id, e) = await recordRoutine(h, c, plan, '33.250000');
  await navigateChart(tester, exerciseKey(e));
  await h.reveal(find.text('33.250000 kg'));
  return (h: h, c: c, id: id, exercise: e, plan: plan);
}

Future<(String, Json)> recordRoutine(
  AccountHarness h,
  ProviderContainer c,
  RoutinePlan plan,
  String load,
) async {
  final saved = await h.repo.saveRoutine(
    id: h.repo.newId(),
    expectedRevision: 0,
    plan: plan,
  );
  final id = await h.repo.startRoutine(
    routineId: saved.id,
    templateId: saved.templateId,
    attemptId: h.repo.newId(),
    timezone: 'UTC',
  );
  await c.read(workoutsProvider.notifier).refresh();
  final w = (await h.repo.workout(id))!;
  final e = w['exercises'][0] as Json;
  await c
      .read(workoutsProvider.notifier)
      .record(id, e, e['sets'][0] as Json, entry(load: load, reps: '7'));
  await c.read(workoutsProvider.notifier).finish(id);
  await h.tester.pumpAndSettle();
  return (id, e);
}

Future<void> navigateChart(WidgetTester tester, ExerciseKey identity) async {
  await tester.tap(find.text('Progress').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(ValueKey(identity)));
  await tester.tap(find.byKey(ValueKey(identity)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Measured charts'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a refresh sampled before a correction cannot restore superseded chart values',
    (tester) async {
      final f = await ownerChart(tester);
      final controller = f.c.read(workoutsProvider.notifier);
      f.h.repo.holdReads = true;
      final obsolete = controller.refresh();
      addTearDown(() {
        if (!f.h.repo.release.isCompleted) {
          f.h.repo.release.complete();
        }
      });
      await f.h.drain(f.h.repo.entered.future);
      f.h.repo.holdReads = false;
      await controller.record(
        f.id,
        f.exercise,
        f.exercise['sets'][0] as Json,
        entry(load: '44.750000'),
        reason: 'Correct original notebook measurement',
      );
      await tester.pumpAndSettle();
      await f.h.reveal(find.text('44.750000 kg'));
      f.h.repo.release.complete();
      await f.h.drain(obsolete);
      await tester.pumpAndSettle();
      final actual = (await f.h.repo.workout(f.id))!;
      expect(
        actual['exercises'][0]['sets'][0]['observation']['actual']['load']['value'],
        '44.750000',
      );
      final model = await f.c.read(
        measuredProgressProvider(exerciseKey(f.exercise)).future,
      );
      expect(model.loads['kg']!.single.load!.original, '44.750000');
      await f.h.reveal(find.text('44.750000 kg'));
      expect(find.text('33.250000 kg'), findsNothing);
    },
  );

  testWidgets(
    'a refresh sampled before owner locking cannot replace the newer access error',
    (tester) async {
      final f = await ownerChart(tester);
      final semantics = tester.ensureSemantics();
      try {
        final controller = f.c.read(workoutsProvider.notifier);
        f.h.repo.holdReads = true;
        final obsolete = controller.refresh();
        addTearDown(() {
          if (!f.h.repo.release.isCompleted) {
            f.h.repo.release.complete();
          }
        });
        await f.h.drain(f.h.repo.entered.future);
        f.h.repo.holdReads = false;
        await f.h.repo.signOut();
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Measured history could not be loaded'),
          findsOneWidget,
        );
        f.h.repo.release.complete();
        await f.h.drain(obsolete);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Measured history could not be loaded'),
          findsOneWidget,
        );
        expect(find.textContaining('Owner A private chart'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Owner A private chart')),
          findsNothing,
        );
        expect(find.text('33.250000 kg'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'local read failure hides chart details and retry recovers acknowledged data',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final f = await ownerChart(tester);
        final original = await f.h.repo.workouts();
        f.h.repo.holdReads = true;
        f.c.invalidate(workoutsProvider);
        await f.h.drain(f.h.repo.entered.future);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Loading measured observations'),
          findsOneWidget,
        );
        expect(find.textContaining('Owner A private chart'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Owner A private chart')),
          findsNothing,
        );
        f.h.repo.holdReads = false;
        f.h.repo.release.complete();
        await f.h.drain(f.c.read(workoutsProvider.future).then((_) {}));
        await tester.pumpAndSettle();
        await f.h.reveal(find.text('33.250000 kg'));
        f.h.repo.failReads = true;
        await f.c.read(workoutsProvider.notifier).refresh();
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Measured history could not be loaded'),
          findsOneWidget,
        );
        expect(find.text('33.250000 kg'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Owner A private chart')),
          findsNothing,
        );
        expect(find.textContaining('PRIVATE READ DETAIL'), findsNothing);
        f.h.repo.failReads = false;
        await tester.tap(find.text('Retry measured history'));
        await tester.pumpAndSettle();
        await f.h.reveal(find.text('33.250000 kg'));
        expect(await f.h.repo.workouts(), original);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'authoritative disable removes private chart data and completes account shutdown',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final f = await ownerChart(tester);
        expect(find.textContaining('Owner A private chart'), findsWidgets);
        final done = Completer<void>();
        void changed() {
          if (f.h.account.state.phase == AccountPhase.disabled &&
              !done.isCompleted) {
            done.complete();
          }
        }

        f.h.account.addListener(changed);
        final coordinator = f.h.account.coordinator!;
        f.h.servers[testOwner]!.disabled = true;
        f.h.account.foreground(true);
        await f.h.drain(coordinator.synchronize(force: true));
        await tester.pumpAndSettle();
        expect(find.textContaining('Owner A private chart'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Owner A private chart')),
          findsNothing,
        );
        expect(find.text('33.250000 kg'), findsNothing);
        await f.h.drain(done.future);
        f.h.account.removeListener(changed);
        expect(f.h.account.local, isNull);
        expect(f.h.account.state.phase, AccountPhase.disabled);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'sign-out and same-variant owner switch never expose prior chart values or routes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final f = await ownerChart(tester);
        final a = await f.h.repo.workouts();
        await f.h.drain(f.h.account.signOut());
        await tester.pumpAndSettle();
        expect(find.textContaining('Owner A private chart'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Owner A private chart')),
          findsNothing,
        );
        await f.h.signIn(owner: ownerB);
        final b = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(await f.h.repo.workouts(), isEmpty);
        final payload = f.plan.json..['name'] = 'Owner B chart';
        final (id, e) = await recordRoutine(
          f.h,
          b,
          RoutinePlan.fromJson(payload),
          '41.750000',
        );
        await navigateChart(tester, exerciseKey(e));
        await f.h.reveal(find.text('41.750000 kg'));
        expect(find.textContaining('Owner A private chart'), findsNothing);
        expect(find.text('33.250000 kg'), findsNothing);
        final model = await b.read(
          measuredProgressProvider(exerciseKey(e)).future,
        );
        expect(model.repetitions.single.workoutId, id);
        expect(model.repetitions.single.workoutId, isNot(f.id));
        await f.h.drain(f.h.account.signOut());
        await tester.pumpAndSettle();
        await f.h.signIn();
        expect(await f.h.repo.workouts(), a);
        await navigateChart(tester, exerciseKey(f.exercise));
        await f.h.reveal(find.text('33.250000 kg'));
        expect(find.text('41.750000 kg'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'expired cloud credentials and file reopening preserve cached measured history offline',
    (tester) async {
      final f = await ownerChart(tester);
      final before = await f.c.read(
        measuredProgressProvider(exerciseKey(f.exercise)).future,
      );
      f.h.now = f.h.now.add(const Duration(hours: 2));
      f.h.provider.refreshFailure = const AuthFailure(
        'network_unavailable',
        retryable: true,
      );
      await tester.runAsync(() => f.h.account.refresh(force: true));
      await tester.pumpAndSettle();
      expect(f.h.account.state.phase, AccountPhase.offline);
      expect(find.text('33.250000 kg'), findsOneWidget);
      await f.h.reopen();
      await navigateChart(tester, exerciseKey(f.exercise));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen, skipOffstage: false)),
      );
      final after = await c.read(
        measuredProgressProvider(exerciseKey(f.exercise)).future,
      );
      expect(after.repetitions.single.source, before.repetitions.single.source);
      expect(after.repetitions.single.load!.original, '33.250000');
      expect(
        after.repetitions.single.startedAt,
        before.repetitions.single.startedAt,
      );
      expect(f.h.servers[testOwner]!.pushed, isEmpty);
    },
  );
}
