import 'dart:async';
import 'dart:math';

import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'contract_validation.dart';
import 'transport.dart';
import 'batch.dart';
import 'transport_contract.dart';

enum SyncPhase {
  savedLocally,
  pending,
  syncing,
  synchronized,
  attention,
  authenticationRequired,
  accountDisabled,
}

class SyncStatus {
  final SyncPhase phase;
  final String? code;
  const SyncStatus(this.phase, [this.code]);

  String? get cloudInterruptionLabel => switch (code) {
    'upgrade_required' => 'App update required to sync',
    'routine_sync_unavailable' => 'Cloud sync capability unavailable',
    'recovery_unavailable' ||
    'recovery_metadata_unverified' ||
    'publication_pending' ||
    'timeline_reconciliation_required' => 'Cloud recovery needs attention',
    _
        when phase == SyncPhase.pending &&
            (['offline', 'timeout', 'connection_dropped'].contains(code) ||
                RegExp(r'^http_(429|5[0-9]{2})$').hasMatch(code ?? '')) =>
      'Cloud sync temporarily unavailable',
    _ => null,
  };

  String? get cloudInterruptionExplanation => switch (code) {
    'upgrade_required' => 'Update to a compatible app to resume cloud synchronization. Your saved work stays on this device.',
    'routine_sync_unavailable' => 'Routine cloud synchronization is unavailable on this server or in this build. Your saved work stays on this device.',
    'recovery_unavailable' ||
    'recovery_metadata_unverified' ||
    'publication_pending' ||
    'timeline_reconciliation_required' => 'Cloud synchronization is paused while the service is checked. You can continue training on this device.',
    _ when cloudInterruptionLabel != null => 'Your saved work is retained. Retry when the cloud connection is available.',
    _ => null,
  };

  String get label {
    final interruption = cloudInterruptionLabel;
    if (interruption != null &&
        phase != SyncPhase.accountDisabled &&
        phase != SyncPhase.authenticationRequired) {
      return 'Saved on this device · ${interruption.toLowerCase()}';
    }
    return switch (phase) {
      SyncPhase.savedLocally => 'Saved on this device',
      SyncPhase.pending => 'Saved on this device · pending sync',
      SyncPhase.syncing => 'Saved on this device · syncing',
      SyncPhase.synchronized => 'Synchronized',
      SyncPhase.attention => 'Saved on this device · sync needs attention',
      SyncPhase.authenticationRequired =>
        'Saved on this device · sign in to sync',
      SyncPhase.accountDisabled => 'Account disabled remotely',
    };
  }
}

/// Single foreground runner. Durable retry metadata survives process restarts;
/// local commits schedule it asynchronously, without awaiting any HTTP work.
class SyncCoordinator {
  final WorkoutRepository repository;
  final SyncTransport transport;
  final DateTime Function() now;
  final double Function() jitter;
  final Future<void> Function()? onInstalled;
  final _statuses = StreamController<SyncStatus>.broadcast();
  final _installations = StreamController<void>.broadcast();
  Stream<void> get installations => _installations.stream;
  Stream<SyncStatus> get statuses => _statuses.stream;
  SyncStatus status = const SyncStatus(SyncPhase.savedLocally);
  StreamSubscription<void>? _commits;
  Timer? _retry;
  Future<void>? _running;
  bool _foreground = true;
  bool _closed = false;
  bool _again = false;
  bool _authorized = true;
  bool _forceNext = false;
  SyncTransport? _cycle;
  SyncTransport get connection => _cycle ?? transport;
  RoutineSyncTransport? get routineConnection {
    final candidate = connection;
    if (candidate case final RoutineSyncTransport channel) {
      return channel.routineSyncEnabled ? channel : null;
    }
    return null;
  }

  SyncCoordinator(
    this.repository,
    this.transport, {
    DateTime Function()? clock,
    double Function()? jitter,
    this.onInstalled,
  }) : now = clock ?? DateTime.now,
       jitter = jitter ?? Random().nextDouble;

  void _status(SyncPhase phase, [String? code]) {
    status = SyncStatus(phase, code);
    if (!_closed) _statuses.add(status);
  }

  Future<void> _notifyInstalled() async {
    if (!_closed) _installations.add(null);
    await onInstalled?.call();
  }

  void start() {
    _commits ??= repository.commits.listen((_) {
      _again = true;
      unawaited(synchronize());
    });
    unawaited(synchronize());
  }

  void foreground(bool enabled) {
    _foreground = enabled;
    if (enabled) {
      unawaited(synchronize());
    } else {
      _retry?.cancel();
    }
  }

  void cloudAuthorization(bool available) {
    _authorized = available;
    if (available) _forceNext = true;
    if (!available) {
      _retry?.cancel();
      _status(SyncPhase.authenticationRequired, 'authentication_required');
    } else if (!_closed && _foreground) {
      unawaited(synchronize(force: true));
    }
  }

