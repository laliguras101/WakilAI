import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Indicates whether the Wakil backend is connected to live Firebase services
/// or running in deterministic local/offline fallback mode.
enum FirebaseBackendMode {
  /// Firebase Core initialized and live Auth / Firestore instances available.
  live,

  /// Offline, unconfigured (no google-services.json / firebase_options.dart),
  /// test-mode, or `flutter test` environment without Firebase platform channels.
  localFallback,
}

/// Immutable snapshot describing the outcome of [FirebaseBootstrap.initializeSafely].
@immutable
class FirebaseBootstrapState {
  /// Whether Firebase Core initialization succeeded.
  final bool isInitialized;

  /// Active backend execution mode.
  final FirebaseBackendMode mode;

  /// Name of the initialized [FirebaseApp], if live.
  final String? appName;

  /// Firebase project ID of the active app, if live.
  final String? projectId;

  /// Target Firestore database ID configured for Wakil.
  final String firestoreDatabaseId;

  /// Diagnostic reason when running in [FirebaseBackendMode.localFallback].
  final String? failureReason;

  /// Timestamp of the last initialization attempt.
  final DateTime checkedAt;

  /// Creates a [FirebaseBootstrapState].
  const FirebaseBootstrapState({
    required this.isInitialized,
    required this.mode,
    required this.firestoreDatabaseId,
    required this.checkedAt,
    this.appName,
    this.projectId,
    this.failureReason,
  });

  /// Creates an initial uninitialized fallback state.
  factory FirebaseBootstrapState.initial({
    String firestoreDatabaseId = FirebaseBootstrap.defaultFirestoreDatabaseId,
  }) {
    return FirebaseBootstrapState(
      isInitialized: false,
      mode: FirebaseBackendMode.localFallback,
      firestoreDatabaseId: firestoreDatabaseId,
      checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
      failureReason: 'Firebase has not been initialized yet.',
    );
  }

  /// Whether live Firebase services are initialized and ready.
  bool get isLive => isInitialized && mode == FirebaseBackendMode.live;

  @override
  String toString() {
    return 'FirebaseBootstrapState(isInitialized: $isInitialized, mode: $mode, '
        'appName: $appName, projectId: $projectId, '
        'firestoreDatabaseId: $firestoreDatabaseId, failureReason: $failureReason)';
  }
}

