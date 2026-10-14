import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload;
import 'support/sync_server.dart' show testOwner;

class CountReads extends QueryInterceptor {
  int reads = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    reads++;
    return executor.runSelect(statement, args);
  }
}

void main() {
  test('real file history preserves projections and bounds read round trips across 100 roots', () async {
    final directory = await Directory.systemTemp.createTemp('history-reads-');
    final counter = CountReads();
    final db = TrainingDatabase(
      NativeDatabase.createInBackground(
        File('${directory.path}/training.sqlite'),
        setup: (sqlite) => sqlite.execute(
          'PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;',
        ),
      ).interceptWith(counter),
    );
    final repo = WorkoutRepository(db, testOwner);
    try {
      await repo.initialize();
      final ids = <String>[];
      for (var i = 0; i < 100; i++) {
        final String id;
        if (i == 99) {
          id = repo.newId();
          final base =
              ((await repo.workout(ids.first))!['exercises'] as List).first
                  as Json;
          await repo.commit(id, 'create_session', {
            'name': 'Multi-exercise fixture',
            'timezone': 'Asia/Kolkata',
            'exercises': [
              for (var j = 0; j < 2; j++)
                {
                  ...base,
                  'session_exercise_id': repo.newId(),
                  'sets': [
                    for (final raw in base['sets'] as List)
                      (Map<String, dynamic>.from(raw as Json)
                          ..remove('observation'))
                        ..['set_id'] = repo.newId(),
                  ],
                },
            ],
          });
        } else {
          id = await repo.startFoundationWorkout();
        }
        ids.add(id);
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!),
        );
        await repo.commit(
          id,
          i.isEven ? 'complete_session' : 'abandon_session',
          {},
        );
      }
      final expected = [
        for (final id in ids.reversed) (await repo.workout(id))!,
      ];
      counter.reads = 0;
      expect(await repo.workouts(), expected);
      expect(
        counter.reads,
        lessThan(20),
        reason: 'History must not issue a query series for every root',
      );
      expect(await repo.pendingCount(), 300);
      counter.reads = 0;
      final active = await repo.startFoundationWorkout();
      expect(
        counter.reads,
        lessThan(30),
        reason: 'Active-session guard must not load every exercise/set',
      );
      await expectLater(
        repo.startFoundationWorkout(),
        throwsA(isA<WorkoutValidation>()),
      );
      final root = (await repo.workout(active))!;
      final frozen = await repo.prepareHead(active);
      await repo.signOut();
      await expectLater(repo.workouts(), throwsA(isA<WorkoutValidation>()));
      await repo.unlockVerifiedOwner(testOwner);
      expect((await repo.workouts()).first, root);
      expect(await repo.prepareHead(active), frozen);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
