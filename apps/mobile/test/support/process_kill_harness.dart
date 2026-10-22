import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'sync_server.dart' show testOwner;

/// Actual OS kill and file-backed restart assertions shared by defensive cases.
Future<void> assertHardKillRecovery({
  required String protocol,
  required String stage,
}) async {
  // dart run bundles native assets into the package's shared .dart_tool/lib.
  // Concurrent test-file processes must not copy/rewrite the same asset while
  // another launcher inspects it (macOS) or a worker has its DLL open (Windows).
  // Serialize on every platform through the actual kill/exit and database close;
  // closing the handle releases the lock even when a worker or assertion fails.
  final lock = await File(
    path.join(Directory.current.path, '.dart_tool', 'process-kill-worker.lock'),
  ).open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    await _assertHardKillRecovery(protocol: protocol, stage: stage);
  } finally {
    await lock.close();
  }
}

Future<void> _assertHardKillRecovery({
  required String protocol,
  required String stage,
}) async {
  final directory = await Directory.systemTemp.createTemp('os-kill-');
  final file = File(path.join(directory.path, 'training.sqlite'));
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
    'test/support/kill_worker.dart',
    file.path,
    stage,
    protocol,
  ]);
  final boundary = Completer<void>();
  final stdoutClosed = Completer<void>();
  final stderrClosed = Completer<void>();
  Map<String, dynamic>? seeded;
  var terminated = false;
  var launcherExited = false;
  final errors = <String>[];
  final stdout = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.startsWith('SEEDED ')) {
          seeded = jsonDecode(line.substring(7)) as Map<String, dynamic>;
        }
        if (line == 'KILL_BOUNDARY' && !boundary.isCompleted) {
          boundary.complete();
        }
      }, onDone: stdoutClosed.complete);
  final stderr = process.stderr
      .transform(utf8.decoder)
      .listen(errors.add, onDone: stderrClosed.complete);
  unawaited(
    process.exitCode.then((code) {
      launcherExited = true;
      if (!boundary.isCompleted) {
        boundary.completeError(
          StateError('Worker exited $code before boundary: ${errors.join()}'),
        );
      }
    }),
  );
  try {
    await boundary.future.timeout(const Duration(seconds: 90));
    expect(seeded, isNotNull);
    // `dart run` can launch a separate VM. Kill the process holding SQLite,
    // then drain its inherited pipes before reopening the database.
    final workerPid = seeded!['process_id'] as int;
    terminated = Process.killPid(workerPid, ProcessSignal.sigkill);
    expect(terminated, true);
    await process.exitCode.timeout(const Duration(seconds: 10));
    await Future.wait([stdoutClosed.future, stderrClosed.future])
        .timeout(const Duration(seconds: 10));
    final db = TrainingDatabase.open(file);
    final repo = WorkoutRepository(db, testOwner);
    try {
      await repo.initialize();
      await db.customStatement('DROP TRIGGER IF EXISTS qualification_stop');
      final root = (await repo.workout(seeded!['id'] as String))!;
      expect(root['local_seq'], stage == 'after_commit' ? 3 : 2);
      final head = await db
          .customSelect('SELECT * FROM outbox ORDER BY local_seq LIMIT 1')
          .getSingle();
      expect(head.read<String>('operation'), seeded!['frozen']);
      expect(
        head.readNullable<String>('frozen_body'),
        stage == 'during_freeze' ? null : seeded!['frozen'],
      );
      expect(
        allSets(root).where((s) => s['observation'] != null).length,
        stage == 'after_commit' ? 2 : 1,
      );
      expect(await repo.pendingCount(), stage == 'after_commit' ? 3 : 2);
      if (protocol == 'v2') {
        final context = (await repo.recoveryContext())!;
        final origins = await db
            .customSelect('SELECT wire_version,origin_context FROM outbox')
            .get();
        expect(
          origins.every(
            (row) =>
                row.read<int>('wire_version') == 2 &&
                row.read<String>('origin_context') ==
                    canonicalJson(context.origin),
          ),
          true,
        );
      }
      expect(
        await repo.prepareHead(seeded!['id'] as String),
        seeded!['frozen'],
      );
      expect(
        await repo.draft(seeded!['set'] as String),
        stage == 'after_commit' ? null : {'reps': '7'},
      );
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
  } finally {
    if (!terminated) {
      if (seeded?['process_id'] case final int workerPid) {
        Process.killPid(workerPid, ProcessSignal.sigkill);
      }
    }
    if (!launcherExited) process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 10));
    await stdout.cancel();
    await stderr.cancel();
    await directory.delete(recursive: true);
  }
}
