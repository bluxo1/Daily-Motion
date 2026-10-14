import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

const owner = '20000000-0000-4000-8000-000000000001';
Map<String, dynamic> entry(Json root, int index) {
  final exercise = (root['exercises'] as List).first as Json;
  final item = allSets(root).elementAt(index);
  return {
    'session_exercise_id': exercise['session_exercise_id'],
    'set_id': item['set_id'],
    'execution_status': 'completed',
    'actual': {
      'load': {'value': '60', 'unit': 'kg', 'basis': 'total_external'},
      'reps': 5,
      'rep_convention': 'bilateral',
      'effort': null,
    },
    'completion_seq': index + 1,
    'order_source': 'logged',
  };
}

/// Separate OS process, real repository/SQLite WAL FULL. No graceful close at fault.
Future<void> main(List<String> args) async {
  final file = File(args[0]);
  final stage = args[1];
  final db = TrainingDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute(
          'PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;',
        );
        database.createFunction(
          functionName: 'qualification_pause',
          argumentCount: const AllowedArgumentCount(0),
          directOnly: false, // Test-only pause used by our controlled trigger.
          function: (_) {
            stdout.writeln('KILL_BOUNDARY');
            stdin.readLineSync(); // Parent kills the whole OS process; never releases this wait.
            return 0;
          },
        );
      },
    ),
  );
  final repo = WorkoutRepository(db, owner);
  await repo.initialize();
  final id = await repo.startFoundationWorkout();
  await repo.commit(id, 'record_set', entry((await repo.workout(id))!, 0));
  final set =
      allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
  await repo.saveDraft(set, {'reps': '7'});
  final frozen = await repo.prepareHead(id);
  stdout.writeln(
    'SEEDED ${jsonEncode({'id': id, 'set': set, 'frozen': frozen})}',
  );
  if (stage == 'during_commit') {
    await db.customStatement(
      'CREATE TRIGGER qualification_stop BEFORE INSERT ON outbox BEGIN SELECT qualification_pause(); END',
    );
    await repo.commit(id, 'record_set', entry((await repo.workout(id))!, 1));
  } else if (stage == 'after_commit') {
    await repo.commit(id, 'record_set', entry((await repo.workout(id))!, 1));
    stdout.writeln('KILL_BOUNDARY');
    stdin.readLineSync();
  } else {
    stdout.writeln('KILL_BOUNDARY');
    stdin.readLineSync();
  }
  throw StateError('Fault worker unexpectedly resumed');
}
