import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'configuration.dart';

abstract interface class ProtectedStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformProtectedStorage implements ProtectedStorage {
  final FlutterSecureStorage storage;
  PlatformProtectedStorage({FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
            // Preserve protected grants/ciphertext when the platform reports an
            // error. Automatic reset can turn a recoverable fault into data loss.
            aOptions: AndroidOptions(resetOnError: false),
          );
  @override
  Future<String?> read(String key) async {
    try {
      return await storage.read(key: key);
    } catch (_) {
      throw const AuthFailure('secure_storage_unavailable');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await storage.write(key: key, value: value);
    } catch (_) {
      throw const AuthFailure('secure_storage_unavailable');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await storage.delete(key: key);
    } catch (_) {
      throw const AuthFailure('secure_storage_unavailable');
    }
  }
}

/// The supported Supabase storage interface, explicitly driven/awaited by our
/// lifecycle controller. No SharedPreferences or unawaited SDK persistence.
class SecureSessionStorage extends LocalStorage {
  final ProtectedStorage storage;
  final String namespace;
  SecureSessionStorage(this.storage, this.namespace);
  String get sessionKey => 'dm.$namespace.session';
  String get ownerKey => 'dm.$namespace.local-owner';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<String?> accessToken() => storage.read(sessionKey);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(sessionKey, persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(sessionKey);
  Future<Session?> restoreSession() async {
    final raw = await accessToken();
    if (raw == null) return null;
    try {
      final session = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (session == null || !hasSessionBinding(session)) {
        throw const FormatException();
      }
      return session;
    } catch (_) {
      await removePersistedSession();
      return null; // Only corrupt cloud state is removed; owner/workouts survive.
    }
  }

  bool hasSessionBinding(Session session) {
    try {
      final claims = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(session.accessToken.split('.')[1]),
          ),
        ),
      ) as Map<String, dynamic>;
      return claims['sub'] == session.user.id &&
          Uuid.isValidUUID(fromString: session.user.id) &&
          session.refreshToken != null &&
          session.refreshToken!.isNotEmpty &&
          session.expiresAt != null &&
          session.tokenType == 'bearer';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSession(Session session) async {
    if (!hasSessionBinding(session)) {
      throw const AuthFailure('invalid_credentials');
    }
    await persistSession(jsonEncode(session.toJson()));
  }

  Future<Map<String, dynamic>?> restoreOwner() async {
    final raw = await storage.read(ownerKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['version'] != 1 ||
          value['unlocked'] is! bool ||
          value['owner'] is! String ||
          !Uuid.isValidUUID(fromString: value['owner'] as String)) {
        throw const FormatException();
      }
      return value;
    } catch (_) {
      // Never guess ownership from an email or a corrupt marker.
      throw const AuthFailure('local_identity_unavailable');
    }
  }

  Future<void> saveOwner(
    String owner, {
    required bool unlocked,
    String unit = 'kg',
  }) => storage.write(
    ownerKey,
    jsonEncode({
      'version': 1,
      'owner': owner,
      'unlocked': unlocked,
      'unit': unit,
    }),
  );
}

class SecureGotrueStorage extends GotrueAsyncStorage {
  final ProtectedStorage storage;
  final String namespace;
  SecureGotrueStorage(this.storage, this.namespace);
  String keyFor(String key) => 'dm.$namespace.pkce.$key';
  @override
  Future<String?> getItem({required String key}) => storage.read(keyFor(key));
  @override
  Future<void> removeItem({required String key}) => storage.delete(keyFor(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      storage.write(keyFor(key), value);
}
