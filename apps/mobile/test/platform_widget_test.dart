import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sync_server.dart' show testOwner;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform back navigation retains active workout and durable editor draft',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final db = TrainingDatabase(NativeDatabase.memory());
        final repo = WorkoutRepository(db, testOwner);
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        await container.read(workoutsProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DailyMotionApp(fixtureEnabled: true),
          ),
        );
        await tester.tap(find.text('Start workout'));
        await tester.pumpAndSettle();
        final root = (await repo.workouts()).single;
        final setId = allSets(root).first['set_id'] as String;
        final reps = find.widgetWithText(TextField, 'Actual reps');
        await tester.scrollUntilVisible(
          reps,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(reps, '7');
        await tester.pumpAndSettle();
        expect((await repo.draft(setId))!['reps'], '7');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Resume workout'), findsOneWidget);
        expect((await repo.workouts()).single['status'], 'active');
        expect(
          allSets((await repo.workouts()).single)
              .every((s) => s['observation'] == null),
          true,
        );
        expect((await repo.draft(setId))!['reps'], '7');
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
        container.dispose();
        await db.close();
      },
    );
  }
  testWidgets(
    'large text, reduced motion and keyboard inset retain accessible logging controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final semantics = tester.ensureSemantics();
      final db = TrainingDatabase(NativeDatabase.memory());
      final repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      await container.read(workoutsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DailyMotionApp(fixtureEnabled: true),
        ),
      );
      await tester.scrollUntilVisible(find.text('Start workout'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();
      final reps = find.widgetWithText(TextField, 'Actual reps');
      await tester.scrollUntilVisible(
        reps,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(reps);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(reps);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(
              find.descendant(of: reps, matching: find.byType(EditableText)),
            )
            .label,
        contains('Actual reps'),
      );
      await tester.scrollUntilVisible(
        find.text('Record set'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await db.close();
      semantics.dispose();
    },
  );
}
