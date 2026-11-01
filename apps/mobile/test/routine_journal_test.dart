// Real file DDL, background-isolate migration and reopening can exceed the
// default 30 seconds under parallel native workers. This is an integrity test,
// not a device latency qualification; retain a bounded recovery-test deadline.
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import 'exercise_catalog_migration_test.dart' show seedFrozenFive, frozenRows;
import 'exercise_catalog_repository_test.dart' show customDefinition;
import 'repository_test.dart' show owner, fixture, recordPayload;
import 'routine_repository_test.dart' show routineId, routinePlan;
import 'support/owned_fixture.dart';

class InterruptedJournalDatabase extends TrainingDatabase {
  final String boundary;
  InterruptedJournalDatabase(File file, this.boundary)
    : super(NativeDatabase(file));

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    if (statement.startsWith(boundary)) {
      throw const FileSystemException('Controlled journal migration fault');
    }
    return super.customStatement(statement, args);
  }
}

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routine-journal-');
    file = File('${directory.path}/owner.sqlite');
  });
  tearDown(() async {
    await deleteOwnedTemporaryDirectory(directory, 'routine-journal-');
  });

  void seedSix() {
    final frozen = File('test/support/schema_v6.sql').readAsBytesSync();
    expect(
      sha256.convert(frozen).toString(),
      '27905e4417b224f31ca4aa40c61e3c2ae0c12dca7468ac224572b697e695e546',
    );
    seedFrozenFive(file);
    final raw = sql.sqlite3.open(file.path);
    try {
      // Seed one complete old fixture, without an fsync for every setup row.
      // The tested upgrade still runs separately through the real repository.
      raw.execute('BEGIN IMMEDIATE');
      // Exact additional DDL from the frozen schema-6 Git blob.
      raw.execute(
        utf8
            .decode(frozen)
            .split('CREATE TABLE custom_exercise_definitions')
            .last
            .replaceFirst(' (', 'CREATE TABLE custom_exercise_definitions ('),
      );
      final definition = customDefinition();
      raw.execute('INSERT INTO custom_exercise_definitions VALUES(?,?,?,?)', [
        owner,
        definition.variantId,
        1,
        canonicalJson(definition.json),
      ]);
      raw.execute('INSERT INTO workout_templates VALUES(?,?,?,?,?)', [
        'd0203000-0000-4000-8000-000000000002',
        owner,
        routineId,
        3,
        canonicalJson(routinePlan(name: 'Updated').json),
      ]);
      raw.execute(
        'UPDATE routines SET current_template_id=?,local_revision=3',
        ['d0203000-0000-4000-8000-000000000002'],
      );
      raw.execute('INSERT INTO historical_receipts VALUES(?,?)', [
        const Uuid().v4(),
        '{"historical":"retained"}',
      ]);
      const secondRoutine = '60000000-0000-4000-8000-000000000002';
      const secondTemplate = 'd0203000-0000-4000-8000-000000000003';
      raw.execute(
        'INSERT INTO routines(id,owner_id,local_revision) VALUES(?,?,0)',
        [secondRoutine, owner],
      );
      raw.execute('INSERT INTO workout_templates VALUES(?,?,?,?,?)', [
        secondTemplate,
        owner,
        secondRoutine,
        1,
        canonicalJson(routinePlan(name: 'Second saved routine').json),
      ]);
      raw.execute(
        'UPDATE routines SET current_template_id=?,local_revision=1 WHERE id=?',
        [secondTemplate, secondRoutine],
      );
      // Build the completed historical workout with the actual domain reducer,
      // then populate the frozen old layout without using a schema-7 writer.
      final create = fixture();
      create['aggregate_id'] = const Uuid().v4();
      create['mutation_id'] = const Uuid().v4();
      for (final exercise
          in (create['payload']['exercises'] as List).cast<Json>()) {
        exercise['session_exercise_id'] = const Uuid().v4();
        for (final set in (exercise['sets'] as List).cast<Json>()) {
          set['set_id'] = const Uuid().v4();
        }
      }
      final active = applyOperation(null, create, revision: 1)!;
      final record = {
        ...create,
        'mutation_id': const Uuid().v4(),
        'command': 'record_set',
        'expected_revision': 1,
        'payload': recordPayload(active),
      };
      final measured = applyOperation(active, record, revision: 2)!;
      final complete = {
        ...create,
        'mutation_id': const Uuid().v4(),
        'command': 'complete_session',
        'expected_revision': 2,
        'payload': <String, dynamic>{},
      };
      final completed = applyOperation(measured, complete, revision: 3)!;
      final metadata = copyJson(completed)..remove('exercises');
      raw.execute('INSERT INTO sessions(id,metadata,local_seq) VALUES(?,?,3)', [
        completed['aggregate_id'],
        canonicalJson(metadata),
      ]);
      for (final (i, exercise)
          in (completed['exercises'] as List).cast<Json>().indexed) {
        final definition = copyJson(exercise)..remove('sets');
        raw.execute(
          'INSERT INTO exercises(id,session_id,ordinal,definition) VALUES(?,?,?,?)',
          [
            exercise['session_exercise_id'],
            completed['aggregate_id'],
            i,
            canonicalJson(definition),
          ],
        );
        for (final (j, set)
            in (exercise['sets'] as List).cast<Json>().indexed) {
          final prescription = copyJson(set)..remove('observation');
          raw.execute(
            'INSERT INTO workout_sets(id,exercise_id,ordinal,prescription,observation) VALUES(?,?,?,?,?)',
            [
              set['set_id'],
              exercise['session_exercise_id'],
              j,
              canonicalJson(prescription),
              set['observation'] == null
                  ? null
                  : canonicalJson(set['observation']),
            ],
          );
        }
      }
      raw.execute(
        'INSERT INTO shadows(session_id,revision,projection) VALUES(?,3,?)',
        [completed['aggregate_id'], canonicalJson(completed)],
      );
      raw.execute(
        'INSERT INTO local_observations(session_id,local_seq,set_id,payload) VALUES(?,2,?,?)',
        [
          completed['aggregate_id'],
          record['payload']['set_id'],
          canonicalJson(record['payload']),
        ],
      );
      raw.execute('UPDATE recovery_state SET high_water=11');
      raw.execute('PRAGMA user_version=6');
      expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
      raw.execute('COMMIT');
    } finally {
      raw.close();
    }
  }

  for (final stage in ['before', 'during', 'after']) {
    test(
      'hard process kill $stage schema7 upgrade preserves the rich schema6 fixture',
      () async {
        seedSix();
        final before = frozenRows(file);
        final lock = await File(
          path.join('.dart_tool', 'process-kill-worker.lock'),
        ).open(mode: FileMode.append);
        Process? process;
        int? worker;
        var exited = false;
        StreamSubscription<String>? output;
        StreamSubscription<String>? errors;
        final stdoutDone = Completer<void>();
        final stderrDone = Completer<void>();
        final boundary = Completer<void>();
        Json? result;
        final errorText = StringBuffer();
        try {
          await lock.lock(FileLock.blockingExclusive);
          final sdk =
              Platform.environment['FLUTTER_ROOT'] ??
              path.join(
                Directory.current.parent.parent.path,
                '.tools',
                'flutter',
              );
          final executable =
              Platform.environment['DM_DART_EXECUTABLE'] ??
              path.join(
                sdk,
                'bin',
                'cache',
                'dart-sdk',
                'bin',
                Platform.isWindows ? 'dart.exe' : 'dart',
              );
          process = await Process.start(executable, [
            'run',
            'test/support/routine_kill_worker.dart',
            file.path,
            'upgrade',
            stage,
          ]);
          output = process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                if (line.startsWith('SEEDED ')) {
                  worker =
                      (jsonDecode(line.substring(7)) as Json)['process_id']
                          as int;
                }
                if (line.startsWith('RESULT ')) {
                  result = jsonDecode(line.substring(7)) as Json;
                }
                if (line == 'KILL_BOUNDARY' && !boundary.isCompleted) {
                  boundary.complete();
                }
              }, onDone: stdoutDone.complete);
          errors = process.stderr
              .transform(utf8.decoder)
              .listen(errorText.write, onDone: stderrDone.complete);
          final exit = process.exitCode.then((code) {
            exited = true;
            if (!boundary.isCompleted) {
              boundary.completeError(
                StateError(
                  'Migration worker exited $code before its boundary: $errorText',
                ),
              );
            }
            return code;
          });
          await boundary.future.timeout(const Duration(seconds: 90));
          expect(worker, isNotNull);
          expect(worker, isNot(pid));
          expect(Process.killPid(worker!, ProcessSignal.sigkill), isTrue);
          await exit.timeout(const Duration(seconds: 10));
          await Future.wait([stdoutDone.future, stderrDone.future])
              .timeout(const Duration(seconds: 10));
          final raw = sql.sqlite3.open(file.path);
          try {
            expect(
              raw.select('PRAGMA user_version').single.values.single,
              stage == 'after' ? 7 : 6,
            );
            expect(
              raw.select('PRAGMA integrity_check').single.values.single,
              'ok',
            );
            expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
          } finally {
            raw.close();
          }
          final persisted = frozenRows(file);
          if (stage == 'after') {
            expect(result!['mutations'], hasLength(3));
            persisted
              ..remove('routine_mutations')
              ..remove('routine_sync_state')
              ..remove('routine_cloud_templates');
          }
          expect(persisted, before);
          final retry = TrainingDatabase.open(file);
          final restored = WorkoutRepository(retry, owner);
          try {
            await restored.initialize();
            final mutations = await retry
                .customSelect(
                  'SELECT mutation_id FROM routine_mutations ORDER BY rowid',
                )
                .get();
            expect(mutations, hasLength(3));
            if (stage == 'after') {
              expect(
                mutations
                    .map((row) => row.read<String>('mutation_id'))
                    .toList(),
                result!['mutations'],
              );
            }
            expect(await restored.routines(), hasLength(2));
            expect(
              (await restored.workouts()).map((row) => row['status']),
              containsAll(['active', 'completed']),
            );
          } finally {
            restored.dispose();
            await retry.close();
          }
        } finally {
          if (!exited) {
            if (worker != null && worker != pid) {
              Process.killPid(worker!, ProcessSignal.sigkill);
            }
            process?.kill(ProcessSignal.sigkill);
          }
          await output?.cancel();
          await errors?.cancel();
          await lock.close();
        }
      },
    );
  }

  test('schema 6 keeps every row and frozen workout byte while journaling all immutable versions', () async {
    seedSix();
    final before = frozenRows(file);
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await repo.initialize();
      final rows = await db
          .customSelect(
            'SELECT * FROM routine_mutations WHERE routine_id=\'$routineId\' ORDER BY local_sequence',
          )
          .get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.read<int>('local_sequence')), [1, 2]);
      expect(
        rows.last.read<String>('predecessor_id'),
        rows.first.read<String>('mutation_id'),
      );
      for (final row in rows) {
        expect(
          Uuid.isValidUUID(fromString: row.read<String>('mutation_id')),
          isTrue,
        );
        expect(row.read<String>('state'), 'pending');
        expect(row.readNullable<String>('frozen_body'), isNull);
      }
      final state = await db
          .customSelect(
            'SELECT * FROM routine_sync_state WHERE routine_id=\'$routineId\'',
          )
          .getSingle();
      expect(state.read<int>('server_revision'), 0);
      expect(state.read<int>('local_sequence'), 2);
      expect(state.readNullable<String>('server_shadow'), isNull);
      expect((await repo.routine(routineId))!.localRevision, 3);
      expect(await repo.routines(), hasLength(2));
      expect(
        (await repo.workouts()).map((row) => row['status']),
        containsAll(['active', 'completed']),
      );
    } finally {
      repo.dispose();
      await db.close();
    }
    expect(
      frozenRows(file)
        ..remove('routine_mutations')
        ..remove('routine_sync_state')
        ..remove('routine_cloud_templates'),
      before,
    );
    final reopened = TrainingDatabase.open(file);
    final restored = WorkoutRepository(reopened, owner);
    try {
      await restored.initialize();
      expect(
        await reopened.customSelect('SELECT * FROM routine_mutations').get(),
        hasLength(3),
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

  for (final boundary in [
    'INSERT INTO routine_sync_state',
    'INSERT INTO routine_mutations',
    'PRAGMA user_version=7',
  ]) {
    test(
      'interrupted migration at $boundary rolls back all new state and safely retries',
      () async {
        seedSix();
        final before = frozenRows(file);
        final db = InterruptedJournalDatabase(file, boundary);
        final repo = WorkoutRepository(db, owner);
        try {
          await expectLater(repo.initialize(), throwsA(anything));
        } finally {
          repo.dispose();
          await db.close();
        }
        expect(frozenRows(file), before);
        final raw = sql.sqlite3.open(file.path);
        expect(raw.select('PRAGMA user_version').single.values.single, 6);
        raw.close();
        final retry = TrainingDatabase.open(file);
        final restored = WorkoutRepository(retry, owner);
        try {
          await restored.initialize();
          expect(
            await retry.customSelect('SELECT * FROM routine_mutations').get(),
            hasLength(3),
          );
        } finally {
          restored.dispose();
          await retry.close();
        }
      },
    );
  }

  for (final table in [
    'routine_sync_state',
    'routine_mutations',
    'routine_cloud_templates',
  ]) {
    test(
      'real DDL failure creating $table rolls back the entire upgrade and safely reopens',
      () async {
        seedSix();
        final raw = sql.sqlite3.open(file.path);
        raw.execute('CREATE INDEX $table ON sessions(local_seq)');
        final schemaBefore = raw
            .select(
              'SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY name',
            )
            .map((row) => Map<String, Object?>.from(row))
            .toList();
        raw.close();
        final before = frozenRows(file);
        final failed = TrainingDatabase.open(file);
        final failedRepo = WorkoutRepository(failed, owner);
        try {
          await expectLater(failedRepo.initialize(), throwsA(anything));
        } finally {
          failedRepo.dispose();
          await failed.close();
        }
        expect(frozenRows(file), before);
        final check = sql.sqlite3.open(file.path);
        expect(check.select('PRAGMA user_version').single.values.single, 6);
        expect(
          check
              .select(
                'SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY name',
              )
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
          schemaBefore,
        );
        check.execute('DROP INDEX $table');
        check.close();
        final retry = TrainingDatabase.open(file);
        final restored = WorkoutRepository(retry, owner);
        try {
          await restored.initialize();
          expect(
            await retry.customSelect('SELECT * FROM routine_mutations').get(),
            hasLength(3),
          );
          expect(await restored.routines(), hasLength(2));
        } finally {
          restored.dispose();
          await retry.close();
        }
      },
    );
  }

  test('corrupt old database is refused repeatedly without rebuilding or rewriting its bytes', () async {
    seedSix();
    final corrupted = file.readAsBytesSync();
    corrupted.setRange(0, 16, List.filled(16, 0x58));
    file.writeAsBytesSync(corrupted, flush: true);
    for (var attempt = 0; attempt < 2; attempt++) {
      final failed = TrainingDatabase.open(file);
      final failedRepo = WorkoutRepository(failed, owner);
      try {
        await expectLater(failedRepo.initialize(), throwsA(anything));
      } finally {
        failedRepo.dispose();
        await failed.close();
      }
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsBytesSync(),
        corrupted,
        reason: 'Corruption cannot authorize deleting/recreating an existing owner file.',
      );
    }
  });

  test('offline edits journal once, rollback together on storage failure and purge under disable', () async {
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await repo.initialize();
      final saved = await repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      await repo.saveRoutine(
        id: routineId,
        expectedRevision: 0,
        plan: routinePlan(),
      );
      expect(
        await db.customSelect('SELECT * FROM routine_mutations').get(),
        hasLength(1),
      );
      await db.customStatement(
        "CREATE TRIGGER fail_journal BEFORE INSERT ON routine_mutations BEGIN SELECT RAISE(ABORT,'controlled fault'); END",
      );
      await expectLater(
        repo.saveRoutine(
          id: routineId,
          expectedRevision: 1,
          plan: routinePlan(reps: 9),
        ),
        throwsA(anything),
      );
      expect((await repo.routine(routineId))!.templateId, saved.templateId);
      expect(
        await db.customSelect('SELECT * FROM workout_templates').get(),
        hasLength(1),
      );
      await db.customStatement('DROP TRIGGER fail_journal');
      await repo.saveRoutine(
        id: routineId,
        expectedRevision: 1,
        plan: routinePlan(reps: 9),
      );
      final rows = await db
          .customSelect(
            'SELECT * FROM routine_mutations ORDER BY local_sequence',
          )
          .get();
      expect(rows, hasLength(2));
      expect(
        rows.last.read<String>('predecessor_id'),
        rows.first.read<String>('mutation_id'),
      );
      expect(
        await repo.pendingCount(),
        0,
        reason: 'Routine changes never enter the workout outbox.',
      );
      await repo.signOut();
      await expectLater(
        repo.routine(routineId),
        throwsA(isA<WorkoutValidation>()),
      );
      await repo.unlockVerifiedOwner(owner);
      await repo.disableRemoteAccount();
      expect(
        await db.customSelect('SELECT * FROM routine_mutations').get(),
        isEmpty,
      );
      expect(
        await db.customSelect('SELECT * FROM routine_sync_state').get(),
        isEmpty,
      );
    } finally {
      repo.dispose();
      await db.close();
    }
  });
}