/// Safe, idempotent Firebase initialization helper for Wakil.
///
/// Guarantees that missing `google-services.json`, missing `firebase_options.dart`,
/// offline environments, `Skip Auth (Test Mode)`, and headless `flutter test`
/// execution never crash app startup.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// Cloud Firestore `(default)` database bound to Firebase project `wakil-3a91d`.
  static const String defaultFirestoreDatabaseId = '(default)';

  static FirebaseBootstrapState _state = FirebaseBootstrapState.initial();
  static Future<FirebaseBootstrapState>? _inFlightInit;
  static bool _emulatorsConfigured = false;

  /// Latest bootstrap status snapshot.
  static FirebaseBootstrapState get currentState => _state;

  /// Whether live Firebase Core is initialized and available.
  static bool get isLive {
    if (!_state.isLive) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initializes Firebase safely with deterministic fallback on any
  /// configuration, platform-channel, or environment error.
  ///
  /// Calling this repeatedly without changing [forceLocalFallback] returns the
  /// active state without re-initializing.
  static Future<FirebaseBootstrapState> initializeSafely({
    FirebaseOptions? options,
    String? appName,
    String firestoreDatabaseId = defaultFirestoreDatabaseId,
    bool forceLocalFallback = false,
    bool configureEmulators = false,
    String emulatorHost = '127.0.0.1',
    int firestoreEmulatorPort = 8085,
    int authEmulatorPort = 9099,
  }) async {
    if (forceLocalFallback) {
      _state = FirebaseBootstrapState(
        isInitialized: false,
        mode: FirebaseBackendMode.localFallback,
        firestoreDatabaseId: firestoreDatabaseId,
        checkedAt: DateTime.now(),
        failureReason: 'Local fallback mode forced (Test Mode / offline).',
      );
      return _state;
    }

    if (_state.isLive && _state.firestoreDatabaseId == firestoreDatabaseId) {
      return _state;
    }

    final existingFuture = _inFlightInit;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _performInitialization(
      options: options,
      appName: appName,
      firestoreDatabaseId: firestoreDatabaseId,
      configureEmulators: configureEmulators,
      emulatorHost: emulatorHost,
      firestoreEmulatorPort: firestoreEmulatorPort,
      authEmulatorPort: authEmulatorPort,
    );
    _inFlightInit = future;
    try {
      return await future;
    } finally {
      _inFlightInit = null;
    }
  }

  static Future<FirebaseBootstrapState> _performInitialization({
    required FirebaseOptions? options,
    required String? appName,
    required String firestoreDatabaseId,
    required bool configureEmulators,
    required String emulatorHost,
    required int firestoreEmulatorPort,
    required int authEmulatorPort,
  }) async {
    try {
      final FirebaseApp app = await _resolveOrInitializeApp(
        options: options,
        appName: appName,
      );

      if (configureEmulators && !_emulatorsConfigured) {
        await _configureLocalEmulators(
          app: app,
          firestoreDatabaseId: firestoreDatabaseId,
          host: emulatorHost,
          firestorePort: firestoreEmulatorPort,
          authPort: authEmulatorPort,
        );
        _emulatorsConfigured = true;
      }

      _state = FirebaseBootstrapState(
        isInitialized: true,
        mode: FirebaseBackendMode.live,
        appName: app.name,
        projectId: app.options.projectId,
        firestoreDatabaseId: firestoreDatabaseId,
        checkedAt: DateTime.now(),
      );
      return _state;
    } catch (error) {
      // Catch Exception and Error (e.g. MissingPluginException, FirebaseException,
      // AssertionError when secondary app lacks options) so startup never crashes.
      debugPrint(
        'Wakil FirebaseBootstrap falling back to local mode: $error',
      );
      _state = FirebaseBootstrapState(
        isInitialized: false,
        mode: FirebaseBackendMode.localFallback,
        firestoreDatabaseId: firestoreDatabaseId,
        checkedAt: DateTime.now(),
        failureReason: error.toString(),
      );
      return _state;
    }
  }

  static Future<FirebaseApp> _resolveOrInitializeApp({
    required FirebaseOptions? options,
    required String? appName,
  }) async {
    final targetName = appName ?? defaultFirebaseAppName;
    final existingApps = Firebase.apps;
    for (final app in existingApps) {
      if (app.name == targetName) {
        return app;
      }
    }

    if (appName != null &&
        appName != defaultFirebaseAppName &&
        options == null) {
      throw StateError(
        'FirebaseOptions must be provided when initializing named app "$appName".',
      );
    }

    return Firebase.initializeApp(name: appName, options: options);
  }

  static Future<void> _configureLocalEmulators({
    required FirebaseApp app,
    required String firestoreDatabaseId,
    required String host,
    required int firestorePort,
    required int authPort,
  }) async {
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(host, authPort);

    final firestore = FirebaseFirestore.instanceFor(
      app: app,
      databaseId: firestoreDatabaseId,
    );
    firestore.useFirestoreEmulator(host, firestorePort);
  }

  /// Returns [FirebaseAuth] for the active [FirebaseApp], or `null` when
  /// Firebase is uninitialized or unavailable.
  static FirebaseAuth? get authOrNull {
    if (!isLive) {
      return null;
    }
    try {
      final targetApp = _state.appName != null
          ? Firebase.app(_state.appName!)
          : Firebase.app();
      return FirebaseAuth.instanceFor(app: targetApp);
    } catch (_) {
      return null;
    }
  }

  /// Returns [FirebaseFirestore] bound to [databaseId] (or the bootstrapped
  /// database ID), or `null` when Firebase is uninitialized or unavailable.
  static FirebaseFirestore? firestoreOrNull({String? databaseId}) {
    if (!isLive) {
      return null;
    }
    try {
      final targetApp = _state.appName != null
          ? Firebase.app(_state.appName!)
          : Firebase.app();
      return FirebaseFirestore.instanceFor(
        app: targetApp,
        databaseId: databaseId ?? _state.firestoreDatabaseId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Resets cached bootstrap state for isolated unit tests.
  @visibleForTesting
  static void resetForTesting() {
    _state = FirebaseBootstrapState.initial();
    _inFlightInit = null;
    _emulatorsConfigured = false;
  }
}
