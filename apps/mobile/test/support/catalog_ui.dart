import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> revealCatalog(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: scroll,
      maxScrolls: 80,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
}

/// Exercise the production picker/custom editor, not a mocked selection result.
Future<void> addPrivateExerciseFromPicker(
  WidgetTester tester,
  String name,
) async {
  final add = find.text('Add exercise');
  await revealCatalog(tester, add);
  await tester.tap(add);
  await tester.pumpAndSettle();
  final create = find.widgetWithText(FilledButton, 'Create custom exercise');
  await revealCatalog(tester, create);
  await tester.tap(create);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('custom-name')), name);
  final save = find.widgetWithText(FilledButton, 'Save custom exercise');
  await revealCatalog(tester, save);
  await tester.tap(save);
  await tester.pumpAndSettle();
  expect(find.text('Exercise catalog'), findsOneWidget);
  final title = find.text(name);
  await revealCatalog(tester, title);
  final card = find.ancestor(of: title, matching: find.byType(Card)).first;
  final choose = find.descendant(
    of: card,
    matching: find.widgetWithText(FilledButton, 'Choose exercise'),
  );
  await revealCatalog(tester, choose);
  await tester.tap(choose);
  await tester.pumpAndSettle();
  expect(find.text('Exercise catalog'), findsNothing);
}
