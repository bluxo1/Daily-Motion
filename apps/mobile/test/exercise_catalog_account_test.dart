import 'dart:async';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'train_activation_test.dart' show AccountHarness, ActivationStores;
import 'exercise_catalog_repository_test.dart' show customDefinition;
import 'support/auth_fakes.dart' show ownerB;
import 'support/sync_server.dart' show testOwner;

void main() {
  const enabled = !kReleaseMode && bool.fromEnvironment('DM_LOCAL_ROUTINES');
  if (!enabled) {
    testWidgets(
      'default verified-account application does not expose catalog or custom authoring',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        expect(find.text('Create routine'), findsNothing);
        expect(find.text('Exercise catalog'), findsNothing);
        expect(find.text('Create custom exercise'), findsNothing);
      },
    );
  } else {
    testWidgets(
      'verified owner opens cached private catalog offline after cloud expiry and SQLite reopen',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        final d = customDefinition(name: 'Cached private catalog exercise');
        await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
        await h.reopen();
        h.now = h.now.add(const Duration(hours: 2));
        h.provider.refreshFailure = const AuthFailure(
          'network_unavailable',
          retryable: true,
        );
        await tester.runAsync(() => h.account.refresh(force: true));
        await tester.pumpAndSettle();
        expect(h.account.state.phase, AccountPhase.offline);
        await h.tap('Create routine');
        await h.tap('Add exercise');
        await tester.enterText(
          find.byKey(const ValueKey('catalog-search')),
          d.name,
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('catalog-${d.variantId}'));
        await h.reveal(card);
        expect(
          find.descendant(of: card, matching: find.text(d.name)),
          findsOneWidget,
        );
        expect((await h.repo.customExercise(d.variantId))!.json, d.json);
        expect(h.servers[testOwner]!.pushed, isEmpty);
      },
    );
    testWidgets(
      'sign-out and owner replacement hide the active private picker while retaining locked owner definitions',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        final d = customDefinition(name: 'Owner A private catalog definition');
        await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
        await h.tap('Create routine');
        await h.tap('Add exercise');
        await tester.enterText(
          find.byKey(const ValueKey('catalog-search')),
          d.name,
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('catalog-${d.variantId}'));
        await h.reveal(card);
        expect(
          find.descendant(of: card, matching: find.text(d.name)),
          findsOneWidget,
        );
        final work = h.account.signOut();
        await tester.pump();
        await h.drain(work);
        await tester.pumpAndSettle();
        expect(h.account.local, isNull);
        expect(
          find.text(d.name),
          findsNothing,
          reason:
              'Sign-out removes private source rows and the previous query.',
        );
        final locked = await ActivationStores(h.directory)
            .open(testOwner, existing: true);
        await expectLater(
          locked.repository.exerciseCatalog(),
          throwsA(isA<WorkoutValidation>()),
        );
        expect(
          (await locked.database
                  .customSelect(
                    'SELECT count(*) AS n FROM custom_exercise_definitions',
                  )
                  .getSingle())
              .read<int>('n'),
          1,
        );
        await locked.close();
        await h.signIn(owner: ownerB);
        expect(
          (await h.repo.exerciseCatalog()).where(
            (d) => d.source == CatalogSource.privateCustom,
          ),
          isEmpty,
        );
        await h.tap('Create routine');
        await h.tap('Add exercise');
        expect(
          find.text(d.name),
          findsNothing,
          reason: 'The new owner must not inherit the previous owner search or definition.',
        );
        await tester.enterText(
          find.byKey(const ValueKey('catalog-search')),
          d.name,
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No exercise definitions match'),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('catalog-${d.variantId}')),
          findsNothing,
          reason: 'A typed search query is not a matching private definition.',
        );
        final leave = h.account.signOut();
        await tester.pump();
        await h.drain(leave);
        await tester.pumpAndSettle();
        await h.signIn();
        expect((await h.repo.customExercise(d.variantId))!.json, d.json);
      },
    );
    testWidgets(
      'authoritative account disable hides offstage-owner catalog routes and erases all custom revisions',
      (tester) async {
        final h = AccountHarness(tester);
        await h.open();
        addTearDown(h.close);
        await h.signIn();
        final d = customDefinition(name: 'Private data to erase');
        await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
        await h.repo.saveCustomExercise(
          definition: d.displayRevision(name: d.name),
          expectedRevision: 1,
        );
        await h.tap('Create routine');
        await h.tap('Add exercise');
        await tester.enterText(
          find.byKey(const ValueKey('catalog-search')),
          d.name,
        );
        await tester.pumpAndSettle();
        await h.reveal(find.byKey(ValueKey('catalog-${d.variantId}')));
        final disabled = Completer<void>();
        void changed() {
          if (h.account.state.phase == AccountPhase.disabled &&
              !disabled.isCompleted) {
            disabled.complete();
          }
        }

        h.account.addListener(changed);
        h.servers[testOwner]!.disabled = true;
        h.account.foreground(true);
        await h.drain(disabled.future);
        h.account.removeListener(changed);
        await tester.pumpAndSettle();
        expect(h.account.local, isNull);
        expect(find.text(d.name), findsNothing);
        expect(find.byKey(const ValueKey('catalog-search')), findsNothing);
        final erased = await ActivationStores(h.directory)
            .open(testOwner, existing: true);
        expect(await erased.repository.remoteDisabled(), isTrue);
        expect(
          await erased.database
              .customSelect('SELECT * FROM custom_exercise_definitions')
              .get(),
          isEmpty,
        );
        await erased.close();
        await h.reopen();
        expect(h.account.local, isNull);
      },
    );
  }
}
