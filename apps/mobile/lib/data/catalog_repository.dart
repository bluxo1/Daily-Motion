part of 'workout_repository.dart';

/// Owner-bound local catalog. No catalog mutation signals a workout commit or
/// creates an outbox command. Revisions append rather than rewriting definitions.
extension LocalExerciseCatalog on WorkoutRepository {
  CatalogDefinition _decodeCatalog(QueryRow row) {
    try {
      final definition = CatalogDefinition.fromJson(
        jsonDecode(row.read<String>('definition')) as Json,
      );
      require(
        definition.variantId == row.read<String>('variant_id') &&
            definition.revision == row.read<int>('definition_revision') &&
            definition.source == CatalogSource.privateCustom,
        'Invalid local exercise definition.',
      );
      return definition;
    } catch (_) {
      throw const WorkoutValidation(
        'A private exercise could not be read safely. Its data is retained.',
      );
    }
  }

  Future<CatalogDefinition?> _customExercise(String id) async {
    final row = await db
        .customSelect(
          'SELECT variant_id,definition_revision,definition FROM custom_exercise_definitions '
          'WHERE owner_id=? AND variant_id=? ORDER BY definition_revision DESC LIMIT 1',
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _decodeCatalog(row);
  }

  Future<CatalogDefinition?> customExercise(String id) =>
      db.transaction(() async {
        await _guard();
        return _customExercise(id);
      });

  Future<List<CatalogDefinition>> exerciseCatalog() => db.transaction(() async {
    await _guard();
    final rows = await db
        .customSelect(
          'SELECT d.variant_id,d.definition_revision,d.definition FROM custom_exercise_definitions d '
          'WHERE d.owner_id=? AND NOT EXISTS(SELECT 1 FROM custom_exercise_definitions newer '
          'WHERE newer.owner_id=d.owner_id AND newer.variant_id=d.variant_id '
          'AND newer.definition_revision>d.definition_revision) ORDER BY d.variant_id',
          variables: [Variable(ownerId)],
        )
        .get();
    return List.unmodifiable([
      ...curatedExercises,
      for (final row in rows) _decodeCatalog(row),
    ]);
  });

  Future<CatalogDefinition> saveCustomExercise({
    required CatalogDefinition definition,
    required int expectedRevision,
  }) => db.transaction(() async {
    await _guard();
    require(
      definition.source == CatalogSource.privateCustom &&
          !curatedExercises.any((d) => d.variantId == definition.variantId),
      'A private definition needs its own variant identity.',
    );
    require(
      expectedRevision >= 0 && definition.revision == expectedRevision + 1,
      'Invalid local exercise revision.',
    );
    final current = await _customExercise(definition.variantId);
    final encoded = canonicalJson(definition.json);
    // Only an exact retry of the latest committed revision is accepted.
    // Once a newer revision wins, an older request is a stale CAS edit; do not
    // return an out-of-date definition as though it were still current.
    if (current != null &&
        current.revision == definition.revision &&
        canonicalJson(current.json) == encoded) {
      return current;
    }
    require(
      (current?.revision ?? 0) == expectedRevision,
      'This exercise changed in another editor. Reopen it before saving; your input is retained.',
    );
    require(
      current == null || current.sameSemantics(definition),
      'Equipment, setup and measurement changes need a separate variant.',
    );
    await db.customStatement(
      'INSERT INTO custom_exercise_definitions(owner_id,variant_id,definition_revision,definition) VALUES(?,?,?,?)',
      [ownerId, definition.variantId, definition.revision, encoded],
    );
    return definition;
  });
}
