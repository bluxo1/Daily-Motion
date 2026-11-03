import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/features/workout_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_copy_test.dart' show recorded;
import 'repository_test.dart' show owner;

void main() {
  for (final choice in ['Copy to draft', 'Cancel']) {
    testWidgets('repeated $choice never pops the training route', (
      tester,
    ) async {
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
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
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use previous working set'));
        await tester.pumpAndSettle();
        final confirm = tester
            .widget<TextButton>(find.widgetWithText(TextButton, choice))
            .onPressed!;
        confirm();
        confirm();
        await tester.pumpAndSettle();
        expect(find.byType(SetEditor), findsOneWidget);
        if (choice == 'Cancel') {
          expect(await repo.draft(item['set_id'] as String), isNull);
        } else {
          expect(
            find.text(
              'Copied to an editable draft. The set has not been recorded.',
            ),
            findsOneWidget,
          );
          expect(
            (await repo.draft(item['set_id'] as String))!['load'],
            '60.000001',
          );
        }
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
    });
  }
}
