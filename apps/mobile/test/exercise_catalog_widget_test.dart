import 'dart:async';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/design/theme.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/features/exercise_catalog_screen.dart';
import 'package:daily_motion/features/routine_screen.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show owner;
import 'support/owned_fixture.dart';
import 'support/catalog_ui.dart';
import 'exercise_catalog_repository_test.dart' show customDefinition;

class CatalogHarness {
  final WidgetTester tester;
  final directory = Directory.systemTemp.createTempSync('catalog-ui-');
  late TrainingDatabase db;
  late WorkoutRepository repo;
  ProviderContainer? container;
  final others = <(TrainingDatabase, WorkoutRepository)>[];
  CatalogHarness(this.tester);
  Future<void> open() async {
    db = TrainingDatabase(
      NativeDatabase(File('${directory.path}/owner.sqlite')),
    );
    repo = WorkoutRepository(db, owner);
    await repo.initialize();
  }

  Future<void> mount({
    Widget home = const RoutineScreen(),
    Brightness brightness = Brightness.light,
  }) async {
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(theme: motionTheme(brightness), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container?.dispose();
    container = null;
  }

  Future<void> reopen() async {
    await unmount();
    repo.dispose();
    await db.close();
    await open();
    await mount();
  }

  Future<void> close() async {
    await unmount();
    repo.dispose();
    await db.close();
    for (final (database, repository) in others) {
      repository.dispose();
      await database.close();
    }
    await deleteOwnedTemporaryDirectory(directory, 'catalog-ui-');
  }

  Future<void> tap(Finder target) async {
    await revealCatalog(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> text(Finder target, String value) async {
    await revealCatalog(tester, target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> choose(CatalogDefinition d) async {
    await text(find.byKey(const ValueKey('catalog-search')), d.name);
    final card = find.byKey(ValueKey('catalog-${d.variantId}'));
    await tap(
      find.descendant(
        of: card,
        matching: find.widgetWithText(FilledButton, 'Choose exercise'),
      ),
    );
  }

  Future<void> select(String label, String item) async {
    final field = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField &&
          w.key is ValueKey<String> &&
          ((w.key as ValueKey<String>).value == 'custom-$label' ||
              (w.key as ValueKey<String>).value.startsWith('catalog-$label-')),
    );
    await tap(field);
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }
}

Future<CatalogHarness> catalogHarness(WidgetTester tester) async {
  final h = CatalogHarness(tester);
  await h.open();
  addTearDown(h.close);
  return h;
}

void main() {
  testWidgets(
    'routine Add exercise opens a searchable catalog instead of a blank identity',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('catalog-ui-');
      final db = TrainingDatabase(
        NativeDatabase(File('${directory.path}/owner.sqlite')),
      );
      final repo = WorkoutRepository(db, owner);
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        repo.dispose();
        await db.close();
        await deleteOwnedTemporaryDirectory(directory, 'catalog-ui-');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: motionTheme(Brightness.light),
            home: const RoutineEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise catalog'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-search')), findsOneWidget);
      expect(await repo.routines(), isEmpty);
      expect(await repo.workouts(), isEmpty);
      expect(await repo.pendingCount(), 0);
    },
  );
  testWidgets(
    'case-insensitive catalog search and equipment/category filters preserve distinct identities',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.mount(home: const ExerciseCatalogScreen());
      await h.text(find.byKey(const ValueKey('catalog-search')), 'DUMBBELL');
      expect(find.text('6 matching definitions'), findsOneWidget);
      await h.select('Equipment', 'Barbell');
      expect(
        find.textContaining('No exercise definitions match'),
        findsOneWidget,
      );
      await h.text(find.byKey(const ValueKey('catalog-search')), '');
      await h.select('Movement category', 'Push');
      expect(find.text('2 matching definitions'), findsOneWidget);
      await h.text(find.byKey(const ValueKey('catalog-search')), '  bench  ');
      final d = curatedExercises.first;
      await revealCatalog(
        tester,
        find.byKey(ValueKey('catalog-${d.variantId}')),
      );
      expect(find.text(d.conventions), findsOneWidget);
      expect(await h.repo.pendingCount(), 0);
    },
  );
  testWidgets(
    'repeated curated selection saves distinct instances and reloads the same variant',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.mount();
      await h.tap(find.text('New routine'));
      await h.text(
        find.byKey(const ValueKey('routine-name')),
        'Repeated bench',
      );
      for (var i = 0; i < 2; i++) {
        await h.tap(find.text('Add exercise'));
        await h.choose(curatedExercises.first);
      }
      await h.tap(find.text('Save routine'));
      final before = (await h.repo.routines()).single;
      final entries = before.plan.exercises;
      expect(
        entries.map((e) => e['session_exercise_id']).toSet(),
        hasLength(2),
      );
      expect(entries.map((e) => e['variant_id']).toSet(), {
        curatedExercises.first.variantId,
      });
      expect(
        entries
            .expand((e) => e['sets'] as List)
            .map((s) => s['set_id'])
            .toSet(),
        hasLength(6),
      );
      await h.reopen();
      expect((await h.repo.routines()).single.plan.json, before.plan.json);
      await h.tap(find.text('Edit routine'));
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Exercise name',
      );
      await revealCatalog(tester, field.first);
      expect(tester.widget<TextField>(field.first).readOnly, isTrue);
      expect(await h.repo.workouts(), isEmpty);
      expect(await h.repo.pendingCount(), 0);
    },
  );
  testWidgets(
    'custom write failure retains input; rapid retry saves one reusable definition',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.mount();
      await h.tap(find.text('New routine'));
      await h.text(find.byKey(const ValueKey('routine-name')), 'Private plan');
      await h.tap(find.text('Add exercise'));
      await h.tap(find.text('Create custom exercise'));
      await h.text(
        find.byKey(const ValueKey('custom-name')),
        'My machine setup',
      );
      await h.db.customStatement(
        "CREATE TRIGGER fail_custom_ui BEFORE INSERT ON custom_exercise_definitions BEGIN SELECT RAISE(ABORT,'PRIVATE WRITE DETAIL'); END",
      );
      await h.tap(find.text('Save custom exercise'));
      expect(find.byKey(const ValueKey('custom-error')), findsOneWidget);
      expect(find.textContaining('PRIVATE WRITE DETAIL'), findsNothing);
      await revealCatalog(tester, find.byKey(const ValueKey('custom-name')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('custom-name')))
            .controller!
            .text,
        'My machine setup',
      );
      expect(
        (await h.repo.exerciseCatalog()).where(
          (d) => d.source == CatalogSource.privateCustom,
        ),
        isEmpty,
      );
      await h.db.customStatement('DROP TRIGGER fail_custom_ui');
      final button = find.text('Save custom exercise');
      await revealCatalog(tester, button);
      await tester.tap(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final custom = (await h.repo.exerciseCatalog())
          .where((d) => d.source == CatalogSource.privateCustom)
          .single;
      expect(custom.revision, 1);
      await h.choose(custom);
      await h.tap(find.text('Save routine'));
      await h.reopen();
      expect(
        (await h.repo.routines()).single.plan.exercises.single['variant_id'],
        custom.variantId,
      );
      await h.tap(find.text('New routine'));
      await h.text(find.byKey(const ValueKey('routine-name')), 'Reuse private');
      await h.tap(find.text('Add exercise'));
      await h.choose(custom);
      await h.tap(find.text('Save routine'));
      expect(
        (await h.repo.routines()).every(
          (r) => r.plan.exercises.single['variant_id'] == custom.variantId,
        ),
        isTrue,
      );
      expect(await h.repo.pendingCount(), 0);
    },
  );
  testWidgets(
    'private rename and archive retain identity; material editing uses a separate variant',
    (tester) async {
      final h = await catalogHarness(tester);
      final original = customDefinition();
      await h.repo.saveCustomExercise(
        definition: original,
        expectedRevision: 0,
      );
      await h.mount(home: const ExerciseCatalogScreen());
      await h.text(find.byKey(const ValueKey('catalog-search')), original.name);
      await h.tap(find.text('Rename'));
      await h.text(find.byKey(const ValueKey('custom-name')), 'Renamed custom');
      await h.tap(find.text('Save custom exercise'));
      final renamed = (await h.repo.customExercise(original.variantId))!;
      expect(renamed.revision, 2);
      expect(renamed.variantId, original.variantId);
      expect(renamed.sameSemantics(original), isTrue);
      await h.tap(find.text('Create separate variant'));
      await h.select('Load convention', 'Positive assistance');
      await h.tap(find.text('Save custom exercise'));
      final definitions = (await h.repo.exerciseCatalog())
          .where((d) => d.source == CatalogSource.privateCustom)
          .toList();
      expect(definitions, hasLength(2));
      expect(definitions.map((d) => d.variantId).toSet(), hasLength(2));
      expect(
        definitions.every((d) => d.movementId == original.movementId),
        isTrue,
      );
      expect(definitions.map((d) => d.loading).toSet(), {
        CatalogLoading.machineStack,
        CatalogLoading.assistance,
      });
      await h.text(
        find.byKey(const ValueKey('catalog-search')),
        'Renamed custom',
      );
      final card = find.byKey(ValueKey('catalog-${original.variantId}'));
      await h.tap(find.descendant(of: card, matching: find.text('Archive')));
      expect(
        (await h.repo.customExercise(original.variantId))!.archived,
        isTrue,
      );
      await h.tap(find.text('Archived private exercises'));
      expect(find.text('1 matching definitions'), findsOneWidget);
      await h.tap(find.text('Restore'));
      expect(
        (await h.repo.customExercise(original.variantId))!.archived,
        isFalse,
      );
    },
  );
  testWidgets(
    'custom back confirmation retains input and restores picker search focus',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.mount(home: const ExerciseCatalogScreen());
      await h.tap(find.text('Create custom exercise'));
      await h.text(find.byKey(const ValueKey('custom-name')), 'Unsaved custom');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved custom exercise?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('custom-name')))
            .controller!
            .text,
        'Unsaved custom',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise catalog'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('catalog-search')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(
        (await h.repo.exerciseCatalog()).where(
          (d) => d.source == CatalogSource.privateCustom,
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'catalog read error hides private data and Retry restores the real file',
    (tester) async {
      final h = await catalogHarness(tester);
      final d = customDefinition();
      await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
      await h.db.customStatement(
        'ALTER TABLE custom_exercise_definitions RENAME TO unavailable_catalog',
      );
      await h.mount(home: const ExerciseCatalogScreen());
      expect(
        find.text('Exercises could not be loaded. Local data is retained.'),
        findsOneWidget,
      );
      expect(find.text(d.name), findsNothing);
      expect(find.textContaining('no such table'), findsNothing);
      await h.db.customStatement(
        'ALTER TABLE unavailable_catalog RENAME TO custom_exercise_definitions',
      );
      await h.tap(find.text('Retry catalog'));
      await h.text(find.byKey(const ValueKey('catalog-search')), d.name);
      final card = find.byKey(ValueKey('catalog-${d.variantId}'));
      await revealCatalog(tester, card);
      expect(
        find.descendant(of: card, matching: find.text(d.name)),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'owner replacement removes old private picker content and semantics before loading another account',
    (tester) async {
      final h = await catalogHarness(tester);
      final d = customDefinition(name: 'Owner A private exercise');
      await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
      await h.mount(home: const ExerciseCatalogScreen());
      await h.text(find.byKey(const ValueKey('catalog-search')), d.name);
      await revealCatalog(
        tester,
        find.byKey(ValueKey('catalog-${d.variantId}')),
      );
      final db = TrainingDatabase(
        NativeDatabase(File('${h.directory.path}/b.sqlite')),
      );
      final repo = WorkoutRepository(
        db,
        '20000000-0000-4000-8000-000000000002',
      );
      await repo.initialize();
      h.others.add((db, repo));
      h.container!.updateOverrides([
        repositoryProvider.overrideWithValue(repo),
      ]);
      await tester.pump();
      expect(find.text(d.name), findsNothing);
      expect(
        find.textContaining('This account is unavailable'),
        findsOneWidget,
      );
      expect(await repo.exerciseCatalog(), hasLength(curatedExercises.length));
    },
  );
  testWidgets(
    'routine editor recovers from catalog read failure without unlocking unknown identities',
    (tester) async {
      final h = await catalogHarness(tester);
      final legacy = customDefinition().prescription(h.repo.newId)
        ..remove('side');
      final saved = await h.repo.saveRoutine(
        id: h.repo.newId(),
        expectedRevision: 0,
        plan: RoutinePlan(name: 'Safe legacy routine', exercises: [legacy]),
      );
      await h.db.customStatement(
        'ALTER TABLE custom_exercise_definitions RENAME TO unavailable_catalog',
      );
      await h.mount(home: RoutineEditorScreen(initial: saved));
      final exerciseName = find.byKey(
        ValueKey('exercise-name-${legacy['session_exercise_id']}'),
      );
      expect(
        find.byKey(const ValueKey('routine-catalog-error')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(exerciseName).readOnly, isTrue);
      expect(find.textContaining('no such table'), findsNothing);
      final retry = find.byKey(const ValueKey('routine-catalog-retry'));
      await revealCatalog(tester, retry);
      await h.db.customStatement(
        'ALTER TABLE unavailable_catalog RENAME TO custom_exercise_definitions',
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('routine-catalog-error')), findsNothing);
      expect(tester.widget<TextField>(exerciseName).readOnly, isFalse);
      expect((await h.repo.routine(saved.id))!.plan.exercises.single, legacy);
    },
  );
  testWidgets(
    'repeated routine catalog retries keep unsaved input and legacy identity until verified recovery',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        final h = await catalogHarness(tester);
        final legacy = customDefinition().prescription(h.repo.newId)
          ..remove('side');
        final saved = await h.repo.saveRoutine(
          id: h.repo.newId(),
          expectedRevision: 0,
          plan: RoutinePlan(name: 'Recovery plan', exercises: [legacy]),
        );
        await h.mount();
        await h.db.customStatement(
          'ALTER TABLE custom_exercise_definitions RENAME TO unavailable_catalog',
        );
        h.container!.invalidate(exerciseCatalogProvider);
        await h.tap(find.text('Edit routine'));
        final routineName = find.byKey(const ValueKey('routine-name'));
        await h.text(routineName, 'Unsaved recovery name');
        final retry = find.byKey(const ValueKey('routine-catalog-retry'));
        await revealCatalog(tester, retry);
        expect(find.bySemanticsLabel('Retry exercise catalog'), findsOneWidget);
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        await h.db.customStatement(
          'ALTER TABLE unavailable_catalog RENAME TO custom_exercise_definitions',
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        final pending = h.db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        try {
          await tester.tap(retry);
          await tester.tap(retry);
          await tester.pump();
          expect(h.container!.read(exerciseCatalogProvider).isLoading, isTrue);
          final exerciseName = find.byKey(
            ValueKey('exercise-name-${legacy['session_exercise_id']}'),
          );
          await revealCatalog(tester, exerciseName);
          expect(tester.widget<TextField>(exerciseName).readOnly, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          release.complete();
          await pending;
        }
        await tester.pumpAndSettle();
        final exerciseName = find.byKey(
          ValueKey('exercise-name-${legacy['session_exercise_id']}'),
        );
        expect(tester.widget<TextField>(exerciseName).readOnly, isFalse);
        await h.text(exerciseName, 'Edited legacy definition');
        final reps = find
            .byWidgetPredicate(
              (w) =>
                  w is TextField && w.decoration?.labelText == 'Planned reps',
            )
            .first;
        await h.text(reps, '8');
        await revealCatalog(tester, routineName);
        expect(
          tester.widget<TextField>(routineName).controller!.text,
          'Unsaved recovery name',
        );
        await h.tap(find.text('Save routine'));
        final updated = (await h.repo.routine(saved.id))!;
        expect(updated.plan.name, 'Unsaved recovery name');
        final exercise = updated.plan.exercises.single;
        expect(exercise['session_exercise_id'], legacy['session_exercise_id']);
        expect(exercise['variant_id'], isNot(legacy['variant_id']));
        expect(exercise.containsKey('side'), isFalse);
        expect(exercise['sets'][0]['planned']['reps'], 8);
        expect(exercise['sets'][0]['set_id'], legacy['sets'][0]['set_id']);
        expect(exercise['sets'][0]['planned']['rest_seconds'], 120);
        expect(
          (await h.repo.exerciseCatalog()).length,
          curatedExercises.length,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final switchOwner in [false, true]) {
    testWidgets(
      'pending routine catalog retry tolerates ${switchOwner ? 'owner replacement' : 'widget disposal'}',
      (tester) async {
        final h = await catalogHarness(tester);
        final legacy = customDefinition(name: 'Owner A legacy exercise')
            .prescription(h.repo.newId);
        final saved = await h.repo.saveRoutine(
          id: h.repo.newId(),
          expectedRevision: 0,
          plan: RoutinePlan(name: 'Owner A private plan', exercises: [legacy]),
        );
        final otherDb = TrainingDatabase(
          NativeDatabase(File('${h.directory.path}/pending-owner-b.sqlite')),
        );
        final other = WorkoutRepository(
          otherDb,
          '20000000-0000-4000-8000-000000000002',
        );
        await other.initialize();
        h.others.add((otherDb, other));
        await h.db.customStatement(
          'ALTER TABLE custom_exercise_definitions RENAME TO unavailable_catalog',
        );
        await h.mount(home: RoutineEditorScreen(initial: saved));
        final retry = find.byKey(const ValueKey('routine-catalog-retry'));
        await revealCatalog(tester, retry);
        await h.db.customStatement(
          'ALTER TABLE unavailable_catalog RENAME TO custom_exercise_definitions',
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        final pending = h.db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        try {
          await tester.tap(retry);
          await tester.pump();
          expect(h.container!.read(exerciseCatalogProvider).isLoading, isTrue);
          if (switchOwner) {
            h.container!.updateOverrides([
              repositoryProvider.overrideWithValue(other),
            ]);
            await tester.pump();
            expect(
              find.textContaining('This account is unavailable'),
              findsOneWidget,
            );
          } else {
            await h.unmount();
          }
        } finally {
          release.complete();
          await pending;
        }
        await tester.pumpAndSettle();
        expect(find.text('Owner A legacy exercise'), findsNothing);
        expect(
          find.byKey(const ValueKey('routine-catalog-retry')),
          findsNothing,
        );
        expect((await h.repo.routine(saved.id))!.plan.exercises.single, legacy);
        expect(await other.routines(), isEmpty);
        expect(
          await other.exerciseCatalog(),
          hasLength(curatedExercises.length),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'legacy omitted side and manual variant remain unchanged after planned target edits',
    (tester) async {
      final h = await catalogHarness(tester);
      final e = customDefinition().prescription(h.repo.newId)..remove('side');
      final saved = await h.repo.saveRoutine(
        id: h.repo.newId(),
        expectedRevision: 0,
        plan: RoutinePlan(name: 'Legacy plan', exercises: [e]),
      );
      await h.mount();
      await h.tap(find.text('Edit routine'));
      final reps = find
          .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Planned reps',
          )
          .first;
      await h.text(reps, '8');
      await h.tap(find.text('Save routine'));
      await h.reopen();
      final updated = (await h.repo.routine(saved.id))!.plan.exercises.single;
      expect(exerciseKey(updated), exerciseKey(e));
      expect(updated.containsKey('side'), isFalse);
      expect(updated['sets'][0]['planned']['reps'], 8);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      '320px 200 percent text catalog and custom input remain usable in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final h = await catalogHarness(tester);
          await h.mount(
            home: const ExerciseCatalogScreen(),
            brightness: brightness,
          );
          await h.text(
            find.byKey(const ValueKey('catalog-search')),
            'Barbell bench',
          );
          expect(
            find.bySemanticsLabel(RegExp('Search exercises')),
            findsWidgets,
          );
          await revealCatalog(tester, find.text(curatedExercises.first.name));
          expect(
            find.bySemanticsLabel(RegExp('Choose Barbell bench press')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await h.tap(find.text('Create custom exercise'));
          await h.text(
            find.byKey(const ValueKey('custom-name')),
            'Accessible custom',
          );
          await revealCatalog(tester, find.text('Save custom exercise'));
          expect(
            tester
                .getSize(
                  find.widgetWithText(FilledButton, 'Save custom exercise'),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('successful archive retry clears the earlier storage error', (
    tester,
  ) async {
    final h = await catalogHarness(tester);
    final d = customDefinition();
    await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
    await h.mount(home: const ExerciseCatalogScreen());
    await h.text(find.byKey(const ValueKey('catalog-search')), d.name);
    await h.db.customStatement(
      "CREATE TRIGGER fail_archive BEFORE INSERT ON custom_exercise_definitions BEGIN SELECT RAISE(ABORT,'PRIVATE ARCHIVE DETAIL'); END",
    );
    await h.tap(find.text('Archive'));
    expect(find.byKey(const ValueKey('catalog-error')), findsOneWidget);
    expect((await h.repo.customExercise(d.variantId))!.archived, isFalse);
    await h.db.customStatement('DROP TRIGGER fail_archive');
    await h.tap(find.text('Archive'));
    expect((await h.repo.customExercise(d.variantId))!.archived, isTrue);
    expect(find.byKey(const ValueKey('catalog-error')), findsNothing);
  });
  testWidgets(
    'renaming an optional-side definition preserves its original unspecified-side metadata',
    (tester) async {
      final h = await catalogHarness(tester);
      final template = customDefinition();
      final d = CatalogDefinition(
        movementId: template.movementId,
        variantId: template.variantId,
        revision: 1,
        name: template.name,
        equipment: template.equipment,
        setup: template.setup,
        category: template.category,
        loading: template.loading,
        repetitions: template.repetitions,
        source: template.source,
      );
      await h.repo.saveCustomExercise(definition: d, expectedRevision: 0);
      await h.mount(home: const ExerciseCatalogScreen());
      await h.text(find.byKey(const ValueKey('catalog-search')), d.name);
      await h.tap(find.text('Rename'));
      await h.text(
        find.byKey(const ValueKey('custom-name')),
        'Renamed optional side',
      );
      await h.tap(find.text('Save custom exercise'));
      expect(find.byKey(const ValueKey('custom-error')), findsNothing);
      final renamed = (await h.repo.customExercise(d.variantId))!;
      expect(renamed.revision, 2);
      expect(renamed.side, isNull);
      expect(renamed.sameSemantics(d), isTrue);
    },
  );
  testWidgets(
    'keyboard activation and repeated Choose callbacks add just one exercise instance',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.mount();
      await h.tap(find.text('New routine'));
      await h.text(find.byKey(const ValueKey('routine-name')), 'Keyboard plan');
      await h.tap(find.text('Add exercise'));
      final search = find.byKey(const ValueKey('catalog-search'));
      await h.text(search, 'Barbell bench');
      final searchNode = tester.widget<TextField>(search).focusNode!;
      expect(searchNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(searchNode.hasFocus, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(searchNode.hasFocus, isTrue);
      final card = find.byKey(
        ValueKey('catalog-${curatedExercises.first.variantId}'),
      );
      final button = find.descendant(
        of: card,
        matching: find.widgetWithText(FilledButton, 'Choose exercise'),
      );
      await revealCatalog(tester, button);
      Focus.of(
        tester.element(
          find.descendant(of: button, matching: find.text('Choose exercise')),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Exercise catalog'), findsNothing);
      await h.tap(find.text('Save routine'));
      expect((await h.repo.routines()).single.plan.exercises, hasLength(1));
    },
  );
  testWidgets(
    'large private catalog builds lazy source rows and searches the retained SQLite definitions',
    (tester) async {
      final h = await catalogHarness(tester);
      await h.db.transaction(() async {
        for (var i = 0; i < 300; i++) {
          await h.repo.saveCustomExercise(
            definition: customDefinition(
              name: 'Private exercise ${i.toString().padLeft(3, '0')}',
            ),
            expectedRevision: 0,
          );
        }
      });
      await h.mount(home: const ExerciseCatalogScreen());
      await h.select('Source', 'Private custom');
      expect(find.text('300 matching definitions'), findsOneWidget);
      expect(find.byType(Card).evaluate().length, lessThan(12));
      await h.text(
        find.byKey(const ValueKey('catalog-search')),
        'exercise 299',
      );
      expect(find.text('1 matching definitions'), findsOneWidget);
      await revealCatalog(tester, find.text('Private exercise 299'));
      expect(find.text('Private exercise 299'), findsOneWidget);
    },
  );
}