  Future<void> synchronize({bool force = false}) {
    if (_closed || !_foreground) return Future.value();
    if (!_authorized) return Future.value();
    if (_running != null) {
      final current = _running!;
      // A fresh credential must not be swallowed by a running paused/old-token
      // cycle. Its bounded follow-up uses the original frozen pending requests.
      return force ? current.then((_) => synchronize(force: true)) : current;
    }
    force = force || _forceNext;
    _forceNext = false;
    _again = false;
    final work = _run(force);
    _running = work;
    return work.whenComplete(() {
      _running = null;
      if (_again && !_closed && _foreground) {
        _again = false;
        unawaited(synchronize());
      }
    });
  }

  Future<void> _run(bool force) async {
    _retry?.cancel();
    try {
      if (await repository.remoteDisabled()) {
        _status(SyncPhase.accountDisabled, 'account_inactive');
        return;
      }
      var meta = await repository.syncMetadata();
      if (!force && meta['next_attempt'] != null) {
        final delay = DateTime.parse(meta['next_attempt'] as String)
            .difference(now());
        if (delay > Duration.zero) {
          _status(SyncPhase.pending, meta['last_error'] as String?);
          _schedule(delay);
          return;
        }
      }
      if (!force &&
          [
            'authentication_required',
            'invalid_credentials',
            'upgrade_required',
            'routine_sync_unavailable',
            'wrong_owner',
            'malformed_response',
            'snapshot_checksum',
            'timeline_reconciliation_required',
          ].contains(meta['last_error'])) {
        _status(
          [
                'authentication_required',
                'invalid_credentials',
              ].contains(meta['last_error'])
              ? SyncPhase.authenticationRequired
              : SyncPhase.attention,
          meta['last_error'] as String,
        );
        return;
      }
      _status(SyncPhase.syncing);
      _cycle = await transport.beginCycle();
      final routineChannel = routineConnection;
      // A validated context-only view for common lifecycle fields. Requests,
      // receipts and staged snapshots retain their original contract and bytes.
      final identity = routineChannel == null
          ? await connection.me()
          : MeResponseDto.fromJson({
              ...(await routineChannel.routineMe()).json,
              'schema_version': 1,
            });
      if (identity.ownerId != repository.ownerId) {
        throw const ContractViolation('wrong_owner');
      }
      if (_closed || !_foreground || !_authorized) {
        _status(
          !_authorized ? SyncPhase.authenticationRequired : SyncPhase.pending,
        );
        return;
      }
      if ([
            'bootstrap_required',
            'snapshot_expired',
            'snapshot_invalidated',
            'stale_page',
          ].contains(meta['last_error']) ||
          meta['generation'] == null ||
          meta['generation'] != identity.generation ||
          meta['erasure_epoch'] != identity.erasureEpoch ||
          (meta['position'] as int) < identity.minimumPosition) {
        if (routineChannel == null) {
          await _bootstrap();
        } else {
          await _bootstrapRoutines(routineChannel);
        }
      }
      if (!_foreground || _closed || !_authorized) {
        _status(
          !_authorized ? SyncPhase.authenticationRequired : SyncPhase.pending,
        );
        return;
      }
      await _pull(); // Account erasure/remote state is processed before queued uploads.
      for (var round = 0; round < 50 && _foreground && _authorized; round++) {
        final roots = await repository.pendingRoots();
        final heads = <String>[];
        for (final root in roots) {
          final body = await repository.prepareHead(root);
          if (body != null) heads.add(body);
        }
        if (routineChannel != null) {
          for (final root in await repository.pendingRoutineRoots()) {
            final body = await repository.prepareRoutineHead(root);
            if (body != null) heads.add(body);
          }
        }
        final batch = packFrozenHeads(
          heads,
          schemaVersion: routineChannel == null ? 1 : 3,
        );
        for (final mutation in batch.oversized) {
          if (routineChannel == null) {
            await repository.markOversized(mutation);
          } else {
            await repository.markMixedOversized(mutation);
          }
        }
        if (batch.operations.isEmpty) break;
        if (_closed || !_foreground || !_authorized) return;
        if (routineChannel == null) {
          await repository.markAttempts(batch.mutations);
        } else {
          await repository.markMixedAttempts(batch.mutations);
        }
        if (_closed || !_foreground || !_authorized) return;
        if (routineChannel == null) {
          final response = await connection.push(batch.body);
          await repository.installAcknowledgements(response, batch.mutations);
        } else {
          final response = await routineChannel.pushRoutines(batch.body);
          await repository.installRoutineAcknowledgements(
            response,
            batch.mutations,
          );
        }
        await _notifyInstalled();
        await _pull();
        if (round == 49) _again = true;
      }
      await _pull();
      await repository.clearSyncFailure();
      _status(
        !_authorized
            ? SyncPhase.authenticationRequired
            : _again || !_foreground
            ? SyncPhase.pending
            : await repository.attentionCount() > 0 ||
                  routineChannel != null &&
                      await repository.routineAttentionCount() > 0
            ? SyncPhase.attention
            : await repository.pendingCount() > 0 ||
                  routineChannel != null &&
                      await repository.routinePendingCount() > 0
            ? SyncPhase.pending
            : SyncPhase.synchronized,
      );
    } catch (error) {
      final code = error is SyncFailure
          ? error.code
          : error is ContractViolation
          ? error.code
          : 'local_sync_failure';
      if (code == 'account_inactive' &&
          error is SyncFailure &&
          error.ownerId == repository.ownerId) {
        await repository.disableRemoteAccount();
        _status(SyncPhase.accountDisabled, code);
        await _notifyInstalled();
        return;
      }
      if (code == 'account_inactive') {
        await repository.recordSyncFailure('wrong_owner');
        _status(SyncPhase.attention, 'wrong_owner');
        return;
      }
      if (code == 'snapshot_checksum') await repository.discardBootstrap();
      if ([
        'bootstrap_required',
        'snapshot_expired',
        'snapshot_invalidated',
        'stale_page',
      ].contains(code)) {
        await repository.discardBootstrap();
        await repository.recordSyncFailure(code, nextAttempt: now());
        // Recovery occurs on the next bounded turn; malformed data never resets usable state.
        _status(SyncPhase.pending, code);
        _schedule(const Duration(milliseconds: 250));
        return;
      }
      if (error is WorkoutValidation) {
        _status(
          SyncPhase.attention,
          await repository.remoteDisabled()
              ? 'account_inactive'
              : 'local_or_domain_validation',
        );
        return;
      }
      final transient = error is SyncFailure && error.retryable;
      final meta = await repository.syncMetadata();
      final attempt = (meta['retry_attempt'] as int).clamp(0, 6);
      final seconds = min(60, pow(2, attempt).toInt());
      final delay = Duration(
        milliseconds: (seconds * 1000 * (0.75 + jitter() * 0.5)).round(),
      );
      await repository.recordSyncFailure(
        code,
        nextAttempt: transient ? now().add(delay) : null,
      );
      _status(
        ['authentication_required', 'invalid_credentials'].contains(code)
            ? SyncPhase.authenticationRequired
            : transient
            ? SyncPhase.pending
            : SyncPhase.attention,
        code,
      );
      if (transient) _schedule(delay);
    }
  }

