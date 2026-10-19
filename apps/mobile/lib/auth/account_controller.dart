import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/workout_repository.dart';

import '../sync/coordinator.dart';
import '../sync/transport.dart';
import '../sync/transport_contract.dart';
import 'configuration.dart';
import 'local_owners.dart';
import 'secure_storage.dart';
import 'supabase_provider.dart';

enum AccountPhase {
  loading,
  signedOut,
  requesting,
  codeSent,
  verifying,
  initializing,
  authenticated,
  refreshing,
  offline,
  authenticationRequired,
  attention,
  signingOut,
  disabled,
}

class AccountState {
  final AccountPhase phase;
  final String? code;
  const AccountState(this.phase, [this.code]);
  String get message => switch (code) {
    'invalid_or_expired_code' =>
      'The code is incorrect or expired. Try again or request a new code.',
    'throttled' => 'Please wait before requesting another code.',
    'network_unavailable' || 'provider_unavailable' =>
      'Connection unavailable. Saved training remains available.',
    'wrong_owner' => 'Sign out before signing in to a different account. Your saved work stays with its owner.',
    'invalid_email' => 'Enter a valid email address.',
    'secure_storage_unavailable' || 'local_identity_unavailable' =>
      'Protected storage is unavailable. Unlock this device and retry.',
    'account_inactive' =>
      'This account is disabled. Sign in with an active account.',
    'authentication_required' || 'invalid_credentials' =>
      'Sign in to synchronize. Saved training remains available.',
    'initialization_failed' =>
      'Account setup could not finish. Retry when connected.',
    'local_storage_unavailable' =>
      'Local training storage could not be opened. Saved work is retained.',
    _ =>
      phase == AccountPhase.codeSent
          ? 'If this email can receive messages, a code has been sent.'
          : code != null
          ? 'This request could not be completed. Please retry.'
          : '',
  };
}

abstract interface class AccountGateway {
  Future<AccountResponseDto> initialize(Session session);
}

class HttpAccountGateway implements AccountGateway {
  final AuthConfiguration configuration;
  HttpAccountGateway(this.configuration);
  @override
  Future<AccountResponseDto> initialize(Session session) async {
    final transport = HttpSyncTransport(
      configuration.api,
      () async => session.accessToken,
      allowLoopbackHttp: configuration.development,
    );
    try {
      return await transport.initializeAccount();
    } finally {
      transport.close();
    }
  }
}

