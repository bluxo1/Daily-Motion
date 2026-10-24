import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Test-owned process and database only. Parent terminates the VM at a real
/// SQLite boundary, without graceful repository/database disposal.
Future<void> main(List<String> args) async {
  final file = File(args[0]);
  final action = args[1];
  final stage = args[2];
  if (!['edit', 'start'].contains(action) ||
      !['before', 'during', 'after'].contains(stage)) {
    throw ArgumentError('Unknown routine fault boundary');
  }
  final db = TrainingDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (sqlite) {
        sqlite.execute(
          'PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;',
        );
        sqlite.createFunction(
          functionName: 'routine_qualification_pause',
          argumentCount: const AllowedArgumentCount(0),
          directOnly: false,
          function: (_) {
            stdout.writeln('KILL_BOUNDARY');
            stdin.readLineSync();
            return 0;
          },
        );
      },
    ),
  );
  final repo = WorkoutRepository(db, '20000000-0000-4000-8000-000000000001');
  await repo.initialize();
  final payload =
      (jsonDecode(
            File('../../contracts/fixtures/workout.json').readAsStringSync(),
          ) as Json)['payload']
          as Json;
  payload['name'] = 'Initial routine';
  final initial = await repo.saveRoutine(
    id: '60000000-0000-4000-8000-000000000001',
    expectedRevision: 0,
    plan: RoutinePlan.fromJson(payload),
  );
  const attempt = '70000000-0000-4000-8000-000000000001';
  stdout.writeln(
    'SEEDED ${jsonEncode({'process_id': pid, 'routine': initial.id, 'template': initial.templateId, 'plan': initial.plan.json, 'attempt': attempt})}',
  );
  if (stage == 'during') {
    final target = action == 'edit'
        ? 'UPDATE OF current_template_id ON routines'
        : 'INSERT ON routine_starts';
    await db.customStatement(
      'CREATE TRIGGER routine_qualification_stop BEFORE $target BEGIN SELECT routine_qualification_pause(); END',
    );
  }
  if (stage != 'before') {
    if (action == 'edit') {
      final next = initial.plan.json..['name'] = 'Updated routine';
      next['exercises'][0]['sets'][0]['planned']['reps'] = 7;
      await repo.saveRoutine(
        id: initial.id,
        expectedRevision: 1,
        plan: RoutinePlan.fromJson(next),
      );
    } else {
      final id = await repo.startRoutine(
        routineId: initial.id,
        templateId: initial.templateId,
        attemptId: attempt,
        timezone: 'Asia/Kolkata',
      );
      stdout.writeln(
        'RESULT ${jsonEncode({'session': id, 'frozen': await repo.prepareHead(id)})}',
      );
    }
  }
  stdout.writeln('KILL_BOUNDARY');
  await stdout.flush();
  stdin.readLineSync();
  throw StateError('Controlled routine worker unexpectedly resumed');
}
