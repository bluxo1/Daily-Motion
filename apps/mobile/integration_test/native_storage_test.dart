import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/platform/device_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../test/repository_test.dart' show recordPayload;
import '../test/support/sync_server.dart' show testOwner;
import '../test/support/auth_fakes.dart' show testSession;

/// Dedicated synthetic test entrypoint, never the production main.dart.
/// `seed`, hard-kill externally, then `recover` (same application ID/signature).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment(
    'DM_NATIVE_STAGE',
    defaultValue: 'smoke',
  );
  testWidgets('native protected storage and durable local recovery ($stage)', (
    tester,
  ) async {
    expect({'smoke', 'seed', 'recover', 'cleanup'}, contains(stage));
    final information = await const DeviceServices().information();
    final support = await getApplicationSupportDirectory();
    await DeviceServices.prepareStorage(support);
    final directory = Directory(
      path.join(support.path, 'native-qualification'),
    );
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, 'training.sqlite'));
    final protected = PlatformProtectedStorage();
    final sessions = SecureSessionStorage(protected, 'native-qualification');
    const probe = 'dm.native-qualification.synthetic-probe';
    if (stage == 'cleanup') {
      await protected.delete(probe);
      await sessions.removePersistedSession();
      if (await directory.exists()) await directory.delete(recursive: true);
      binding.reportData = {
        'device': information,
        'stage': stage,
        'synthetic_only': true,
      };
      return;
    }
    if (stage == 'recover') {
      expect(
        await file.exists(),
        true,
        reason: 'No silently recreated recovery database',
      );
    }
    var database = TrainingDatabase.open(file);
    var repo = WorkoutRepository(
      database,
      testOwner,
      restClock: const DeviceServices(),
    );
    try {
      await repo.initialize();
      var workouts = await repo.workouts();
      if (stage != 'recover' && workouts.isEmpty) {
        final id = await repo.startFoundationWorkout();
        await repo.commit(
          id,
          'record_set',
          recordPayload((await repo.workout(id))!),
        );
        final next =
            allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
        await repo.saveDraft(next, {'reps': '7', 'load': '60'});
        final frozen = (await repo.prepareHead(id))!;
        await protected.write(
          probe,
          sha256.convert(utf8.encode(frozen)).toString(),
        );
        await sessions.saveSession(
          testSession(testOwner, DateTime.now().toUtc()),
        );
        workouts = await repo.workouts();
      }
      expect(workouts, hasLength(1));
      final id = workouts.single['aggregate_id'] as String;
      final frozen = await repo.prepareHead(id);
      await database.close();
      database = TrainingDatabase.open(file);
      repo = WorkoutRepository(
        database,
        testOwner,
        restClock: const DeviceServices(),
      );
      await repo.initialize();
      expect(await repo.prepareHead(id), frozen);
      expect(await repo.pendingCount(), 2);
      final sets = allSets((await repo.workout(id))!).toList();
      expect(sets.first['observation']['actual']['reps'], 5);
      expect(await repo.draft(sets[1]['set_id'] as String), {
        'reps': '7',
        'load': '60',
      });
      expect(
        await protected.read(probe),
        sha256.convert(utf8.encode(frozen!)).toString(),
      );
      expect(await repo.restDisplay(id), isNotNull);
      expect((await sessions.restoreSession())!.user.id, testOwner);
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      binding.reportData = {
        'device': information,
        'stage': stage,
        'synthetic_only': true,
        'sqlite_integrity': 'ok',
        'outbox_count': 2,
        'secure_probe_restored': true,
        'synthetic_session_restored': true,
        'draft_restored': true,
        'same_process_reopen': true,
        'previous_installation_state_required': stage == 'recover',
        'external_kill_must_be_recorded_separately': true,
      };
    } finally {
      await database.close();
    }
  });
}
