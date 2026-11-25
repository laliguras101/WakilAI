import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_bootstrap.dart';

/// User workspace authorization roles for Wakil (`US-14`).
enum WakilUserRole {
  /// Administrative governance role routed to `AdminWorkspaceScreen`.
  admin,

  /// Standard citizen or advocate role routed to `MainWorkspaceScreen`.
  citizen,
}

/// Abstract key-value persistence layer used by [SessionService].
///
/// Decouples session storage from platform channels so unit tests and
/// unsupported platforms execute hermetically without crashes.
abstract interface class SecureKeyValueStore {
  /// Reads a stored string value for [key], or `null` if absent.
  Future<String?> read(String key);

  /// Persists [value] under [key].
  Future<void> write(String key, String value);

  /// Deletes the entry for [key].
  Future<void> delete(String key);

  /// Removes all entries managed by this store.
  Future<void> deleteAll();
}

/// [SecureKeyValueStore] backed by [FlutterSecureStorage] with transparent
/// in-memory fallback when native platform channels are unavailable.
class ResilientSecureStorage implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = <String, String>{};
  bool _usingMemoryFallback = false;

  /// Creates a [ResilientSecureStorage] wrapping [storage].
  ResilientSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(storageNamespace: 'wakil_ai_session'),
            );

  /// Whether storage fell back to in-memory persistence due to missing
  /// platform channels or platform storage failure.
  bool get isUsingMemoryFallback => _usingMemoryFallback;

  Future<T> _runWithFallback<T>(
    Future<T> Function() primary,
    T Function() fallback,
  ) async {
    if (_usingMemoryFallback) {
      return fallback();
    }
    try {
      return await primary();
    } catch (error) {
      // MissingPluginException, PlatformException, or UnsupportedError in tests
      // switches safely to deterministic in-memory storage.
      debugPrint(
        'Wakil SessionService switching to in-memory storage fallback: $error',
      );
      _usingMemoryFallback = true;
      return fallback();
    }
  }

  @override
  Future<String?> read(String key) {
    return _runWithFallback(
      () => _storage.read(key: key),
      () => _memoryFallback[key],
    );
  }

  @override
  Future<void> write(String key, String value) {
    return _runWithFallback(
      () async {
        await _storage.write(key: key, value: value);
        _memoryFallback[key] = value;
      },
      () async {
        _memoryFallback[key] = value;
      },
    );
  }

  @override
  Future<void> delete(String key) {
    return _runWithFallback(
      () async {
        await _storage.delete(key: key);
        _memoryFallback.remove(key);
      },
      () async {
        _memoryFallback.remove(key);
      },
    );
  }

  @override
  Future<void> deleteAll() {
    return _runWithFallback(
      () async {
        await _storage.deleteAll();
        _memoryFallback.clear();
      },
      () async {
        _memoryFallback.clear();
      },
    );
  }
}

/// Pure in-memory [SecureKeyValueStore] for deterministic testing.
class InMemoryKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}

/// Immutable representation of an active or remembered Wakil user session.
@immutable
class WakilSessionRecord {
  /// Stable user identifier (Firebase UID or deterministic fallback UID).
  final String userId;

  /// Primary login identifier (email address or normalized +977 phone).
  final String identifier;

  /// Optional user email address.
  final String? email;

  /// Optional normalized Nepali phone number (`+977...`).
  final String? phoneNumber;

  /// Optional display name.
  final String? displayName;

  /// Resolved workspace role (`US-14`).
  final WakilUserRole role;

  /// Authentication method (`password`, `google.com`, `otp`, `test_mode`).
  final String authProvider;

  /// Whether the user opted in to Remember Device (`US-07`).
  final bool rememberDevice;

  /// Whether this session was created via Skip Auth (Test Mode).
  final bool isTestMode;

  /// Optional token reference stored only in secure storage when remembered.
  final String? sessionToken;

  /// Unique device installation identifier for session revocation tracking.
  final String deviceId;

