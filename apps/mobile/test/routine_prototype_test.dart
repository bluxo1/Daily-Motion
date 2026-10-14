import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/qualification/routine_prototype.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'routine previews freeze planned content without recording outcomes',
    () {
      final controller = RoutinePrototypeController();
      addTearDown(controller.dispose);
      expect(controller.preview(), true);
      final original = controller.previews.single;
      controller.edit('name', 'New name');
      controller.edit('minimumReps', '8');
      controller.edit('maximumReps', '12');
      controller.edit('restSeconds', '0');
      expect(controller.preview(), true);
      expect(original.name, 'Upper body');
      expect(original.minimumReps, 5);
      expect(original.restSeconds, 120);
      expect(controller.previews.last.minimumReps, 8);
      expect(controller.previews.last.version, 2);
      expect(() => controller.previews.clear(), throwsUnsupportedError);
    },
  );

  test('invalid or blank prescriptions never create a preview', () {
    final controller = RoutinePrototypeController();
    addTearDown(controller.dispose);
    for (final pair in const [
      ['name', ' '],
      ['sets', '0'],
      ['sets', '21'],
      ['sets', '3.5'],
      ['minimumReps', '9'],
      ['minimumReps', ''],
      ['maximumReps', '101'],
      ['restSeconds', '-1'],
      ['restSeconds', '3601'],
      ['restSeconds', '1e2'],
    ]) {
      final values = {
        'name': controller.name,
        'sets': controller.sets,
        'minimumReps': controller.minimumReps,
        'maximumReps': controller.maximumReps,
        'restSeconds': controller.restSeconds,
      };
      controller.edit(pair.first, pair.last);
      expect(controller.preview(), false, reason: pair.first);
      expect(controller.error, isNotNull);
      expect(controller.previews, isEmpty);
      controller.edit(pair.first, values[pair.first]!);
    }
  });

  testWidgets(
    'keyboard-safe routine editing preserves draft after preview back',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const RoutinePrototypeApp());
      final name = find.byKey(const ValueKey('name'));
      await tester.scrollUntilVisible(
        name,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(name, 'Changed routine');
      final rest = find.byKey(const ValueKey('restSeconds'));
      await tester.scrollUntilVisible(
        rest,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(rest, '90');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final action = find.text('Preview next workout');
      await tester.scrollUntilVisible(
        action,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('90 s planned rest'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('90 s planned rest'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('No actual load'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('No actual load'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        name,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Changed routine',
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  test(
    'light and dark primary text and action pairs meet contrast requirements',
    () {
      double ratio(Color first, Color second) {
        final a = first.computeLuminance();
        final b = second.computeLuminance();
        return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
      }

      for (final brightness in Brightness.values) {
        final theme = motionTheme(brightness);
        final colors = theme.colorScheme;
        for (final pair in [
          [colors.onSurface, colors.surface],
          [colors.onSurfaceVariant, colors.surface],
          [colors.onPrimary, colors.primary],
          [colors.onSurface, theme.scaffoldBackgroundColor],
        ]) {
          expect(ratio(pair.first, pair.last), greaterThanOrEqualTo(4.5));
        }
      }
    },
  );
}
