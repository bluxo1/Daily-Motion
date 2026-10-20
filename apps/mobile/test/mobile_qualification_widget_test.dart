import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show fixture, recordPayload;
import 'support/sync_server.dart' show testOwner;

class FailingTimerRepository extends WorkoutRepository {
  FailingTimerRepository(super.db, super.ownerId);

  @override
  Future<void> cancelTimer(String id) async {
    throw const FileSystemException('synthetic private path');
  }
}

void main() {
  late TrainingDatabase database;
  late WorkoutRepository repository;
  late ProviderContainer container;
  late String id;

  Future<void> open(
    WidgetTester tester, {
    bool failCancel = false,
    String unit = 'kg',
  }) async {
    database = TrainingDatabase(NativeDatabase.memory());
    repository = failCancel
        ? FailingTimerRepository(database, testOwner)
        : WorkoutRepository(database, testOwner);
    await repository.initialize();
    final creation = fixture();
    id = creation['aggregate_id'] as String;
    final prescription = creation['payload'] as Json;
    for (final exercise in prescription['exercises'] as List) {
      for (final item in exercise['sets'] as List) {
        item['planned']['load']['unit'] = unit;
      }
    }
    await repository.commit(id, 'create_session', prescription);
    final payload = recordPayload((await repository.workout(id))!);
    (payload['actual'] as Json)['effort'] = {
      'scale': 'rir',
      'value': '2',
      'source': 'self_reported',
    };
    payload['actual']['load']['unit'] = unit;
    await repository.commit(id, 'record_set', payload);
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    await container.read(workoutsProvider.future);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      repository.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: motionTheme(Brightness.light),
          home: WorkoutScreen(sessionId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'timer cancellation failure retains timer and offers a safe retry',
    (tester) async {
      await open(tester, failCancel: true);
      await tester.scrollUntilVisible(
        find.text('Cancel'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Rest timer could not be cancelled. Retry.'),
        findsOneWidget,
      );
      expect(await repository.timerDeadline(id), isNotNull);
      expect(find.textContaining('synthetic private path'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets('correction keyboard advances to reason before submitting', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Correct set 1'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final effort = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextField, 'Actual effort (optional)'),
    );
    final reason = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextField, 'Correction reason'),
    );
    await tester.ensureVisible(effort);
    await tester.tap(effort);
    await tester.enterText(effort, '3');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.text('Save correction'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: reason, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(reason, 'Corrected effort');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Save correction'), findsNothing);
    expect(
      allSets((await repository.workout(id))!)
          .first['observation']['actual']['effort']['value'],
      '3',
    );
  });

  testWidgets('recorded set exposes effort alongside load, reps and outcome', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester);
      expect(find.textContaining('RIR 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('completed.*60 kg.*5.*RIR 2')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('planned pounds are labelled with their prescribed unit', (
    tester,
  ) async {
    await open(tester, unit: 'lb');
    expect(find.textContaining('Planned 60 lb'), findsNWidgets(2));
    expect(find.textContaining('Planned 60 kg'), findsNothing);
  });

  testWidgets(
    'large-text correction sheet remains usable with keyboard and back',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await open(tester);
        await tester.scrollUntilVisible(
          find.byTooltip('Correct set 1'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Correct set 1'));
        await tester.pumpAndSettle();
        final reason = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(TextField, 'Correction reason'),
        );
        await tester.ensureVisible(reason);
        await tester.pumpAndSettle();
        await tester.tap(reason);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(reason);
        await tester.pumpAndSettle();
        await tester.enterText(reason, 'Unsaved correction');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect((await repository.workout(id))!['status'], 'active');
        expect(await repository.pendingCount(), 2);
      } finally {
        semantics.dispose();
      }
    },
  );
}
