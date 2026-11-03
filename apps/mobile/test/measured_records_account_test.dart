import 'dart:async';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'measured_progress_account_test.dart' show ownerChart;
import 'multi_exercise_test.dart' show entry;

import 'package:daily_motion/domain/workout.dart';

import 'support/auth_fakes.dart' show ownerB;
import 'support/sync_server.dart' show testOwner;

void main() {
  testWidgets(
    'file-backed records correct, hide private read errors and recover before sign-out',
    (tester) async {
      final f = await ownerChart(tester);
      await f.h.reveal(find.text('View measured records'));
      await tester.tap(find.text('View measured records'));
      await tester.pumpAndSettle();
      expect(find.text('Measured records'), findsOneWidget);
      final controller = f.c.read(workoutsProvider.notifier);
      await controller.record(
        f.id,
        f.exercise,
        f.exercise['sets'][0] as Json,
        entry(load: '44.750000'),
        reason: 'Correct record source',
      );
      await tester.pumpAndSettle();
      await f.h.reveal(find.text('44.750000 kg'));
      expect(find.text('33.250000 kg'), findsNothing);
      f.h.repo.failReads = true;
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Measured records could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('Owner A private chart'), findsNothing);
      expect(find.textContaining('PRIVATE READ DETAIL'), findsNothing);
      f.h.repo.failReads = false;
      await tester.tap(find.text('Retry measured records'));
      await tester.pumpAndSettle();
      await f.h.reveal(find.text('44.750000 kg'));
      await f.h.drain(f.h.account.signOut());
      await tester.pumpAndSettle();
      expect(find.text('Measured records'), findsNothing);
      await f.h.signIn(owner: ownerB);
      expect(await f.h.repo.workouts(), isEmpty);
      expect(find.textContaining('Owner A private chart'), findsNothing);
      expect(find.text('44.750000 kg'), findsNothing);
    },
  );
  testWidgets(
    'current record route observes authoritative disable and drains account shutdown',
    (tester) async {
      final f = await ownerChart(tester);
      await f.h.reveal(find.text('View measured records'));
      await tester.tap(find.text('View measured records'));
      await tester.pumpAndSettle();
      expect(find.text('Measured records'), findsOneWidget);
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
      expect(find.text('33.250000 kg'), findsNothing);
      await f.h.drain(done.future);
      f.h.account.removeListener(changed);
      expect(f.h.account.local, isNull);
      expect(f.h.account.state.phase, AccountPhase.disabled);
    },
  );
}
