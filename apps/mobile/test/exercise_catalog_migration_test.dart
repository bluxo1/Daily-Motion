import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/exercise_catalog.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:drift/native.dart';

import 'repository_test.dart' show fixture, owner;
import 'routine_repository_test.dart' show routineId;
import 'exercise_catalog_repository_test.dart' show customDefinition;
import 'support/owned_fixture.dart';

const frozenSchemaFiveSha256 =
    '59b71497afc4f066a915784d0316034dc45fc54e5cb5082ee96c6c487ba4e1f1';
const template = 'd0203000-0000-4000-8000-000000000001';

class InterruptedVersionDatabase extends TrainingDatabase {
  bool reachedFinalVersion = false;
  InterruptedVersionDatabase(File file) : super(NativeDatabase(file));
  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    if (statement == 'PRAGMA user_version=6') {
      final created = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='custom_exercise_definitions'",
      ).get();
      expect(
        created,
        hasLength(1),
        reason: 'Interrupt only after the actual catalog DDL completed in the production migration transaction.',
      );
      reachedFinalVersion = true;
      throw const FileSystemException(
        'Controlled interruption before migration commit',
      );
    }
    return super.customStatement(statement, args);
  }
}

/// Exact protected-main schema-5 SQL, not a reconstructed current schema.
void seedFrozenFive(File file) {
  final bytes = File('test/support/schema_v5.sql').readAsBytesSync();
  expect(sha256.convert(bytes).toString(), frozenSchemaFiveSha256);
  final raw = sql.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA foreign_keys=ON');
    raw.execute(utf8.decode(bytes));
    final op = fixture();
    final state = applyOperation(null, op)!;
    final metadata = copyJson(state)..remove('exercises');
    raw.execute(
      'INSERT INTO local_identity(singleton,owner_id,installation_id) VALUES(1,?,?)',
      [owner, op['installation_id']],
    );
    raw.execute('INSERT INTO sync_metadata(singleton) VALUES(1)');
    raw.execute('INSERT INTO recovery_state(singleton) VALUES(1)');
    raw.execute(
      'INSERT INTO sessions(id,metadata,local_seq,branch_base) VALUES(?,?,1,0)',
      [state['aggregate_id'], canonicalJson(metadata)],
    );
    for (final (i, e) in (state['exercises'] as List).cast<Json>().indexed) {
      final definition = copyJson(e)..remove('sets');
      raw.execute(
        'INSERT INTO exercises(id,session_id,ordinal,definition) VALUES(?,?,?,?)',
        [
          e['session_exercise_id'],
          state['aggregate_id'],
          i,
          canonicalJson(definition),
        ],
      );
      for (final (j, s) in (e['sets'] as List).cast<Json>().indexed) {
        final plan = copyJson(s)..remove('observation');
        raw.execute(
          'INSERT INTO workout_sets(id,exercise_id,ordinal,prescription) VALUES(?,?,?,?)',
          [s['set_id'], e['session_exercise_id'], j, canonicalJson(plan)],
        );
      }
    }
    raw.execute(
      "INSERT INTO outbox(mutation_id,session_id,local_seq,origin_base,operation,frozen_body,state) VALUES(?,?,1,0,?,?,'pending')",
      [
        op['mutation_id'],
        op['aggregate_id'],
        canonicalJson(op),
        canonicalJson(op),
      ],
    );
    final set = allSets(state).first['set_id'];
    raw.execute('INSERT INTO drafts(set_id,values_json) VALUES(?,?)', [
      set,
      canonicalJson({'reps': '7', 'load': '62.5'}),
    ]);
    raw.execute(
      'INSERT INTO rest_timers(session_id,anchor,deadline) VALUES(?,?,?)',
      [state['aggregate_id'], '2026-10-27T10:00:00Z', '2026-10-27T10:02:00Z'],
    );
    raw.execute(
      'INSERT INTO routines(id,owner_id,local_revision) VALUES(?,?,0)',
      [routineId, owner],
    );
    raw.execute(
      'INSERT INTO workout_templates(id,owner_id,routine_id,local_revision,prescription) VALUES(?,?,?,1,?)',
      [template, owner, routineId, canonicalJson(op['payload'])],
    );
    raw.execute('UPDATE routines SET current_template_id=?,local_revision=1', [
      template,
    ]);
    raw.execute('PRAGMA user_version=5');
    expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
  } finally {
    raw.close();
  }
}

