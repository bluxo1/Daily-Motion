part of 'workout_repository.dart';

// SQLite text keys must use the same canonical spelling as workout UUIDs.
bool _isRoutineUuid(String value) =>
    value == value.toLowerCase() && Uuid.isValidUUID(fromString: value);

const _routineProjection =
    'SELECT r.id,r.current_template_id,r.local_revision,'
    't.local_revision AS template_revision,t.prescription '
    'FROM routines r LEFT JOIN workout_templates t ON '
    't.owner_id=r.owner_id AND t.routine_id=r.id AND t.id=r.current_template_id ';

/// Local planning shares the existing owner lock/disable guard and database.
/// Routine revisions are local CAS tokens, not sync revisions or receipts.
extension LocalRoutines on WorkoutRepository {
  SavedRoutine _decodeRoutine(QueryRow row) {
    require(
      row.readNullable<int>('template_revision') ==
              row.read<int>('local_revision') &&
          row.readNullable<String>('prescription') != null,
      'The saved routine could not be read safely. Its data has been retained.',
    );
    return SavedRoutine(
      id: row.read<String>('id'),
      templateId: row.read<String>('current_template_id'),
      localRevision: row.read<int>('local_revision'),
      plan: RoutinePlan.fromJson(
        jsonDecode(row.read<String>('prescription')) as Json,
      ),
    );
  }

  Future<SavedRoutine?> _routine(String id) async {
    final row = await db
        .customSelect(
          '${_routineProjection}WHERE r.owner_id=? AND r.id=?',
          variables: [Variable(ownerId), Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _decodeRoutine(row);
  }

  Future<SavedRoutine?> routine(String id) => db.transaction(() async {
    await _guard();
    return _routine(id);
  });

  Future<List<SavedRoutine>> routines() => db.transaction(() async {
    await _guard();
    final rows = await db
        .customSelect(
          '${_routineProjection}WHERE r.owner_id=? ORDER BY r.rowid DESC',
          variables: [Variable(ownerId)],
        )
        .get();
    return [for (final row in rows) _decodeRoutine(row)];
  });

  Future<SavedRoutine> saveRoutine({
    required String id,
    required int expectedRevision,
    required RoutinePlan plan,
  }) => db.transaction(() async {
    await _guard();
    require(_isRoutineUuid(id), 'Use a stable lowercase routine UUID.');
    require(expectedRevision >= 0, 'Invalid local routine revision.');
    final current = await _routine(id);
    final encoded = canonicalJson(plan.json);
    // An unchanged save and a response-loss retry do not publish new versions.
    if (current != null &&
        canonicalJson(current.plan.json) == encoded &&
        (current.localRevision == expectedRevision ||
            current.localRevision == expectedRevision + 1)) {
      return current;
    }
    require(
      (current?.localRevision ?? 0) == expectedRevision,
      'This routine changed in another editor. Reload before saving; your draft is retained.',
    );
    if (current == null) {
      await db.customStatement(
        'INSERT INTO routines(id,owner_id,local_revision) VALUES(?,?,0)',
        [id, ownerId],
      );
    }
    final revision = expectedRevision + 1;
    final template = newId();
    require(_isRoutineUuid(template), 'Use a stable lowercase template UUID.');
    await db.customStatement(
      'INSERT INTO workout_templates(id,owner_id,routine_id,local_revision,prescription) VALUES(?,?,?,?,?)',
      [template, ownerId, id, revision, encoded],
    );
    await db.customStatement(
      'UPDATE routines SET current_template_id=?,local_revision=? WHERE owner_id=? AND id=?',
      [template, revision, ownerId, id],
    );
    return (await _routine(id))!;
  });

  /// Caller retains the same attempt UUID until its result is known. The
  /// durable binding survives restart, routine edits and session completion.
  Future<String> startRoutine({
    required String routineId,
    required String templateId,
    required String attemptId,
    String? timezone,
  }) async {
    final watch = Stopwatch()..start();
    var created = false;
    final id = await db.transaction(() async {
      await _guard();
      require(timezone != null, 'Choose the workout timezone before starting.');
      require(_isRoutineUuid(attemptId), 'Use a stable lowercase start UUID.');
      require(
        _isRoutineUuid(routineId) && _isRoutineUuid(templateId),
        'Use the saved lowercase routine and template UUIDs.',
      );
      final prior = await db
          .customSelect(
            'SELECT * FROM routine_starts WHERE owner_id=? AND attempt_id=?',
            variables: [Variable(ownerId), Variable(attemptId)],
          )
          .getSingleOrNull();
      if (prior != null) {
        require(
          prior.read<String>('routine_id') == routineId &&
              prior.read<String>('template_id') == templateId &&
              prior.read<String>('timezone') == timezone,
          'This start identity belongs to a different request.',
        );
        final id = prior.read<String>('session_id');
        require(
          await _read(id) != null,
          'This workout was removed. The start cannot be replayed.',
        );
        return id;
      }
      final current = await _routine(routineId);
      require(
        current != null && current.templateId == templateId,
        'The routine changed. Reload before starting a workout.',
      );
      final payload = current!.plan.json..['timezone'] = timezone;
      for (final exercise in (payload['exercises'] as List).cast<Json>()) {
        exercise['session_exercise_id'] = newId();
        for (final item in (exercise['sets'] as List).cast<Json>()) {
          item['set_id'] = newId();
        }
      }
      final session = newId();
      // Existing validation, active-session guard, working state and outbox stay
      // together with the start receipt. No network or provider action occurs.
      await _commit(session, 'create_session', payload, notify: false);
      await db.customStatement(
        'INSERT INTO routine_starts(attempt_id,owner_id,routine_id,template_id,timezone,session_id) VALUES(?,?,?,?,?,?)',
        [attemptId, ownerId, routineId, templateId, timezone, session],
      );
      created = true;
      return session;
    });
    watch.stop();
    if (created) _signalCommit(watch.elapsed);
    return id;
  }
}
