import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/features/measured_records_view.dart';
import 'package:daily_motion/features/workout_controller.dart';

import 'exercise_history_test.dart' show exercise, workout;
import 'measured_progress_widget_test.dart' show mountProjection;
import 'exercise_history_provider_test.dart' show LargeProjection;

import 'package:drift/native.dart';

void main() {
  testWidgets('measured records are reachable from the real exercise chart', (
    tester,
  ) async {
    final e = exercise(load: '42.500000');
    await mountProjection(tester, [
      workout('record-source', [e]),
    ], e);
    await tester.tap(find.text('Measured charts'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(OutlinedButton, 'View measured records'),
      findsOneWidget,
    );
    await tester.tap(find.text('View measured records'));
    await tester.pumpAndSettle();
    expect(find.text('Measured records'), findsOneWidget);
    expect(find.textContaining('42.500000 kg'), findsWidgets);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'record rows and source actions fit320px/200percent/reduced motion ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final e = exercise(load: '42.500000');
        final db = TrainingDatabase(NativeDatabase.memory());
        final repo = LargeProjection(db, 'fixture-owner', [
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
        String? opened;
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                theme: motionTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: MeasuredRecordsScreen(
                  identity: exerciseKey(e),
                  onOpenWorkout: (id) => opened = id,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final action = find
              .widgetWithText(TextButton, 'Open source workout')
              .first;
          await tester.scrollUntilVisible(
            action,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 30,
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Open source workout'), findsWidgets);
          Focus.of(tester.element(find.text('Open source workout').first))
              .requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(opened, 'source');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'record load groups are bounded and paginate independently from chart windows',
    (tester) async {
      final e = exercise(load: '1');
      await mountProjection(tester, [
        for (var i = 1; i <= 45; i++)
          workout('source-$i', [exercise(load: '$i')]),
      ], e);
      await tester.tap(find.text('Measured charts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View measured records'));
      await tester.pumpAndSettle();
      expect(find.text('Load groups 1–20 of 45'), findsOneWidget);
      final next = find.text('Next record groups');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Load groups 21–40 of 45'), findsOneWidget);
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Load groups 41–45 of 45'), findsOneWidget);
    },
  );

  testWidgets('assistance records never show a highest-load achievement', (
    tester,
  ) async {
    final e = exercise(load: '40', basis: 'assistance');
    await mountProjection(tester, [
      workout('source', [e]),
    ], e);
    await tester.tap(find.text('Measured charts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View measured records'));
    await tester.pumpAndSettle();
    expect(find.text('Highest positive recorded load'), findsNothing);
    expect(find.textContaining('No highest-load achievement'), findsOneWidget);
    expect(
      find.text('Rep records at fixed positive assistance'),
      findsOneWidget,
    );
  });
}