Map<String, Object?> frozenRows(File file) {
  final raw = sql.sqlite3.open(file.path);
  try {
    final names = raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return {
      for (final row in names)
        row['name'] as String: [
          for (final record in raw.select(
            'SELECT * FROM "${row['name']}" ORDER BY rowid',
          ))
            Map<String, Object?>.from(record),
        ],
    };
  } finally {
    raw.close();
  }
}

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('catalog-migration-');
    file = File('${directory.path}/v5.sqlite');
    seedFrozenFive(file);
  });
  tearDown(() async {
    await deleteOwnedTemporaryDirectory(directory, 'catalog-migration-');
  });

  test('frozen real schema 5 upgrades to 6 without changing pending bytes, plans, draft, timer or active workout', () async {
    final before = frozenRows(file);
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await repo.initialize();
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        6,
      );
      final state = (await repo.workouts()).single;
      expect(state['status'], 'active');
      expect(await repo.pendingCount(), 1);
      expect(
        await repo.prepareHead(state['aggregate_id'] as String),
        canonicalJson(fixture()),
      );
      expect((await repo.routines()).single.templateId, template);
      expect(await repo.draft(allSets(state).first['set_id'] as String), {
        'reps': '7',
        'load': '62.5',
      });
      expect((await repo.exerciseCatalog()).length, curatedExercises.length);
      await expectLater(
        repo.startRoutine(
          routineId: routineId,
          templateId: template,
          attemptId: repo.newId(),
          timezone: 'UTC',
        ),
        throwsA(isA<WorkoutValidation>()),
      );
    } finally {
      repo.dispose();
      await db.close();
    }
    final after = frozenRows(file)..remove('custom_exercise_definitions');
    expect(after, before);
    final reopened = TrainingDatabase.open(file);
    final restored = WorkoutRepository(reopened, owner);
    try {
      await restored.initialize();
      final custom = customDefinition();
      await restored.saveCustomExercise(
        definition: custom,
        expectedRevision: 0,
      );
      expect(
        (await restored.customExercise(custom.variantId))!.json,
        custom.json,
      );
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      restored.dispose();
      await reopened.close();
    }
  });
  test('late migration DDL failure rolls back schema 6 and its version without losing any schema-5 rows', () async {
    final raw = sql.sqlite3.open(file.path);
    raw.execute('CREATE INDEX custom_exercise_definitions ON outbox(state)');
    final schemaBefore = raw
        .select('SELECT type,name,sql FROM sqlite_master ORDER BY type,name')
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    raw.close();
    final before = frozenRows(file);
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await expectLater(repo.initialize(), throwsA(anything));
    } finally {
      repo.dispose();
      await db.close();
    }
    final failed = sql.sqlite3.open(file.path);
    try {
      expect(failed.select('PRAGMA user_version').single.values.single, 5);
      expect(
        failed
            .select(
              'SELECT type,name,sql FROM sqlite_master ORDER BY type,name',
            )
            .map((row) => Map<String, Object?>.from(row))
            .toList(),
        schemaBefore,
      );
      expect(frozenRows(file), before);
      failed.execute('DROP INDEX custom_exercise_definitions');
    } finally {
      failed.close();
    }
    final retry = TrainingDatabase.open(file);
    final recovery = WorkoutRepository(retry, owner);
    try {
      await recovery.initialize();
      expect(await recovery.pendingCount(), 1);
      expect(frozenRows(file)..remove('custom_exercise_definitions'), before);
    } finally {
      recovery.dispose();
      await retry.close();
    }
  });
  test('interruption after catalog DDL rolls back the new table and version together', () async {
    final before = frozenRows(file);
    final db = InterruptedVersionDatabase(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await expectLater(repo.initialize(), throwsA(anything));
      expect(db.reachedFinalVersion, isTrue);
    } finally {
      repo.dispose();
      await db.close();
    }
    final raw = sql.sqlite3.open(file.path);
    try {
      expect(raw.select('PRAGMA user_version').single.values.single, 5);
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name='custom_exercise_definitions'",
        ),
        isEmpty,
      );
      expect(frozenRows(file), before);
      expect(raw.select('PRAGMA integrity_check').single.values.single, 'ok');
    } finally {
      raw.close();
    }
    final retry = TrainingDatabase.open(file);
    final restored = WorkoutRepository(retry, owner);
    try {
      await restored.initialize();
      expect(await restored.pendingCount(), 1);
    } finally {
      restored.dispose();
      await retry.close();
    }
  });
}