  /// Monotonic global revocation epoch valid when this session was issued.
  final int revocationEpoch;

  /// Session creation timestamp (UTC).
  final DateTime createdAt;

  /// Session last-update timestamp (UTC).
  final DateTime updatedAt;

  /// Creates a [WakilSessionRecord].
  const WakilSessionRecord({
    required this.userId,
    required this.identifier,
    required this.role,
    required this.authProvider,
    required this.rememberDevice,
    required this.isTestMode,
    required this.deviceId,
    required this.revocationEpoch,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.sessionToken,
  });

  /// Serializes this session to a JSON map for encrypted secure storage.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'identifier': identifier,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'role': role.name,
      'authProvider': authProvider,
      'rememberDevice': rememberDevice,
      'isTestMode': isTestMode,
      'sessionToken': sessionToken,
      'deviceId': deviceId,
      'revocationEpoch': revocationEpoch,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Restores a [WakilSessionRecord] from a decoded JSON map.
  factory WakilSessionRecord.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String? ?? WakilUserRole.citizen.name;
    final role = WakilUserRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => WakilUserRole.citizen,
    );

    return WakilSessionRecord(
      userId: json['userId'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String?,
      role: role,
      authProvider: json['authProvider'] as String? ?? 'password',
      rememberDevice: json['rememberDevice'] as bool? ?? false,
      isTestMode: json['isTestMode'] as bool? ?? false,
      sessionToken: json['sessionToken'] as String?,
      deviceId: json['deviceId'] as String? ?? '',
      revocationEpoch: (json['revocationEpoch'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Result returned by [SessionService.revokeAllSessions] (`US-13`).
@immutable
class GlobalRevocationResult {
  /// Whether revocation succeeded cleanly.
  final bool isSuccess;

  /// New monotonic revocation epoch invalidated against older sessions.
  final int revocationEpoch;

  /// Number of remembered credentials/devices cleared locally.
  final bool localTokensCleared;

  /// Whether active remote Firebase auth state was also signed out.
  final bool remoteSessionSignedOut;

  /// Optional identity for which global revocation was requested.
  final String? identity;

  /// Human-readable status summary.
  final String message;

  /// Creates a [GlobalRevocationResult].
  const GlobalRevocationResult({
    required this.isSuccess,
    required this.revocationEpoch,
    required this.localTokensCleared,
    required this.remoteSessionSignedOut,
    required this.message,
    this.identity,
  });
}

/// Optional callback hook for invoking a backend/Cloud Function session
/// revocation endpoint (e.g. Firebase Admin `revokeRefreshTokens(uid)`).
typedef RemoteSessionRevocationHook = Future<void> Function(
  String? identity,
  String? uid,
);

/// Manages encrypted session persistence (`US-07` Remember Device), disclaimer
/// consent state (`US-03`), and global token/device revocation (`US-13`).
class SessionService {
  /// Storage key for the serialized remembered session record.
  static const String sessionRecordKey = 'wakil.session.record';

  /// Storage key for the remembered login identifier (email or phone).
  static const String rememberedIdentifierKey = 'wakil.session.identifier';

  /// Storage key for the user's Remember Device checkbox preference.
  static const String rememberDeviceFlagKey = 'wakil.session.remember_device';

  /// Storage key for the device installation identifier.
  static const String deviceIdKey = 'wakil.session.device_id';

  /// Storage key for the global session revocation epoch counter.
  static const String revocationEpochKey = 'wakil.session.revocation_epoch';

  /// Storage key for the legal disclaimer consent state (`US-03`).
  static const String disclaimerAcceptedKey = 'wakil.onboarding.disclaimer_ok';

  final SecureKeyValueStore _store;
  final RemoteSessionRevocationHook? _remoteRevocationHook;
  final StreamController<WakilSessionRecord?> _sessionController =
      StreamController<WakilSessionRecord?>.broadcast();

  WakilSessionRecord? _activeSession;
  int _revocationEpoch = 0;
  bool _rememberDeviceEnabled = true;

  /// Creates a [SessionService].
  ///
  /// Uses [ResilientSecureStorage] backed by `flutter_secure_storage` unless a
  /// custom [store] is supplied.
  SessionService({
    SecureKeyValueStore? store,
    FlutterSecureStorage? secureStorage,
    this._remoteRevocationHook,
  }) : _store = store ?? ResilientSecureStorage(storage: secureStorage);

  /// Currently active in-memory session, or `null` if signed out.
  WakilSessionRecord? get activeSession => _activeSession;

  /// Whether a user session is currently active.
  bool get isAuthenticated => _activeSession != null;

  /// Current `Remember Device` preference (`US-07`).
  bool get rememberDeviceEnabled => _rememberDeviceEnabled;

  /// Current global revocation counter (`US-13`).
  int get revocationEpoch => _revocationEpoch;

  /// Whether secure storage fell back to in-memory storage (e.g. tests).
  bool get isUsingMemoryFallback =>
      _store is ResilientSecureStorage && _store.isUsingMemoryFallback;

  /// Broadcast stream emitting session transitions (sign-in, restore, sign-out,
  /// global revocation).
  Stream<WakilSessionRecord?> get sessionChanges => _sessionController.stream;

  Future<int> _loadRevocationEpoch() async {
    final raw = await _store.read(revocationEpochKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null && parsed > _revocationEpoch) {
      _revocationEpoch = parsed;
    }
    return _revocationEpoch;
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _store.read(deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = _generateDeviceId();
    await _store.write(deviceIdKey, generated);
    return generated;
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    final suffix = List<int>.generate(8, (_) => random.nextInt(16))
        .map((n) => n.toRadixString(16))
        .join();
    return 'wakil-dev-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  /// Restores a previously remembered device session (`US-07`) if present and
  /// not invalidated by a subsequent global session revocation (`US-13`).
  Future<WakilSessionRecord?> restoreRememberedSession() async {
    final currentEpoch = await _loadRevocationEpoch();
    final rememberRaw = await _store.read(rememberDeviceFlagKey);
    if (rememberRaw != null) {
      _rememberDeviceEnabled = rememberRaw == 'true';
    }

    final encoded = await _store.read(sessionRecordKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        await _store.delete(sessionRecordKey);
        return null;
      }

      final record = WakilSessionRecord.fromJson(decoded);
      if (!record.rememberDevice ||
          record.identifier.isEmpty ||
          record.revocationEpoch < currentEpoch) {
        await _store.delete(sessionRecordKey);
        return null;
      }

      _activeSession = record;
      _emitSession(record);
      return record;
    } catch (_) {
      await _store.delete(sessionRecordKey);
      return null;
    }
  }

  /// Reads the stored `Remember Device` preference (`US-07`), defaulting to
  /// `true` on fresh installs.
  Future<bool> getRememberDevicePreference() async {
    final raw = await _store.read(rememberDeviceFlagKey);
    if (raw == null) {
      return _rememberDeviceEnabled;
    }
    _rememberDeviceEnabled = raw == 'true';
    return _rememberDeviceEnabled;
  }

  /// Returns the last remembered user identifier (email or phone) if stored.
  Future<String?> getRememberedIdentifier() {
    return _store.read(rememberedIdentifierKey);
  }

  /// Activates a user session and persists encrypted device state when
  /// [rememberDevice] is `true` and [isTestMode] is `false`.
  Future<WakilSessionRecord> saveSession({
    required String userId,
    required String identifier,
    required WakilUserRole role,
    String? email,
    String? phoneNumber,
    String? displayName,
    String authProvider = 'password',
    bool rememberDevice = true,
    bool isTestMode = false,
    String? sessionToken,
  }) async {
    final epoch = await _loadRevocationEpoch();
    final deviceId = await _getOrCreateDeviceId();
    final now = DateTime.now().toUtc();

    final record = WakilSessionRecord(
      userId: userId,
      identifier: identifier,
      email: email,
      phoneNumber: phoneNumber,
      displayName: displayName,
      role: role,
      authProvider: authProvider,
      rememberDevice: rememberDevice && !isTestMode,
      isTestMode: isTestMode,
      sessionToken: sessionToken,
      deviceId: deviceId,
      revocationEpoch: epoch,
      createdAt: now,
      updatedAt: now,
    );

    _activeSession = record;
    _rememberDeviceEnabled = rememberDevice;
    await _store.write(
      rememberDeviceFlagKey,
      rememberDevice ? 'true' : 'false',
    );

    if (rememberDevice && !isTestMode) {
      await _store.write(sessionRecordKey, jsonEncode(record.toJson()));
      await _store.write(rememberedIdentifierKey, identifier);
    } else {
      await _store.delete(sessionRecordKey);
      if (!rememberDevice) {
        await _store.delete(rememberedIdentifierKey);
      }
    }

    _emitSession(record);
    return record;
  }

  /// Signs out the current session while optionally keeping the remembered
  /// identifier for faster next sign-in.
  Future<void> clearCurrentSession({
    bool preserveRememberedIdentifier = false,
  }) async {
    _activeSession = null;
    await _store.delete(sessionRecordKey);
    if (!preserveRememberedIdentifier) {
      await _store.delete(rememberedIdentifierKey);
    }
    _emitSession(null);
  }

  /// Executes Global Session Revocation (`US-13`).
  ///
  /// Clears all remembered tokens, persisted session records, and device
  /// identifiers, bumps the monotonic revocation epoch, invokes any configured
  /// remote revocation hook, and signs out live Firebase Auth if active.
  Future<GlobalRevocationResult> revokeAllSessions({
    String? identity,
    FirebaseAuth? firebaseAuth,
  }) async {
    final currentEpoch = await _loadRevocationEpoch();
    final nextEpoch = currentEpoch + 1;
    final activeUid = _activeSession?.userId;

    _activeSession = null;
    _revocationEpoch = nextEpoch;
    _rememberDeviceEnabled = false;

    await _store.delete(sessionRecordKey);
    await _store.delete(rememberedIdentifierKey);
    await _store.write(rememberDeviceFlagKey, 'false');
    await _store.write(revocationEpochKey, nextEpoch.toString());
    // Rotate local device ID so previously bound device fingerprints are void.
    await _store.write(deviceIdKey, _generateDeviceId());

    bool remoteSignedOut = false;
    final auth = firebaseAuth ?? FirebaseBootstrap.authOrNull;
    if (auth != null) {
      try {
        if (auth.currentUser != null) {
          await auth.signOut();
          remoteSignedOut = true;
        }
      } catch (error) {
        debugPrint('Wakil SessionService remote signOut warning: $error');
      }
    }

    if (_remoteRevocationHook != null) {
      try {
        await _remoteRevocationHook(identity, activeUid);
      } catch (error) {
        debugPrint('Wakil SessionService remote revocation hook error: $error');
      }
    }

    _emitSession(null);

    return GlobalRevocationResult(
      isSuccess: true,
      revocationEpoch: nextEpoch,
      localTokensCleared: true,
      remoteSessionSignedOut: remoteSignedOut,
      identity: identity,
      message: 'All device tokens and active sessions have been revoked.',
    );
  }

  /// Returns whether the user previously accepted the mandatory legal disclaimer
  /// (`US-03`).
  Future<bool> hasAcceptedDisclaimer() async {
    final raw = await _store.read(disclaimerAcceptedKey);
    return raw == 'true';
  }

  /// Persists the legal disclaimer consent state (`US-03`).
  Future<void> setDisclaimerAccepted(bool accepted) async {
    await _store.write(disclaimerAcceptedKey, accepted ? 'true' : 'false');
  }

  void _emitSession(WakilSessionRecord? session) {
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }
  }

  /// Releases stream resources held by this service.
  Future<void> dispose() async {
    await _sessionController.close();
  }
}