/// Local access is a durable owner grant, never a consequence of a cloud session
/// callback. All auth completion/persistence uses an epoch and a serialized queue.
class AccountController extends ChangeNotifier {
  final OtpProvider provider;
  final AccountGateway gateway;
  final SecureSessionStorage storage;
  final LocalOwnerStores stores;
  final SyncTransport Function(String owner, Future<String?> Function() token)
  syncTransport;
  final DateTime Function() now;
  final _installed = StreamController<void>.broadcast();
  Stream<void> get installations => _installed.stream;
  AccountState state = const AccountState(AccountPhase.loading);
  LocalOwner? local;
  SyncCoordinator? coordinator;
  Session? _session;
  Future<void> _tail = Future.value();
  StreamSubscription<SyncStatus>? _syncEvents;
  Timer? _refreshTimer;
  int _epoch = 0;
  int _refreshFailures = 0;
  DateTime? _lastRefresh;
  DateTime? _nextRefresh;
  bool _foreground = true;
  bool _initializationPending = false;
  bool _disposed = false;
  String? challengeEmail;
  DateTime? resendAt;
  AccountController({
    required this.provider,
    required this.gateway,
    required this.storage,
    required this.stores,
    required this.syncTransport,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;
  String? get owner => local?.repository.ownerId;
  bool get canRetryInitialization =>
      _initializationPending && _session != null && !_expired(_session!);
  bool get busy => [
    AccountPhase.loading,
    AccountPhase.requesting,
    AccountPhase.verifying,
    AccountPhase.initializing,
    AccountPhase.signingOut,
  ].contains(state.phase);
  void _state(AccountPhase phase, [String? code]) {
    state = AccountState(phase, code);
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  Future<void> _enqueue(int epoch, Future<void> Function() action) {
    final work = _tail.then((_) async {
      if (!_current(epoch)) return;
      try {
        await action();
      } catch (error) {
        if (!_current(epoch)) return;
        if (error is SyncFailure &&
            error.code == 'account_inactive' &&
            error.ownerId == _session?.user.id) {
          try {
            if (local != null && owner == error.ownerId) {
              await local!.repository.disableRemoteAccount();
            } else if (local == null && await stores.exists(error.ownerId!)) {
              final locked = await stores.open(error.ownerId!, existing: true);
              try {
                await locked.repository.disableRemoteAccount();
              } finally {
                await locked.close();
              }
            }
            await _deactivate(disabled: true);
          } catch (failure) {
            _state(
              AccountPhase.attention,
              failure is AuthFailure
                  ? failure.code
                  : 'local_storage_unavailable',
            );
          }
          return;
        }
        coordinator?.cloudAuthorization(false);
        final code = error is AuthFailure
            ? error.code
            : error is SyncFailure
            ? error.code
            : 'local_storage_unavailable';
        _state(
          code == 'authentication_required' || code == 'invalid_credentials'
              ? AccountPhase.authenticationRequired
              : AccountPhase.attention,
          code,
        );
      }
    });
    _tail = work.then<void>((_) {}, onError: (_, _) {});
    return work;
  }

  Future<void> restore() {
    final epoch = _epoch;
    return _enqueue(epoch, () async {
      final grant = await storage.restoreOwner();
      if (!_current(epoch)) return;
      if (grant != null && grant['unlocked'] == true) {
        final cached = await stores.open(
          grant['owner'] as String,
          existing: true,
        );
        try {
          final identity = await cached.database
              .customSelect('SELECT owner_id,locked FROM local_identity')
              .getSingle();
          if (identity.read<String>('owner_id') != grant['owner']) {
            throw const AuthFailure('wrong_owner');
          }
          if (await cached.repository.remoteDisabled()) {
            await cached.close();
            await storage.saveOwner(grant['owner'] as String, unlocked: false);
            await storage.removePersistedSession();
            _state(AccountPhase.disabled, 'account_inactive');
            return;
          }
          if (identity.read<int>('locked') == 1) {
            await cached.close();
            await storage.saveOwner(grant['owner'] as String, unlocked: false);
            await storage.removePersistedSession();
            _state(AccountPhase.signedOut);
            return;
          }
          // A protected grant restores an already initialized, unlocked database;
          // initialize refuses a DB explicitly locked by sign-out/remote disable.
          await cached.repository.initialize();
          if (!_current(epoch)) {
            await cached.close();
            return;
          }
          local = cached;
          _attach();
          _state(AccountPhase.offline, 'authentication_required');
        } catch (_) {
          await cached.close();
          rethrow;
        }
      }
      if (grant != null && grant['unlocked'] == false) {
        await storage.removePersistedSession();
        _state(AccountPhase.signedOut);
        return;
      }
      _session = await storage.restoreSession();
      if (!_current(epoch)) {
        _session = null;
        return;
      }
      if (_session != null && local != null && _session!.user.id != owner) {
        _session = null;
        await storage.removePersistedSession();
      }
      if (_session == null) {
        _state(
          local == null
              ? AccountPhase.signedOut
              : AccountPhase.authenticationRequired,
        );
        return;
      }
      if (_expired(_session!)) {
        _state(
          local == null
              ? AccountPhase.authenticationRequired
              : AccountPhase.offline,
          'authentication_required',
        );
        _scheduleRefresh(Duration.zero);
      } else if (local == null) {
        await _establish(_session!, epoch);
      } else {
        _state(AccountPhase.authenticated);
        coordinator!.cloudAuthorization(true);
        _scheduleExpiry();
      }
    });
  }

  Future<void> requestOtp(String email, {bool resend = false}) {
    if (state.phase == AccountPhase.signingOut) return Future.value();
    final epoch = ++_epoch;
    _state(AccountPhase.requesting);
    return _enqueue(epoch, () async {
      final address = email.trim();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address) ||
          address.runes.length > 254) {
        throw const AuthFailure('invalid_email');
      }
      if (resend && resendAt != null && now().isBefore(resendAt!)) {
        throw const AuthFailure('throttled');
      }
      // Once another challenge is requested, an ambiguous/failed response must
      // not leave the previous recipient available for verification.
      challengeEmail = null;
      resendAt = now().add(const Duration(seconds: 60));
      await provider.request(address);
      if (!_current(epoch)) return;
      // Provider latency must not consume the successful request's cooldown.
      resendAt = now().add(const Duration(seconds: 60));
      challengeEmail = address;
      _state(AccountPhase.codeSent);
    });
  }

  Future<void> verifyOtp(String code) {
    if (state.phase == AccountPhase.signingOut) return Future.value();
    final epoch = ++_epoch;
    _state(AccountPhase.verifying);
    return _enqueue(epoch, () async {
      final email = challengeEmail;
      if (email == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
        throw const AuthFailure('invalid_or_expired_code');
      }
      final session = await provider.verify(email, code);
      if (!_current(epoch)) return;
      if (local != null && session.user.id != owner) {
        throw const AuthFailure('wrong_owner');
      }
      _session = session;
      await storage.saveSession(session);
      if (!_current(epoch)) return;
      await _establish(session, epoch);
    });
  }

  Future<void> retryInitialization() => _enqueue(_epoch, () async {
    final session = _session;
    if (session == null || _expired(session)) {
      throw const AuthFailure('authentication_required');
    }
    await _establish(session, _epoch);
  });

  Future<void> _establish(Session session, int epoch) async {
    _initializationPending = true;
    _state(AccountPhase.initializing);
    final account = await gateway.initialize(session);
    if (!_current(epoch)) return;
    if (account.ownerId != session.user.id ||
        local != null && owner != account.ownerId) {
      throw const AuthFailure('wrong_owner');
    }
    final selected = local ?? await stores.open(account.ownerId);
    try {
      if (!_current(epoch)) {
        if (selected != local) await selected.close();
        return;
      }
      // Only the live, verified API subject grants unlock; no email/cached UI ID.
      final identity = await selected.database
          .customSelect('SELECT owner_id FROM local_identity')
          .getSingleOrNull();
      if (identity != null) {
        await selected.repository.unlockVerifiedOwner(account.ownerId);
      }
      await selected.repository.initialize();
      if (!_current(epoch)) {
        if (selected != local) await selected.close();
        return;
      }
      await storage.saveOwner(
        account.ownerId,
        unlocked: true,
        unit: (account.profile as Map<String, dynamic>)['unit'] as String,
      );
      if (!_current(epoch)) {
        if (selected != local) {
          await selected.repository.signOut();
          try {
            await storage.saveOwner(account.ownerId, unlocked: false);
          } finally {
            await selected.close();
          }
        }
        return;
      }
      local = selected;
      _initializationPending = false;
      if (coordinator == null) _attach();
      challengeEmail = null;
      _refreshFailures = 0;
      _nextRefresh = null;
      _lastRefresh = null;
      _state(AccountPhase.authenticated);
      coordinator!.cloudAuthorization(true);
      _scheduleExpiry();
    } catch (_) {
      if (selected != local) {
        if (!_current(epoch) && !await selected.repository.remoteDisabled()) {
          await selected.repository.signOut();
        }
        await selected.close();
      }
      rethrow;
    }
  }

  void _attach() {
    final installationOwner = owner!;
    final transport = syncTransport(
      installationOwner,
      () async =>
          owner == installationOwner &&
              _session?.user.id == installationOwner &&
              _session != null &&
              !_expired(_session!)
          ? _session!.accessToken
          : null,
    );
    coordinator = SyncCoordinator(
      local!.repository,
      transport,
      onInstalled: () async {
        if (!_disposed && owner == installationOwner) _installed.add(null);
      },
    );
    coordinator!.cloudAuthorization(false);
    coordinator!.foreground(_foreground);
    _syncEvents = coordinator!.statuses.listen((status) {
      if (owner != installationOwner || _disposed) return;
      if (status.phase == SyncPhase.accountDisabled) {
        unawaited(_enqueue(_epoch, () => _deactivate(disabled: true)));
      } else if (status.phase == SyncPhase.authenticationRequired &&
          _session != null &&
          state.phase == AccountPhase.authenticated) {
        _state(AccountPhase.authenticationRequired, 'authentication_required');
        coordinator!.cloudAuthorization(false);
        if (_lastRefresh == null ||
            now().difference(_lastRefresh!) >= const Duration(seconds: 30)) {
          _scheduleRefresh(Duration.zero);
        } else {
          _refreshTimer?.cancel(); // A fresh rejected token requires attention, not a refresh loop.
        }
      }
      // Notify the host to refresh repository-backed UI after remote installations.
      if (!_disposed) notifyListeners();
    });
    coordinator!.start();
  }

  bool _expired(Session session) =>
      session.expiresAt == null ||
      !DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          .isAfter(now().toUtc());

  Future<void> refresh({bool force = false}) => _enqueue(_epoch, () async {
    final epoch = _epoch;
    final session = _session;
    if (session == null) {
      _state(AccountPhase.authenticationRequired, 'authentication_required');
      return;
    }
    if (!force && _nextRefresh != null && now().isBefore(_nextRefresh!)) {
      _scheduleRefresh(_nextRefresh!.difference(now()));
      return;
    }
    _lastRefresh = now();
    coordinator?.cloudAuthorization(false);
    _state(AccountPhase.refreshing);
    try {
      final refreshed = await provider.refresh(session);
      if (!_current(epoch)) return;
      if (refreshed.user.id != session.user.id ||
          owner != null && refreshed.user.id != owner ||
          _expired(refreshed)) {
        throw const AuthFailure('wrong_owner');
      }
      await storage.saveSession(refreshed);
      if (!_current(epoch)) return;
      _session = refreshed;
      _refreshFailures = 0;
      _nextRefresh = null;
      if (local == null) {
        await _establish(refreshed, epoch);
        return;
      }
      _state(AccountPhase.authenticated);
      coordinator!.cloudAuthorization(true);
      _scheduleExpiry();
    } on AuthFailure catch (error) {
      if (!_current(epoch)) return;
      if (error.retryable) {
        _state(AccountPhase.offline, error.code);
        final delay = Duration(
          seconds: min(60, pow(2, _refreshFailures.clamp(0, 6)).toInt()),
        );
        _nextRefresh = now().add(delay);
        _scheduleRefresh(delay);
        _refreshFailures++;
      } else {
        _session = null;
        await storage.removePersistedSession();
        _state(AccountPhase.authenticationRequired, 'authentication_required');
      }
    }
  });

  void _scheduleExpiry() {
    final expiration = DateTime.fromMillisecondsSinceEpoch(
      _session!.expiresAt! * 1000,
    );
    final delay = expiration
        .subtract(const Duration(seconds: 30))
        .difference(now());
    _scheduleRefresh(delay < Duration.zero ? Duration.zero : delay);
  }

  void _scheduleRefresh(Duration delay) {
    _refreshTimer?.cancel();
    if (_nextRefresh != null && now().add(delay).isBefore(_nextRefresh!)) {
      delay = _nextRefresh!.difference(now());
    }
    if (_foreground && !_disposed) {
      _refreshTimer = Timer(delay, () => unawaited(refresh()));
    }
  }

  void foreground(bool available) {
    _foreground = available;
    coordinator?.foreground(available);
    if (!available) {
      _refreshTimer?.cancel();
    } else if (_session != null) {
      _scheduleExpiry();
    }
  }

  Future<void> signOut() {
    if (state.phase == AccountPhase.signingOut) return _tail;
    ++_epoch; // Invalidates pending verification/refresh immediately, before waits.
    _refreshTimer?.cancel();
    coordinator?.cloudAuthorization(false);
    _state(AccountPhase.signingOut);
    final session = _session;
    _session = null;
    final work = _tail.then((_) async {
      AuthFailure? localFailure;
      try {
        await _deactivate(disabled: false);
      } on AuthFailure catch (error) {
        localFailure = error;
      }
      _state(AccountPhase.signingOut);
      String? cloudFailure;
      try {
        await provider.signOut(session);
      } catch (_) {
        cloudFailure = 'remote_sign_out_unavailable';
      }
      _state(
        localFailure == null ? AccountPhase.signedOut : AccountPhase.attention,
        localFailure?.code ?? cloudFailure,
      );
    });
    _tail = work.then<void>((_) {}, onError: (_, _) {});
    return work;
  }

  Future<void> _deactivate({required bool disabled}) async {
    final selected = local;
    final id = owner;
    ++_epoch;
    _refreshTimer?.cancel();
    _session = null;
    _initializationPending = false;
    challengeEmail = null;
    _refreshFailures = 0;
    _nextRefresh = null;
    _lastRefresh = null;
    AuthFailure? failure;
    // The SQLite lock and protected logout marker independently fail closed on
    // restart. A stale cached session never unlocks a deliberately locked database.
    if (id != null) {
      try {
        await storage.saveOwner(id, unlocked: false);
      } catch (_) {
        failure = const AuthFailure('secure_storage_unavailable');
      }
    }
    try {
      await storage.removePersistedSession();
    } catch (_) {
      failure = const AuthFailure('secure_storage_unavailable');
    }
    await _syncEvents?.cancel();
    _syncEvents = null;
    try {
      await coordinator?.close();
    } catch (_) {
      failure ??= const AuthFailure('local_storage_unavailable');
    } finally {
      if (coordinator?.transport case final HttpSyncTransport http) {
        http.close();
      }
      coordinator = null;
    }
    if (selected != null) {
      try {
        if (!await selected.repository.remoteDisabled()) {
          await selected.repository.signOut();
        }
      } catch (_) {
        failure ??= const AuthFailure('local_storage_unavailable');
      } finally {
        try {
          await selected.close();
        } catch (_) {
          failure ??= const AuthFailure('local_storage_unavailable');
        }
      }
    }
    local = null;
    if (failure != null) {
      _state(AccountPhase.attention, failure.code);
      throw failure;
    }
    _state(
      disabled ? AccountPhase.disabled : AccountPhase.signedOut,
      disabled ? 'account_inactive' : null,
    );
  }

  Future<void> close() async {
    _disposed = true;
    ++_epoch;
    _refreshTimer?.cancel();
    await _tail;
    await _syncEvents?.cancel();
    await coordinator?.close();
    if (coordinator?.transport case final HttpSyncTransport http) http.close();
    await local?.close();
    await _installed.close();
    _session = null;
    super.dispose();
  }
}
