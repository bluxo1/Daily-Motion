import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default build cannot start an unverified personal workout', (
    tester,
  ) async {
    await tester.pumpWidget(const DailyMotionApp());
    expect(find.text('Daily Motion'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
  });
  testWidgets('disabled account restart accurately reports remote erasure', (
    tester,
  ) async {
    await tester.pumpWidget(const DailyMotionApp(accountDisabled: true));
    expect(
      find.text(
        'This account was disabled remotely. Local training data has been removed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Saved work is retained'), findsNothing);
    expect(find.text('Start workout'), findsNothing);
  });

  testWidgets('320px large-text logging records only after a deliberate save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = TrainingDatabase(NativeDatabase.memory());
    final repo = WorkoutRepository(db, '20000000-0000-4000-8000-000000000001');
    await repo.initialize();
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(workoutsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DailyMotionApp(fixtureEnabled: true),
      ),
    );
    await tester.pumpAndSettle();
    final start = find.text('Start workout');
    await tester.scrollUntilVisible(start, 300);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    final workout = (await repo.workouts()).single;
    expect(allSets(workout).every((s) => s['observation'] == null), isTrue);
    final save = find.text('Record set');
    await tester.scrollUntilVisible(save, 300);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      allSets((await repo.workouts()).single)
          .where((s) => s['observation'] != null)
          .length,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}
