import 'dart:io';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/features/workout_controller.dart';
import 'package:daily_motion/platform/device_services.dart';
import 'package:daily_motion/qualification/durable_benchmark.dart';
import 'package:daily_motion/qualification/native_installation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../test/repository_test.dart' show recordPayload;
import '../test/support/sync_server.dart' show testOwner;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('full durable set acknowledgement on native SQLite', (
    tester,
  ) async {
    final device = await const DeviceServices().information();
    requireQualificationInstallation(device);
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    final benchmark = DurableBenchmark(device, mode);
    final support = await getApplicationSupportDirectory();
    await DeviceServices.prepareStorage(support);
    final parent = await Directory(
      path.join(support.path, 'benchmark-qualification'),
    ).create(recursive: true);
    final directory = await parent.createTemp('run-');
    final database = TrainingDatabase.open(
      File(path.join(directory.path, 'training.sqlite')),
    );
    final repo = WorkoutRepository(
      database,
      testOwner,
      restClock: const DeviceServices(),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final warmupSamples = <int>[];
    var completed = false;
    var historyRoots = 0;
    try {
      await repo.initialize();
      // Fixed declared history and warmups, not discarded inconvenient samples.
      for (var i = 0; i < 100; i++) {
        final id = await repo.startFoundationWorkout();
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!),
        );
        await repo.commit(id, 'complete_session', {});
        historyRoots++;
      }
      await container.read(workoutsProvider.future);
      final controller = container.read(workoutsProvider.notifier);
      var id = '';
      for (var i = 0; i < 232; i++) {
        if (i % 3 == 0) id = await controller.start();
        final root = (await repo.workout(id))!;
        final exercise = (root['exercises'] as List).first as Json;
        final item = allSets(root).elementAt(i % 3);
        final watch = Stopwatch()..start();
        var acknowledged = false;
        try {
          acknowledged = await controller.record(id, exercise, item, {
            'load': '60',
            'reps': '5',
            'effort': '',
            'effort_scale': 'rir',
            'unit': 'kg',
            'execution_status': 'completed',
          });
        } finally {
          watch.stop();
          if (i < 32) {
            warmupSamples.add(watch.elapsedMicroseconds);
            if (!acknowledged) {
              benchmark.record(watch.elapsed, acknowledged: false);
            }
            expect(acknowledged, true);
          } else {
            benchmark.record(watch.elapsed, acknowledged: acknowledged);
          }
        }
        expect(acknowledged, true);
        expect(container.read(workoutsProvider).hasError, false);
        if (i % 3 == 2) await controller.finish(id);
      }
      completed = true;
    } finally {
      try {
        container.dispose();
        repo.dispose();
        await database.close();
        await directory.delete(recursive: true);
      } catch (_) {
        completed = false;
        rethrow;
      } finally {
        binding.reportData = {
          ...benchmark.report(
            warmups: warmupSamples.length,
            historyRoots: historyRoots,
            scenario: 'offline_repository_no_provider',
            buildRevision: const String.fromEnvironment(
              'DM_BUILD_REVISION',
              defaultValue: 'unrecorded',
            ),
            completed: completed,
          ),
          'warmup_samples_us': warmupSamples,
          'synthetic_only': true,
          'same_process': true,
          'revision': const String.fromEnvironment(
            'DM_BUILD_REVISION',
            defaultValue: 'unrecorded',
          ),
        };
      }
    }
    expect(benchmark.failures, 0);
    expect(binding.reportData!['sample_count'], 200);
    // Debug/emulator runs can verify mechanics, never pass the phone latency gate.
    if (device['physical'] == true && mode != 'debug') {
      expect(binding.reportData!['target_met'], true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