  void _schedule(Duration delay) {
    if (!_closed && _foreground) {
      _retry = Timer(delay, () => unawaited(synchronize()));
    }
  }

  Future<void> _pull() async {
    for (var page = 0; page < 100 && _foreground && _authorized; page++) {
      final meta = await repository.syncMetadata();
      final cursor = meta['cursor'] as String?;
      if (_closed || !_foreground || !_authorized) return;
      final routineChannel = routineConnection;
      if (routineChannel == null) {
        final result = await connection.pull(cursor);
        await repository.installPull(result, requestedCursor: cursor);
        if (result.changes.isNotEmpty) await _notifyInstalled();
        if (!result.hasMore) return;
      } else {
        final result = await routineChannel.pullRoutines(cursor);
        await repository.installRoutinePull(result, requestedCursor: cursor);
        if (result.changes.isNotEmpty) await _notifyInstalled();
        if (!result.hasMore) return;
      }
    }
    _again = true;
  }

  Future<void> _bootstrap() async {
    var manifest = await repository.stagedBootstrap();
    if (manifest != null &&
        !DateTime.parse(manifest.expiresAt).isAfter(now().toUtc())) {
      await repository.discardBootstrap();
      manifest = null;
    }
    if (manifest == null) {
      final meta = await repository.syncMetadata();
      manifest = await connection.bootstrap(meta['installation_id'] as String);
      await repository.stageBootstrap(manifest);
    }
    final downloaded = await repository.stagedPageIndices();
    for (var index = 0; index < manifest.pageCount; index++) {
      if (!_foreground || _closed || !_authorized) return;
      if (!downloaded.contains(index)) {
        await repository.stageBootstrapPage(
          index,
          await connection.page(manifest.token, index),
        );
      }
    }
    if (!_foreground || _closed || !_authorized) return;
    final current = await connection.validateSnapshot(manifest.token);
    await repository.activateBootstrap(current);
    await _notifyInstalled();
  }

  Future<void> _bootstrapRoutines(RoutineSyncTransport channel) async {
    var manifest = await repository.stagedRoutineBootstrap();
    if (manifest != null &&
        !DateTime.parse(manifest.expiresAt).isAfter(now().toUtc())) {
      await repository.discardBootstrap();
      manifest = null;
    }
    if (manifest == null) {
      final meta = await repository.syncMetadata();
      manifest = await channel.bootstrapRoutines(
        meta['installation_id'] as String,
      );
      await repository.stageRoutineBootstrap(manifest);
    }
    final downloaded = await repository.stagedPageIndices();
    for (var index = 0; index < manifest.pageCount; index++) {
      if (!_foreground || _closed || !_authorized) return;
      if (!downloaded.contains(index)) {
        await repository.stageRoutineBootstrapPage(
          index,
          await channel.routinePage(manifest.token, index),
        );
      }
    }
    if (!_foreground || _closed || !_authorized) return;
    await repository.activateRoutineBootstrap(
      await channel.validateRoutineSnapshot(manifest.token),
    );
    await _notifyInstalled();
  }

  Future<void> close() async {
    _closed = true;
    _foreground = false;
    _retry?.cancel();
    await _commits?.cancel();
    await _running;
    await _statuses.close();
    await _installations.close();
  }
}
