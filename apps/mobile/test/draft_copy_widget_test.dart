import 'dart:async';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_copy_test.dart' show recorded;
import 'repository_test.dart' show owner;

class HeldDraftRepository extends WorkoutRepository {
  HeldDraftRepository(super.db, super.ownerId);
  Completer<void>? gate;
  @override
  Future<void> saveDraft(String setId, Json values) async {
    await gate?.future;
    await super.saveDraft(setId, values);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('copy confirmation is draft only at 320px/200%, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = TrainingDatabase(NativeDatabase.memory());
      final repo = WorkoutRepository(db, owner);
      await repo.initialize();
      final id = await recorded(repo);
      final state = (await repo.workout(id))!;
      final exercise = state['exercises'][0] as Json;
      final item = exercise['sets'][1] as Json;
      var recordedCount = 0;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SetEditor(
                    sessionId: id,
                    exercise: exercise,
                    item: item,
                    onSaved: () => recordedCount++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (dark) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        } else {
          await tester.tap(find.text('Use previous working set'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Copy values into this draft?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await repo.draft(item['set_id'] as String), isNull);
        await tester.tap(find.text('Use previous working set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy to draft'));
        await tester.pumpAndSettle();
        expect((await repo.draft(item['set_id'] as String))!['effort'], '');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '60.000001',
        );
        expect(recordedCount, 0);
        expect(
          allSets((await repo.workout(id))!)
              .where((s) => s['observation'] != null),
          hasLength(1),
        );
        final save = find.text('Record set');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(recordedCount, 1);
        final actual = allSets((await repo.workout(id))!)
            .elementAt(1)['observation']['actual'];
        expect(actual['load']['value'], '60.000001');
        expect(actual['load']['unit'], 'kg');
        expect(actual['effort'], isNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    });
  }
  testWidgets(
    'held older autosave must finish before preview, repeated taps cannot complete a set',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final repo = HeldDraftRepository(db, owner);
      await repo.initialize();
      final id = await recorded(repo);
      final state = (await repo.workout(id))!;
      final exercise = state['exercises'][0] as Json;
      final item = exercise['sets'][1] as Json;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SetEditor(
                    sessionId: id,
                    exercise: exercise,
                    item: item,
                    onSaved: () => fail('Copy must not record'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        repo.gate = Completer<void>();
        await tester.enterText(find.byType(TextField).first, '88');
        await tester.pump();
        await tester.tap(find.text('Use previous working set'));
        await tester.pump();
        await tester.tap(find.text('Preparing draft…'));
        await tester.pump();
        expect(find.text('Copy to draft'), findsNothing);
        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Copy to draft'), findsOneWidget);
        await tester.tap(find.text('Copy to draft'));
        await tester.pumpAndSettle();
        expect(
          (await repo.draft(item['set_id'] as String))!['load'],
          '60.000001',
        );
        expect(
          allSets((await repo.workout(id))!)
              .where((s) => s['observation'] != null),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        repo.gate?.completeIfNeeded();
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
  testWidgets('late A autosave after owner replacement cannot copy into B', (
    tester,
  ) async {
    final a = TrainingDatabase(NativeDatabase.memory());
    final b = TrainingDatabase(NativeDatabase.memory());
    final repo = HeldDraftRepository(a, owner);
    await repo.initialize();
    final other = WorkoutRepository(b, '20000000-0000-4000-8000-000000000099');
    await other.initialize();
    final id = await recorded(repo);
    final state = (await repo.workout(id))!;
    final exercise = state['exercises'][0] as Json;
    final item = exercise['sets'][1] as Json;
    try {
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('A'),
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SetEditor(
                  sessionId: id,
                  exercise: exercise,
                  item: item,
                  onSaved: () => fail('Must not record'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.gate = Completer<void>();
      await tester.enterText(find.byType(TextField).first, '88');
      await tester.tap(find.text('Use previous working set'));
      await tester.pump();
      await repo.signOut();
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('B'),
          overrides: [repositoryProvider.overrideWithValue(other)],
          child: const MaterialApp(home: Scaffold(body: Text('B training'))),
        ),
      );
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('B training'), findsOneWidget);
      expect(find.text('Copy to draft'), findsNothing);
      expect(await other.workouts(), isEmpty);
      expect(await b.customSelect('SELECT * FROM drafts').get(), isEmpty);
      expect(await a.customSelect('SELECT * FROM drafts').get(), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      repo.gate?.completeIfNeeded();
      await tester.pumpWidget(const SizedBox());
      await a.close();
      await b.close();
    }
  });
  testWidgets(
    'copy storage failure retains editable values and sanitized retry succeeds',
    (tester) async {
      final db = TrainingDatabase(NativeDatabase.memory());
      final repo = WorkoutRepository(db, owner);
      await repo.initialize();
      final id = await recorded(repo);
      final state = (await repo.workout(id))!;
      final exercise = state['exercises'][0] as Json;
      final item = exercise['sets'][1] as Json;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SetEditor(
                    sessionId: id,
                    exercise: exercise,
                    item: item,
                    onSaved: () => fail('Must not record'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '88');
        await tester.pumpAndSettle();
        await db.customStatement(
          "CREATE TRIGGER fail_copy_ui BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT, 'private SQL detail'); END",
        );
        await tester.tap(find.text('Use previous working set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy to draft'));
        await tester.pumpAndSettle();
        expect(
          find.text('Copy failed. Your entry is retained; retry.'),
          findsOneWidget,
        );
        expect(find.textContaining('private SQL detail'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '88',
        );
        expect((await repo.draft(item['set_id'] as String))!['load'], '88');
        await db.customStatement('DROP TRIGGER fail_copy_ui');
        await tester.tap(find.text('Use previous working set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy to draft'));
        await tester.pumpAndSettle();
        expect(
          (await repo.draft(item['set_id'] as String))!['load'],
          '60.000001',
        );
        expect(
          allSets((await repo.workout(id))!)
              .where((s) => s['observation'] != null),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      }
    },
  );
}

extension on Completer<void> {
  void completeIfNeeded() {
    if (!isCompleted) complete();
  }
}
