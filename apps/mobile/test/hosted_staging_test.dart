import 'dart:convert';
import 'dart:io';

import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/coordinator.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload;

/// Opt-in only. Obtain real staging credentials through OTP before invocation.
/// This proves hosted sync/recovery, not delivery or UI/provider sign-out.
void main() {
  final enabled = Platform.environment['DM_HOSTED_SYNC_QUALIFICATION'] == '1';
  test('real staging receipt, RLS namespace and file-backed A to B to A recovery', () async {
    if (!enabled) return;
    final project = Platform.environment['DM_SUPABASE_URL'] ?? '';
    final api = Platform.environment['DM_API_URL'] ?? '';
    final key = Platform.environment['DM_SUPABASE_PUBLISHABLE_KEY'] ?? '';
    final config = AuthConfiguration(
      environment: 'staging',
      supabaseUrl: project,
      apiUrl: api,
      publishableKey: key,
      release: true,
    );
    // Desktop Flutter test process only; never tokens in app bundles/dart-defines.
    final tokenA = Platform.environment['DM_STAGING_TOKEN_A'];
    final tokenB = Platform.environment['DM_STAGING_TOKEN_B'];
    if (tokenA == null || tokenB == null || tokenA.isEmpty || tokenB.isEmpty) {
      throw StateError(
        'Verified staging user credentials must be injected into the test process',
      );
    }
    final transportA = HttpSyncTransport(config.api, () async => tokenA);
    final transportB = HttpSyncTransport(config.api, () async => tokenB);
    LocalOwner? selected;
    SyncCoordinator? coordinator;
    try {
      final accountA = await transportA.initializeAccount();
      final accountB = await transportB.initializeAccount();
      if (accountA.ownerId == accountB.ownerId) {
        throw StateError(
          'Two different verified staging test owners are required',
        );
      }
      final support = await Directory.systemTemp.createTemp(
        'dm-hosted-qualification-',
      );
      final stores = LocalOwnerStores(
        Directory('${support.path}/hosted-qualification/${config.namespace}'),
      );
      selected = await stores.open(accountA.ownerId);
      // Returning to a previously locked fixture requires fresh server verification.
      await selected.repository.initialize();
      final root = await selected.repository.startFoundationWorkout();
      await selected.repository.commit(
        root,
        'record_set',
        recordPayload((await selected.repository.workout(root))!),
      );
      final frozen = (await selected.repository.prepareHead(root))!;
      final body = jsonEncode({
        'schema_version': 1,
        'operations': [jsonDecode(frozen)],
      });
      final first = await transportA.push(body);
      final replay = await transportA.push(body);
      // Accepted response deliberately remains uninstalled until after restart.
      final accepted = first.results.single as Json;
      expect(accepted['status'], 'accepted');
      expect(replay.results.single, {...accepted, 'status': 'duplicate'});
      final metadataA = await selected.repository.syncMetadata();
      await selected.repository.signOut();
      await expectLater(
        selected.repository.workout(root),
        throwsA(isA<WorkoutValidation>()),
      );
      await selected.close();
      selected = null;
      selected = await stores.open(accountB.ownerId);
      await selected.repository.initialize();
      expect(await selected.repository.workout(root), null);
      expect(
        (await selected.repository.syncMetadata())['installation_id'],
        isNot(metadataA['installation_id']),
      );
      final pageB = await transportB.pull(null);
      expect(
        pageB.changes.any((page) => canonicalJson(page).contains(root)),
        false,
      );
      await selected.repository.signOut();
      await selected.close();
      selected = null;
      selected = await stores.open(accountA.ownerId, existing: true);
      final verifiedAgain = await transportA.initializeAccount();
      await selected.repository.unlockVerifiedOwner(verifiedAgain.ownerId);
      await selected.repository.initialize();
      expect(await selected.repository.prepareHead(root), frozen);
      coordinator = SyncCoordinator(selected.repository, transportA);
      await coordinator.synchronize(force: true);
      expect(coordinator.status.phase, SyncPhase.synchronized);
      expect((await selected.repository.workout(root))!['aggregate_id'], root);
      expect(
        allSets((await selected.repository.workout(root))!)
            .first['observation']['actual']['reps'],
        5,
      );
      expect(await selected.repository.pendingRoots(), isEmpty);
      // Fixture data remains private and durable for later restart examination.
    } finally {
      await coordinator?.close();
      await selected?.close();
      transportA.close();
      transportB.close();
    }
  }, skip: !enabled);
}
