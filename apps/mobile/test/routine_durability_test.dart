import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/routine.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'repository_test.dart' show owner;
import 'support/owned_fixture.dart';

void main() {
  for (final action in ['edit', 'start']) {
    for (final stage in ['before', 'during', 'after']) {
      test(
        'hard process kill $stage routine $action preserves exactly one atomic outcome',
        () async {
          // Same lock as the existing Phase 0 worker harness. Native assets must
          // not be rewritten while another dart-run VM holds the SQLite DLL.
          final lock = await File(
            path.join('.dart_tool', 'process-kill-worker.lock'),
          ).open(mode: FileMode.append);
          try {
            await lock.lock(FileLock.blockingExclusive);
            await killRoutineWorker(action, stage);
          } finally {
            await lock.close();
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}

Future<void> killRoutineWorker(String action, String stage) async {
  final directory = await Directory.systemTemp.createTemp('routine-kill-');
  final file = File(path.join(directory.path, 'routine.sqlite'));
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      path.join(Directory.current.parent.parent.path, '.tools', 'flutter');
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
  final process = await Process.start(executable, [
    'run',
    'test/support/routine_kill_worker.dart',
    file.path,
    action,
    stage,
  ]);
  final boundary = Completer<void>();
  final outputClosed = Completer<void>();
  final errorsClosed = Completer<void>();
  Json? seeded;
  Json? result;
  var passed = false;
  var terminated = false;
  var launcherExited = false;
  final errors = <String>[];
  final output = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.startsWith('SEEDED ')) {
          seeded = jsonDecode(line.substring(7)) as Json;
        }
        if (line.startsWith('RESULT ')) {
          result = jsonDecode(line.substring(7)) as Json;
        }
        if (line == 'KILL_BOUNDARY' && !boundary.isCompleted) {
          boundary.complete();
        }
      }, onDone: outputClosed.complete);
  final errorSubscription = process.stderr
      .transform(utf8.decoder)
      .listen(errors.add, onDone: errorsClosed.complete);
  unawaited(
    process.exitCode.then((code) {
      launcherExited = true;
      if (!boundary.isCompleted) {
        boundary.completeError(
          StateError(
            'Routine worker exited $code before boundary: ${errors.join()}',
          ),
        );
      }
    }),
  );
  try {
    await boundary.future.timeout(const Duration(seconds: 90));
    expect(seeded, isNotNull);
    final worker = seeded!['process_id'] as int;
    expect(worker, isNot(pid));
    terminated = Process.killPid(worker, ProcessSignal.sigkill);
    expect(terminated, true);
    await process.exitCode.timeout(const Duration(seconds: 10));
    await Future.wait([outputClosed.future, errorsClosed.future])
        .timeout(const Duration(seconds: 10));
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, owner);
    try {
      await repo.initialize();
      await db.customStatement(
        'DROP TRIGGER IF EXISTS routine_qualification_stop',
      );
      final saved = (await repo.routine(seeded!['routine'] as String))!;
      Future<int> count(String table) async =>
          (await db
                  .customSelect('SELECT count(*) AS n FROM $table')
                  .getSingle())
              .read<int>('n');
      if (action == 'edit') {
        expect(saved.localRevision, stage == 'after' ? 2 : 1);
        expect(
          saved.plan.name,
          stage == 'after' ? 'Updated routine' : 'Initial routine',
        );
        expect(await count('workout_templates'), stage == 'after' ? 2 : 1);
        expect(await repo.workouts(), isEmpty);
        expect(await repo.pendingCount(), 0);
        final next = copyJson(seeded!['plan'] as Json)
          ..['name'] = 'Updated routine';
        next['exercises'][0]['sets'][0]['planned']['reps'] = 7;
        await repo.saveRoutine(
          id: saved.id,
          expectedRevision: 1,
          plan: RoutinePlan.fromJson(next),
        );
        expect(
          await count('workout_templates'),
          2,
          reason: 'Retry must not publish a duplicate template after response loss.',
        );
      } else {
        for (final table in ['sessions', 'outbox', 'routine_starts']) {
          expect(await count(table), stage == 'after' ? 1 : 0, reason: table);
        }
        final id = await repo.startRoutine(
          routineId: saved.id,
          templateId: saved.templateId,
          attemptId: seeded!['attempt'] as String,
          timezone: 'Asia/Kolkata',
        );
        expect(
          await repo.startRoutine(
            routineId: saved.id,
            templateId: saved.templateId,
            attemptId: seeded!['attempt'] as String,
            timezone: 'Asia/Kolkata',
          ),
          id,
        );
        expect(await count('sessions'), 1);
        expect(await count('outbox'), 1);
        expect(await count('routine_starts'), 1);
        expect(
          allSets((await repo.workout(id))!)
              .every((s) => s['observation'] == null),
          true,
        );
        if (stage == 'after') {
          expect(id, result!['session']);
          expect(await repo.prepareHead(id), result!['frozen']);
        }
      }
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      passed = true;
    } finally {
      repo.dispose();
      await db.close();
    }
  } finally {
    if (!terminated) {
      if (seeded?['process_id'] case final int worker) {
        Process.killPid(worker, ProcessSignal.sigkill);
      }
    }
    if (!launcherExited) process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 10));
    await output.cancel();
    await errorSubscription.cancel();
    if (passed) {
      await deleteOwnedTemporaryDirectory(directory, 'routine-kill-');
    } else {
      // Retain the owned failed fixture for diagnosis, rather than destroying
      // the only database demonstrating an unexpected crash outcome.
      stderr.writeln('Preserved routine fault fixture: ${directory.path}');
    }
  }
}
