import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/exercise_history.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('optional catalog side is explicit unspecified instead of the server both default', () {
    final d = CatalogDefinition(
      movementId: const Uuid().v4(),
      variantId: const Uuid().v4(),
      revision: 1,
      name: 'Unknown side',
      equipment: CatalogEquipment.other,
      setup: '',
      category: MovementCategory.other,
      loading: CatalogLoading.totalExternal,
      repetitions: CatalogRepetitions.bilateral,
      source: CatalogSource.privateCustom,
    );
    expect(d.prescription(const Uuid().v4)['side'], 'unspecified');
  });
  test('first-party catalog has explicit unique stable UUIDs and compatible prescriptions', () {
    expect(curatedExercises, hasLength(16));
    expect(curatedExercises.map((d) => d.variantId).toSet(), hasLength(16));
    expect(
      curatedExercises.first.variantId,
      'd0202000-0000-4000-8000-000000000001',
    );
    for (final d in curatedExercises) {
      final a = d.prescription(const Uuid().v4);
      final b = d.prescription(const Uuid().v4);
      expect(a['session_exercise_id'], isNot(b['session_exercise_id']));
      expect(
        (a['sets'] as List)
            .map((s) => s['set_id'])
            .toSet()
            .intersection((b['sets'] as List).map((s) => s['set_id']).toSet()),
        isEmpty,
      );
      expect(exerciseKey(a), exerciseKey(b));
      expect(a['variant_id'], d.variantId);
      final plan = RoutinePlan(name: 'Plan', exercises: [a, b]);
      expect(
        plan.exercises.every(
          (e) =>
              (e['sets'] as List).every((s) => !s.containsKey('observation')),
        ),
        isTrue,
      );
      expect(CatalogDefinition.fromJson(d.json).json, d.json);
      expect(d.source, CatalogSource.firstParty);
    }
  });
  test(
    'display revisions preserve key and leave detached snapshots unchanged',
    () {
      final original = curatedExercises.first;
      final before = original.prescription(const Uuid().v4);
      final renamed = original.displayRevision(name: 'New display name');
      expect(renamed.revision, 2);
      expect(
        exerciseKey(before),
        exerciseKey(renamed.prescription(const Uuid().v4)),
      );
      expect(before['name'], original.name);
      final copy = original.json..['name'] = 'External mutation';
      expect(copy['name'], isNot(original.name));
      expect(original.name, 'Barbell bench press');
    },
  );
  test('case-insensitive search and metadata filters do not merge names or variants', () {
    final results = filterCatalog(
      curatedExercises,
      search: '  DUMBBELL ',
      equipment: CatalogEquipment.dumbbell,
      category: MovementCategory.push,
    );
    expect(results.map((d) => d.name), [
      'Dumbbell bench press',
      'Dumbbell overhead press',
    ]);
    expect(filterCatalog(curatedExercises, search: 'missing'), isEmpty);
    expect(filterCatalog(curatedExercises, archived: true), isEmpty);
    final repeated = curatedExercises.first.displayRevision(
      name: curatedExercises[1].name,
    );
    expect(
      filterCatalog([repeated, curatedExercises[1]], search: 'dumbbell bench'),
      hasLength(2),
    );
    expect(
      exerciseKey(repeated.prescription(const Uuid().v4)),
      isNot(exerciseKey(curatedExercises[1].prescription(const Uuid().v4))),
    );
  });
  test('all existing loading and repetition conventions are explicit without actual values', () {
    for (final loading in CatalogLoading.values) {
      for (final reps in CatalogRepetitions.values) {
        final d = CatalogDefinition(
          movementId: const Uuid().v4(),
          variantId: const Uuid().v4(),
          revision: 1,
          name: 'Private',
          equipment: CatalogEquipment.other,
          setup: '',
          category: MovementCategory.other,
          loading: loading,
          repetitions: reps,
          source: CatalogSource.privateCustom,
        );
        final plan = RoutinePlan(
          name: 'Plan',
          exercises: [d.prescription(const Uuid().v4)],
        );
        final e = plan.exercises.single;
        expect(e['loading_basis'], loading.wire);
        expect(e['rep_convention'], reps.wire);
        expect(e['side'], 'unspecified');
        for (final s in e['sets'] as List) {
          expect(s['planned']['load'], isNull);
          expect(s.containsKey('observation'), isFalse);
        }
      }
    }
  });
  test('archiving prevents new selection but does not mutate existing prescriptions', () {
    final original = curatedExercises.first;
    final before = original.prescription(const Uuid().v4);
    final archived = original.displayRevision(
      name: original.name,
      archived: true,
    );
    expect(
      () => archived.prescription(const Uuid().v4),
      throwsA(isA<WorkoutValidation>()),
    );
    expect(
      RoutinePlan(name: 'Existing plan', exercises: [before]).exercises.single,
      before,
    );
    expect(
      filterCatalog([archived], archived: true).single.variantId,
      original.variantId,
    );
  });
  for (final name in ['', '  ', 'bad\nname', 'a' * 121]) {
    test('invalid display name rejects ${name.length} characters safely', () {
      expect(
        () => curatedExercises.first.displayRevision(name: name),
        throwsA(isA<WorkoutValidation>()),
      );
    });
  }
}
