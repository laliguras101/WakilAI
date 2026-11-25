import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_bootstrap.dart';
import 'role_routing_service.dart';
import 'session_service.dart';

/// Immutable authenticated user summary surfaced to Wakil UI and routing.
@immutable
class WakilUser {
  /// Stable user ID (Firebase Auth UID or deterministic local fallback ID).
  final String uid;

  /// Canonical login identifier (email or normalized `+977` phone).
  final String identifier;

  /// Email address if available.
  final String? email;

  /// Normalized Nepali mobile number (`+977...`) if available.
  final String? phoneNumber;

  /// Full display name if available.
  final String? displayName;

  /// Resolved workspace role (`US-14`).
  final WakilUserRole role;

  /// Authentication provider ID (`password`, `google.com`, `phone`, `test_mode`).
  final String providerId;

  /// Whether this user is operating in local/offline/test mode.
  final bool isTestMode;

  /// Creates a [WakilUser].
  const WakilUser({
    required this.uid,
    required this.identifier,
    required this.role,
    required this.providerId,
    required this.isTestMode,
    this.email,
    this.phoneNumber,
    this.displayName,
  });

  /// Whether this user should route to the Admin Console Workspace (`US-14`).
  bool get isAdmin => role == WakilUserRole.admin;

  /// Creates a [WakilUser] from a [WakilSessionRecord].
  factory WakilUser.fromSession(WakilSessionRecord session) {
    return WakilUser(
      uid: session.userId,
      identifier: session.identifier,
      email: session.email,
      phoneNumber: session.phoneNumber,
      displayName: session.displayName,
      role: session.role,
      providerId: session.authProvider,
      isTestMode: session.isTestMode,
    );
  }
}

/// Result of sign-in, Google Sign-In, OTP verification, or test-mode entry.
@immutable
class AuthResult {
  /// Whether authentication succeeded.
  final bool isSuccess;

  /// Authenticated user when [isSuccess] is `true`.
  final WakilUser? user;

  /// Persisted or active session record when [isSuccess] is `true`.
  final WakilSessionRecord? session;

  /// Target workspace route (`US-14`) when [isSuccess] is `true`.
  final WorkspaceDestination? destination;

  /// Machine-readable error code when [isSuccess] is `false`.
  final String? errorCode;

  /// User-facing status or error message.
  final String? message;

  /// Whether the operation ran using deterministic local/test fallback rather
  /// than live Firebase Auth.
  final bool isFallbackMode;

  /// Whether a subsequent SMS OTP verification step is pending (`US-08`-`US-11`).
  final bool requiresOtpVerification;

  /// Active SMS verification ID when OTP verification is pending.
  final String? verificationId;

  /// Creates an [AuthResult].
  const AuthResult({
    required this.isSuccess,
    this.user,
    this.session,
    this.destination,
    this.errorCode,
    this.message,
    this.isFallbackMode = false,
    this.requiresOtpVerification = false,
    this.verificationId,
  });

  /// Constructs a successful [AuthResult].
  factory AuthResult.success({
    required WakilUser user,
    required WakilSessionRecord session,
    required WorkspaceDestination destination,
    bool isFallbackMode = false,
    bool requiresOtpVerification = false,
    String? verificationId,
    String? message,
  }) {
    return AuthResult(
      isSuccess: true,
      user: user,
      session: session,
      destination: destination,
      isFallbackMode: isFallbackMode,
      requiresOtpVerification: requiresOtpVerification,
      verificationId: verificationId,
      message: message,
    );
  }

  /// Constructs a failed [AuthResult].
  factory AuthResult.failure({
    required String errorCode,
    required String message,
    bool isFallbackMode = false,
  }) {
    return AuthResult(
      isSuccess: false,
      errorCode: errorCode,
      message: message,
      isFallbackMode: isFallbackMode,
    );
  }
}

/// Result of dispatching or resending a 6-digit SMS OTP (`US-09`, `US-10`).
@immutable
class OtpDispatchResult {
  /// Whether the OTP dispatch succeeded.
  final bool isSuccess;

  /// Normalized Nepali mobile number (`+977...`).
  final String phoneNumber;

  /// Verification ID to pair with the user-entered 6-digit SMS code.
  final String verificationId;

  /// Resend token provided by Firebase Auth for `forceResendingToken`.
  final int? resendToken;

  /// Countdown duration before SMS resend becomes available (`US-10`).
  final Duration timeout;

  /// Whether Android auto-verification resolved immediately.
  final bool autoVerified;

  /// Whether dispatch used deterministic local fallback.
  final bool isFallbackMode;

  /// User-facing status or error message.
  final String? message;

  /// Machine-readable error code on failure.
  final String? errorCode;

  /// Creates an [OtpDispatchResult].
  const OtpDispatchResult({
    required this.isSuccess,
    required this.phoneNumber,
    required this.verificationId,
    required this.timeout,
    this.resendToken,
    this.autoVerified = false,
    this.isFallbackMode = false,
    this.message,
    this.errorCode,
  });
}

/// Result of Step 1 of Password Recovery (`US-12` identity verification).
@immutable
class PasswordRecoveryVerificationResult {
  /// Whether the identity passed verification.
  final bool isSuccess;

  /// Normalized email or `+977` phone number.
  final String normalizedIdentity;

  /// Whether [normalizedIdentity] is an email address (vs phone number).
  final bool isEmailIdentity;

  /// Whether deterministic local fallback handled verification.
  final bool isFallbackMode;

  /// User-facing status or error message.
  final String message;

  /// Machine-readable error code when [isSuccess] is `false`.
  final String? errorCode;

  /// Creates a [PasswordRecoveryVerificationResult].
  const PasswordRecoveryVerificationResult({
    required this.isSuccess,
    required this.normalizedIdentity,
    required this.isEmailIdentity,
    required this.message,
    this.isFallbackMode = false,
    this.errorCode,
  });
}

/// Result of Step 2 of Password Recovery (`US-12` reset + `US-13` revocation).
@immutable
class PasswordResetResult {
  /// Whether the password update or reset email dispatch succeeded.
  final bool isSuccess;

  /// Normalized identity whose password was updated/reset.
  final String normalizedIdentity;

  /// Whether global session revocation (`US-13`) was executed.
  final bool sessionsRevoked;

  /// Whether deterministic local fallback handled the reset.
  final bool isFallbackMode;

  /// User-facing status or error message.
  final String message;

  /// Machine-readable error code when [isSuccess] is `false`.
  final String? errorCode;

  /// Creates a [PasswordResetResult].
  const PasswordResetResult({
    required this.isSuccess,
    required this.normalizedIdentity,
    required this.sessionsRevoked,
    required this.message,
    this.isFallbackMode = false,
    this.errorCode,
  });
}

/// Optional resolver mapping a normalized Nepali phone number (`+977...`) to a
/// registered email address when signing in with phone + password on Firebase.
typedef PhoneToEmailResolver = Future<String?> Function(String normalizedPhone);

/// Repository interface defining Wakil authentication, registration, OTP,
/// password recovery, and session sign-out operations.
abstract interface class WakilAuthRepository {
  /// Current authenticated user, or `null` when signed out.
  WakilUser? get currentUser;

  /// Stream emitting authentication state changes.
  Stream<WakilUser?> get authStateChanges;

  /// Whether a live Firebase Auth backend is currently active.
  bool get isLiveBackend;

  /// Restores any remembered device session (`US-07`).
  Future<AuthResult?> restoreSession();

  /// Signs in with email or Nepali mobile number and password (`US-04`, `US-07`).
  Future<AuthResult> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
    bool rememberDevice = true,
  });

  /// Signs in using Google One-Tap / OAuth (`US-06`).
  Future<AuthResult> signInWithGoogle({
    bool rememberDevice = true,
    String? clientId,
    String? serverClientId,
  });

  /// Enters workspace immediately in `Skip Auth (Test Mode)` (`US-07`).
  Future<AuthResult> enterTestMode({
    String identifier = 'test_mode_user',
    WakilUserRole? forcedRole,
  });

  /// Starts account registration (`US-08`) and dispatches SMS OTP when
  /// [sendOtpImmediately] is `true`.
  Future<AuthResult> registerWithDetails({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    bool sendOtpImmediately = true,
  });

  /// Sends a 6-digit SMS OTP to a Nepali phone number (`US-09`).
  Future<OtpDispatchResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 120),
  });

  /// Resends a 6-digit SMS OTP after countdown expiry (`US-10`).
  Future<OtpDispatchResult> resendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 120),
  });

  /// Verifies the 6-digit SMS OTP code (`US-09`, `US-11`) and signs in.
  Future<AuthResult> verifyOtp({
    required String otpCode,
    String? verificationId,
    String? phoneNumber,
    bool rememberDevice = true,
  });

  /// Verifies recovery identity (email or Nepali phone) (`US-12`).
  Future<PasswordRecoveryVerificationResult> verifyRecoveryIdentity(
    String identity,
  );

  /// Updates password after strength validation (`US-12`) and optionally
  /// triggers Global Session Revocation (`US-13`).
  Future<PasswordResetResult> resetPassword({
    required String identity,
    required String newPassword,
    bool revokeAllSessions = true,
  });

  /// Signs out the current user (`US-14`).
  Future<void> signOut({bool clearRememberedDevice = false});
}

class _LocalAccountRecord {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  String password;
  bool phoneVerified;

  _LocalAccountRecord({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.phoneVerified = false,
  });
}

class _PendingRegistration {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;

  const _PendingRegistration({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
  });
}

/// Primary authentication service implementing [WakilAuthRepository].
///
/// Uses live [FirebaseAuth] and [GoogleSignIn] whenever [FirebaseBootstrap]
/// has initialized a live Firebase app, and automatically falls back to a
/// deterministic, hermetic local repository when offline, unconfigured (no
/// `google-services.json` / `firebase_options.dart`), in Test Mode, or running
/// inside `flutter test`.
class AuthService implements WakilAuthRepository {
  /// Default countdown timeout for OTP verification (`US-10`).
  static const Duration defaultOtpTimeout = Duration(seconds: 120);

  static Future<void>? _googleSignInInitFuture;

  final FirebaseAuth? _firebaseAuthOverride;
  final SessionService _sessionService;
  final RoleRoutingService _roleRoutingService;
  final PhoneToEmailResolver? _phoneToEmailResolver;
  final bool _forceLocalFallback;
  final String _fallbackGoogleEmail;
  final String? _expectedTestOtp;

  final StreamController<WakilUser?> _authStateController =
      StreamController<WakilUser?>.broadcast();

  final Map<String, _LocalAccountRecord> _localAccountsByEmail =
      <String, _LocalAccountRecord>{};
  final Map<String, String> _emailByNormalizedPhone = <String, String>{};

  WakilUser? _currentUser;
  _PendingRegistration? _pendingRegistration;
  String? _activeVerificationId;
  String? _activeOtpPhone;
  int? _activeResendToken;

  /// Creates an [AuthService] capable of live Firebase Auth with safe offline
  /// and test fallback.
  AuthService({
    FirebaseAuth? firebaseAuth,
    SessionService? sessionService,
    RoleRoutingService? roleRoutingService,
    this._phoneToEmailResolver,
    this._forceLocalFallback = false,
    this._fallbackGoogleEmail = 'citizen.google@wakil.ai',
    this._expectedTestOtp,
  })  : _firebaseAuthOverride = firebaseAuth,
        _sessionService = sessionService ?? SessionService(),
        _roleRoutingService = roleRoutingService ?? RoleRoutingService();

  /// Convenience constructor locked to deterministic local/offline mode.
  factory AuthService.localFallback({
    SessionService? sessionService,
    RoleRoutingService? roleRoutingService,
    String fallbackGoogleEmail = 'citizen.google@wakil.ai',
    String? expectedTestOtp,
  }) {
    return AuthService(
      sessionService: sessionService ??
          SessionService(store: InMemoryKeyValueStore()),
      roleRoutingService: roleRoutingService ?? RoleRoutingService(),
      forceLocalFallback: true,
      fallbackGoogleEmail: fallbackGoogleEmail,
      expectedTestOtp: expectedTestOtp,
    );
  }

  /// Exposes the underlying [SessionService] used for Remember Device and
  /// Global Session Revocation.
  SessionService get sessionService => _sessionService;

  /// Exposes the underlying [RoleRoutingService] used for Admin/Citizen routing.
  RoleRoutingService get roleRoutingService => _roleRoutingService;

  FirebaseAuth? get _liveAuth {
    if (_forceLocalFallback) {
      return null;
    }
    return _firebaseAuthOverride ?? FirebaseBootstrap.authOrNull;
  }

  @override
  bool get isLiveBackend => _liveAuth != null;

  @override
  WakilUser? get currentUser => _currentUser;

  @override
  Stream<WakilUser?> get authStateChanges => _authStateController.stream;

  /// Validates email format used in Wakil auth forms.
  static bool isValidEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  /// Normalizes and validates a 10-digit Nepali mobile number starting with
  /// `98` or `97`, returning `+977XXXXXXXXXX` or `null` if invalid.
  static String? normalizeNepaliPhone(String input) {
    final cleaned = input
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    if (cleaned.isEmpty) {
      return null;
    }

    String digits = cleaned;
    if (digits.startsWith('+977')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('00977')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('977') && digits.length == 13) {
      digits = digits.substring(3);
    }

    if (!RegExp(r'^(98|97)\d{8}$').hasMatch(digits)) {
      return null;
    }
    return '+977$digits';
  }

  /// Evaluates password strength on a 0-4 scale matching the `US-12` gauge.
  static int evaluatePasswordStrength(String password) {
    if (password.isEmpty) {
      return 0;
    }
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]')) || password.length >= 12) {
      score++;
    }
    return score.clamp(1, 4);
  }

  static bool _looksLikePhoneInput(String input) {
    final stripped = input.trim().replaceAll(RegExp(r'[\s\-()+]'), '');
    return stripped.isNotEmpty && RegExp(r'^\d+$').hasMatch(stripped);
  }

  static String _deterministicUidFor(String identifier) {
    final normalized = identifier.trim().toLowerCase();
    final hash = normalized.codeUnits.fold<int>(
      17,
      (prev, unit) => (prev * 31 + unit) & 0x7fffffff,
    );
    return 'local_${hash.toRadixString(16)}';
  }

  @override
  Future<AuthResult?> restoreSession() async {
    final auth = _liveAuth;
    final remembered = await _sessionService.restoreRememberedSession();

    if (auth != null) {
      try {
        final fbUser = auth.currentUser;
        if (fbUser != null) {
          final identifier =
              fbUser.email ?? fbUser.phoneNumber ?? fbUser.uid;
          final roleResult = await _roleRoutingService.resolveRole(
            identifier: identifier,
            uid: fbUser.uid,
          );
          final session = await _sessionService.saveSession(
            userId: fbUser.uid,
            identifier: identifier,
            email: fbUser.email,
            phoneNumber: fbUser.phoneNumber,
            displayName: fbUser.displayName,
            role: roleResult.role,
            authProvider: fbUser.providerData.isNotEmpty
                ? fbUser.providerData.first.providerId
                : 'firebase',
            rememberDevice: remembered?.rememberDevice ?? true,
          );
          final user = WakilUser.fromSession(session);
          _setCurrentUser(user);
          return AuthResult.success(
            user: user,
            session: session,
            destination: roleResult.destination,
            isFallbackMode: false,
          );
        }
      } catch (error) {
        debugPrint('Wakil AuthService restoreSession live check failed: $error');
      }
    }

    if (remembered != null) {
      final user = WakilUser.fromSession(remembered);
      final destination = _roleRoutingService.destinationForRole(user.role);
      _setCurrentUser(user);
      return AuthResult.success(
        user: user,
        session: remembered,
        destination: destination,
        isFallbackMode: true,
      );
    }

    return null;
  }

  @override
  Future<AuthResult> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
    bool rememberDevice = true,
  }) async {
    final cleanInput = identifier.trim();
    if (cleanInput.isEmpty) {
      return AuthResult.failure(
        errorCode: 'empty-identifier',
        message: 'Please enter your email or Nepali mobile number.',
        isFallbackMode: !isLiveBackend,
      );
    }

    if (password.length < 6) {
      return AuthResult.failure(
        errorCode: 'weak-password',
        message: 'Password must be at least 6 characters.',
        isFallbackMode: !isLiveBackend,
      );
    }

    final isEmail = isValidEmail(cleanInput);
    final normalizedPhone = normalizeNepaliPhone(cleanInput);

    if (!isEmail && normalizedPhone == null) {
      if (_looksLikePhoneInput(cleanInput)) {
        return AuthResult.failure(
          errorCode: 'invalid-phone-number',
          message:
              'Please enter a valid 10-digit Nepali mobile number (starts with 98 or 97).',
          isFallbackMode: !isLiveBackend,
        );
      }
      return AuthResult.failure(
        errorCode: 'invalid-identifier',
        message: 'Please enter a valid email address or Nepali mobile number.',
        isFallbackMode: !isLiveBackend,
      );
    }

    final auth = _liveAuth;
    if (auth != null) {
      try {
        String? emailToSignIn = isEmail ? cleanInput : null;
        if (emailToSignIn == null && normalizedPhone != null) {
          emailToSignIn = _emailByNormalizedPhone[normalizedPhone];
          if (emailToSignIn == null && _phoneToEmailResolver != null) {
            emailToSignIn = await _phoneToEmailResolver(normalizedPhone);
          }
          if (emailToSignIn == null) {
            return AuthResult.failure(
              errorCode: 'phone-email-mapping-required',
              message:
                  'Please sign in with your registered email address or verify via SMS OTP.',
              isFallbackMode: false,
            );
          }
        }

        final credential = await auth.signInWithEmailAndPassword(
          email: emailToSignIn!,
          password: password,
        );
        final fbUser = credential.user;
        final canonicalIdentifier =
            fbUser?.email ?? cleanInput;
        final uid = fbUser?.uid ?? _deterministicUidFor(canonicalIdentifier);

        return await _completeSignIn(
          uid: uid,
          identifier: canonicalIdentifier,
          email: fbUser?.email ?? emailToSignIn,
          phoneNumber: fbUser?.phoneNumber ?? normalizedPhone,
          displayName: fbUser?.displayName,
          providerId: 'password',
          rememberDevice: rememberDevice,
          isFallbackMode: false,
        );
      } on FirebaseAuthException catch (e) {
        return AuthResult.failure(
          errorCode: e.code,
          message: _mapFirebaseAuthError(e),
          isFallbackMode: false,
        );
      } catch (e) {
        return AuthResult.failure(
          errorCode: 'auth-error',
          message: 'Sign in failed: $e',
          isFallbackMode: false,
        );
      }
    }

    // Deterministic local/offline fallback
    final lookupEmail = isEmail
        ? cleanInput.toLowerCase()
        : _emailByNormalizedPhone[normalizedPhone!];
    final localAccount =
        lookupEmail != null ? _localAccountsByEmail[lookupEmail] : null;

    if (localAccount != null && localAccount.password != password) {
      return AuthResult.failure(
        errorCode: 'wrong-password',
        message: 'Incorrect password for $cleanInput.',
        isFallbackMode: true,
      );
    }

    final canonicalIdentifier = localAccount?.email ??
        (isEmail ? cleanInput : normalizedPhone!);
    return _completeSignIn(
      uid: localAccount?.uid ?? _deterministicUidFor(canonicalIdentifier),
      identifier: canonicalIdentifier,
      email: localAccount?.email ?? (isEmail ? cleanInput : null),
      phoneNumber: localAccount?.phoneNumber ?? normalizedPhone,
      displayName: localAccount?.fullName,
      providerId: 'password',
      rememberDevice: rememberDevice,
      isFallbackMode: true,
    );
  }

  @override
  Future<AuthResult> signInWithGoogle({
    bool rememberDevice = true,
    String? clientId,
    String? serverClientId,
  }) async {
    final auth = _liveAuth;
    if (auth == null) {
      return _completeSignIn(
        uid: _deterministicUidFor(_fallbackGoogleEmail),
        identifier: _fallbackGoogleEmail,
        email: _fallbackGoogleEmail,
        displayName: 'Wakil Google User',
        providerId: 'google.com',
        rememberDevice: rememberDevice,
        isFallbackMode: true,
        message: 'Signed in with Google (local fallback mode).',
      );
    }

    try {
      await _ensureGoogleSignInInitialized(
        clientId: clientId,
        serverClientId: serverClientId,
      );

      final googleSignIn = GoogleSignIn.instance;
      if (!googleSignIn.supportsAuthenticate()) {
        return AuthResult.failure(
          errorCode: 'google-signin-unsupported',
          message:
              'Interactive Google Sign-In is not supported on this platform.',
          isFallbackMode: false,
        );
      }

      final GoogleSignInAccount account = await googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      String? accessToken;
      if (idToken == null) {
        final authz = await account.authorizationClient.authorizationForScopes(
          const <String>['email', 'profile'],
        );
        accessToken = authz?.accessToken;
      }

      if (idToken == null && accessToken == null) {
        return AuthResult.failure(
          errorCode: 'missing-google-token',
          message: 'Google Sign-In did not return an ID or access token.',
          isFallbackMode: false,
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      final userCred = await auth.signInWithCredential(credential);
      final fbUser = userCred.user;
      final email = fbUser?.email ?? account.email;
      final uid = fbUser?.uid ?? _deterministicUidFor(email);

      return await _completeSignIn(
        uid: uid,
        identifier: email,
        email: email,
        phoneNumber: fbUser?.phoneNumber,
        displayName: fbUser?.displayName ?? account.displayName,
        providerId: 'google.com',
        rememberDevice: rememberDevice,
        isFallbackMode: false,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AuthResult.failure(
          errorCode: 'canceled',
          message: 'Google sign-in was canceled.',
          isFallbackMode: false,
        );
      }
      return AuthResult.failure(
        errorCode: e.code.name,
        message: e.description ?? 'Google sign-in failed (${e.code.name}).',
        isFallbackMode: false,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        message: _mapFirebaseAuthError(e),
        isFallbackMode: false,
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'google-signin-error',
        message: 'Google sign-in failed: $e',
        isFallbackMode: false,
      );
    }
  }

  static Future<void> _ensureGoogleSignInInitialized({
    String? clientId,
    String? serverClientId,
  }) {
    return _googleSignInInitFuture ??= GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  @override
  Future<AuthResult> enterTestMode({
    String identifier = 'test_mode_user',
    WakilUserRole? forcedRole,
  }) async {
    final cleanId = identifier.trim().isEmpty
        ? 'test_mode_user'
        : identifier.trim();
    final roleResult = forcedRole != null
        ? RoleResolutionResult(
            role: forcedRole,
            destination: _roleRoutingService.destinationForRole(forcedRole),
            source: 'forced_test_role',
          )
        : await _roleRoutingService.resolveRole(
            identifier: cleanId,
            isTestMode: true,
            allowFirestoreLookup: false,
          );

    final session = await _sessionService.saveSession(
      userId: _deterministicUidFor(cleanId),
      identifier: cleanId,
      email: cleanId.contains('@') ? cleanId : null,
      displayName: 'Test Mode User',
      role: roleResult.role,
      authProvider: 'test_mode',
      rememberDevice: false,
      isTestMode: true,
    );

    final user = WakilUser.fromSession(session);
    _setCurrentUser(user);

    return AuthResult.success(
      user: user,
      session: session,
      destination: roleResult.destination,
      isFallbackMode: true,
      message: 'Entered Wakil in Test Mode.',
    );
  }

  @override
  Future<AuthResult> registerWithDetails({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    bool sendOtpImmediately = true,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();
    final normalizedPhone = normalizeNepaliPhone(phoneNumber);

    if (cleanName.isEmpty) {
      return AuthResult.failure(
        errorCode: 'invalid-name',
        message: 'Full Name is required.',
        isFallbackMode: !isLiveBackend,
      );
    }

    if (!isValidEmail(cleanEmail)) {
      return AuthResult.failure(
        errorCode: 'invalid-email',
        message: 'Please enter a valid email address.',
        isFallbackMode: !isLiveBackend,
      );
    }

    if (normalizedPhone == null) {
      return AuthResult.failure(
        errorCode: 'invalid-phone-number',
        message:
            'Please enter a valid 10-digit Nepali mobile number (starts with 98 or 97).',
        isFallbackMode: !isLiveBackend,
      );
    }

    if (password.length < 6) {
      return AuthResult.failure(
        errorCode: 'weak-password',
        message: 'Password must be at least 6 characters.',
        isFallbackMode: !isLiveBackend,
      );
    }

    final auth = _liveAuth;
    if (auth != null) {
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        final fbUser = cred.user;
        if (fbUser != null) {
          await fbUser.updateDisplayName(cleanName);
        }

        _pendingRegistration = _PendingRegistration(
          fullName: cleanName,
          email: cleanEmail,
          phoneNumber: normalizedPhone,
          password: password,
        );
        _emailByNormalizedPhone[normalizedPhone] = cleanEmail.toLowerCase();

        String? verificationId;
        if (sendOtpImmediately) {
          final otpResult = await sendOtp(phoneNumber: normalizedPhone);
          verificationId = otpResult.verificationId;
        }

        final roleResult = await _roleRoutingService.resolveRole(
          identifier: cleanEmail,
          uid: fbUser?.uid,
        );
        final session = await _sessionService.saveSession(
          userId: fbUser?.uid ?? _deterministicUidFor(cleanEmail),
          identifier: cleanEmail,
          email: cleanEmail,
          phoneNumber: normalizedPhone,
          displayName: cleanName,
          role: roleResult.role,
          authProvider: 'password',
          rememberDevice: true,
        );
        final user = WakilUser.fromSession(session);
        _setCurrentUser(user);

        return AuthResult.success(
          user: user,
          session: session,
          destination: roleResult.destination,
          isFallbackMode: false,
          requiresOtpVerification: true,
          verificationId: verificationId,
          message: 'Account created. Verification OTP sent to $normalizedPhone.',
        );
      } on FirebaseAuthException catch (e) {
        return AuthResult.failure(
          errorCode: e.code,
          message: _mapFirebaseAuthError(e),
          isFallbackMode: false,
        );
      } catch (e) {
        return AuthResult.failure(
          errorCode: 'registration-failed',
          message: 'Registration failed: $e',
          isFallbackMode: false,
        );
      }
    }

    // Deterministic local/offline registration
    final emailKey = cleanEmail.toLowerCase();
    if (_localAccountsByEmail.containsKey(emailKey)) {
      return AuthResult.failure(
        errorCode: 'email-already-in-use',
        message: 'An account already exists for $cleanEmail.',
        isFallbackMode: true,
      );
    }

    _pendingRegistration = _PendingRegistration(
      fullName: cleanName,
      email: cleanEmail,
      phoneNumber: normalizedPhone,
      password: password,
    );

    String? verificationId;
    if (sendOtpImmediately) {
      final otpResult = await sendOtp(phoneNumber: normalizedPhone);
      verificationId = otpResult.verificationId;
    }

    final uid = _deterministicUidFor(cleanEmail);
    final roleResult = await _roleRoutingService.resolveRole(
      identifier: cleanEmail,
      uid: uid,
      allowFirestoreLookup: false,
    );
    final session = await _sessionService.saveSession(
      userId: uid,
      identifier: cleanEmail,
      email: cleanEmail,
      phoneNumber: normalizedPhone,
      displayName: cleanName,
      role: roleResult.role,
      authProvider: 'password',
      rememberDevice: true,
    );
    final user = WakilUser.fromSession(session);
    _setCurrentUser(user);

    return AuthResult.success(
      user: user,
      session: session,
      destination: roleResult.destination,
      isFallbackMode: true,
      requiresOtpVerification: true,
      verificationId: verificationId,
      message: 'Account registered locally; proceed with OTP verification.',
    );
  }

  @override
  Future<OtpDispatchResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = defaultOtpTimeout,
  }) async {
    final normalizedPhone = normalizeNepaliPhone(phoneNumber);
    if (normalizedPhone == null) {
      return OtpDispatchResult(
        isSuccess: false,
        phoneNumber: phoneNumber,
        verificationId: '',
        timeout: timeout,
        isFallbackMode: !isLiveBackend,
        errorCode: 'invalid-phone-number',
        message:
            'Please enter a valid 10-digit Nepali mobile number (starts with 98 or 97).',
      );
    }

    _activeOtpPhone = normalizedPhone;
    final auth = _liveAuth;
    if (auth == null) {
      final localId =
          'local-otp-${normalizedPhone.replaceAll('+', '')}-${DateTime.now().millisecondsSinceEpoch}';
      _activeVerificationId = localId;
      return OtpDispatchResult(
        isSuccess: true,
        phoneNumber: normalizedPhone,
        verificationId: localId,
        timeout: timeout,
        isFallbackMode: true,
        message: 'A 6-digit security OTP was sent to $normalizedPhone.',
      );
    }

    final completer = Completer<OtpDispatchResult>();
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: timeout,
        forceResendingToken: forceResendingToken ?? _activeResendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!completer.isCompleted) {
            completer.complete(
              OtpDispatchResult(
                isSuccess: true,
                phoneNumber: normalizedPhone,
                verificationId:
                    _activeVerificationId ?? 'auto-verified-$normalizedPhone',
                timeout: timeout,
                autoVerified: true,
                isFallbackMode: false,
                message: 'Phone number automatically verified.',
              ),
            );
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!completer.isCompleted) {
            completer.complete(
              OtpDispatchResult(
                isSuccess: false,
                phoneNumber: normalizedPhone,
                verificationId: '',
                timeout: timeout,
                isFallbackMode: false,
                errorCode: error.code,
                message: _mapFirebaseAuthError(error),
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _activeVerificationId = verificationId;
          _activeResendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(
              OtpDispatchResult(
                isSuccess: true,
                phoneNumber: normalizedPhone,
                verificationId: verificationId,
                resendToken: resendToken,
                timeout: timeout,
                isFallbackMode: false,
                message:
                    'A new 6-digit security OTP was sent to $normalizedPhone.',
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _activeVerificationId = verificationId;
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => OtpDispatchResult(
          isSuccess: false,
          phoneNumber: normalizedPhone,
          verificationId: '',
          timeout: timeout,
          isFallbackMode: false,
          errorCode: 'otp-dispatch-timeout',
          message: 'Timed out waiting for SMS verification dispatch.',
        ),
      );
    } catch (error) {
      // Certain desktop/test platforms throw UnimplementedError for phone auth.
      final localId =
          'local-otp-${normalizedPhone.replaceAll('+', '')}-${DateTime.now().millisecondsSinceEpoch}';
      _activeVerificationId = localId;
      return OtpDispatchResult(
        isSuccess: true,
        phoneNumber: normalizedPhone,
        verificationId: localId,
        timeout: timeout,
        isFallbackMode: true,
        message: 'OTP prepared in fallback mode for $normalizedPhone ($error).',
      );
    }
  }

  @override
  Future<OtpDispatchResult> resendOtp({
    required String phoneNumber,
    Duration timeout = defaultOtpTimeout,
  }) {
    return sendOtp(
      phoneNumber: phoneNumber,
      forceResendingToken: _activeResendToken,
      timeout: timeout,
    );
  }

  @override
  Future<AuthResult> verifyOtp({
    required String otpCode,
    String? verificationId,
    String? phoneNumber,
    bool rememberDevice = true,
  }) async {
    final cleanCode = otpCode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      return AuthResult.failure(
        errorCode: 'invalid-otp-format',
        message: 'Please enter all 6 digits of the OTP code.',
        isFallbackMode: !isLiveBackend,
      );
    }

    final resolvedVerificationId = verificationId ?? _activeVerificationId;
    final resolvedPhone = (phoneNumber != null
            ? normalizeNepaliPhone(phoneNumber)
            : null) ??
        _activeOtpPhone ??
        _pendingRegistration?.phoneNumber;

    final auth = _liveAuth;
    final isRealFirebaseVerification = auth != null &&
        resolvedVerificationId != null &&
        resolvedVerificationId.isNotEmpty &&
        !resolvedVerificationId.startsWith('local-otp-') &&
        !resolvedVerificationId.startsWith('auto-verified-');

    if (isRealFirebaseVerification) {
      try {
        final phoneCredential = PhoneAuthProvider.credential(
          verificationId: resolvedVerificationId,
          smsCode: cleanCode,
        );

        final existingUser = auth.currentUser;
        User? fbUser;
        if (existingUser != null) {
          await existingUser.updatePhoneNumber(phoneCredential);
          await existingUser.reload();
          fbUser = auth.currentUser ?? existingUser;
        } else {
          final cred = await auth.signInWithCredential(phoneCredential);
          fbUser = cred.user;
        }

        final pending = _pendingRegistration;
        _pendingRegistration = null;
        final canonicalIdentifier = fbUser?.email ??
            pending?.email ??
            fbUser?.phoneNumber ??
            resolvedPhone ??
            fbUser?.uid ??
            '';

        return await _completeSignIn(
          uid: fbUser?.uid ?? _deterministicUidFor(canonicalIdentifier),
          identifier: canonicalIdentifier,
          email: fbUser?.email ?? pending?.email,
          phoneNumber:
              fbUser?.phoneNumber ?? resolvedPhone ?? pending?.phoneNumber,
          displayName: fbUser?.displayName ?? pending?.fullName,
          providerId: 'phone',
          rememberDevice: rememberDevice,
          isFallbackMode: false,
        );
      } on FirebaseAuthException catch (e) {
        return AuthResult.failure(
          errorCode: e.code,
          message: _mapFirebaseAuthError(e),
          isFallbackMode: false,
        );
      } catch (e) {
        return AuthResult.failure(
          errorCode: 'otp-verification-failed',
          message: 'OTP verification failed: $e',
          isFallbackMode: false,
        );
      }
    }

    // Local/test OTP verification
    if (_expectedTestOtp != null && cleanCode != _expectedTestOtp) {
      return AuthResult.failure(
        errorCode: 'invalid-verification-code',
        message: 'Invalid 6-digit OTP verification code.',
        isFallbackMode: true,
      );
    }

    final pending = _pendingRegistration;
    if (pending != null) {
      final uid = _deterministicUidFor(pending.email);
      _localAccountsByEmail[pending.email.toLowerCase()] = _LocalAccountRecord(
        uid: uid,
        fullName: pending.fullName,
        email: pending.email,
        phoneNumber: pending.phoneNumber,
        password: pending.password,
        phoneVerified: true,
      );
      _emailByNormalizedPhone[pending.phoneNumber] =
          pending.email.toLowerCase();
      _pendingRegistration = null;

      return _completeSignIn(
        uid: uid,
        identifier: pending.email,
        email: pending.email,
        phoneNumber: pending.phoneNumber,
        displayName: pending.fullName,
        providerId: 'phone',
        rememberDevice: rememberDevice,
        isFallbackMode: true,
      );
    }

    final fallbackIdentifier = _currentUser?.identifier ??
        resolvedPhone ??
        'citizen@wakil.ai';
    return _completeSignIn(
      uid: _currentUser?.uid ?? _deterministicUidFor(fallbackIdentifier),
      identifier: fallbackIdentifier,
      email: _currentUser?.email,
      phoneNumber: resolvedPhone ?? _currentUser?.phoneNumber,
      displayName: _currentUser?.displayName,
      providerId: 'phone',
      rememberDevice: rememberDevice,
      isFallbackMode: true,
    );
  }

  @override
  Future<PasswordRecoveryVerificationResult> verifyRecoveryIdentity(
    String identity,
  ) async {
    final clean = identity.trim();
    if (clean.isEmpty) {
      return const PasswordRecoveryVerificationResult(
        isSuccess: false,
        normalizedIdentity: '',
        isEmailIdentity: false,
        isFallbackMode: true,
        errorCode: 'empty-identity',
        message: 'Please enter your registered email or phone.',
      );
    }

    final isEmail = isValidEmail(clean);
    final normalizedPhone = normalizeNepaliPhone(clean);

    if (!isEmail && normalizedPhone == null) {
      return PasswordRecoveryVerificationResult(
        isSuccess: false,
        normalizedIdentity: clean,
        isEmailIdentity: false,
        isFallbackMode: !isLiveBackend,
        errorCode: 'invalid-identity',
        message: 'Please enter a valid email address or Nepali mobile number.',
      );
    }

    final normalized = isEmail ? clean : normalizedPhone!;
    return PasswordRecoveryVerificationResult(
      isSuccess: true,
      normalizedIdentity: normalized,
      isEmailIdentity: isEmail,
      isFallbackMode: !isLiveBackend,
      message:
          'Identity verified for $normalized. Please set your new password.',
    );
  }

  @override
  Future<PasswordResetResult> resetPassword({
    required String identity,
    required String newPassword,
    bool revokeAllSessions = true,
  }) async {
    final verification = await verifyRecoveryIdentity(identity);
    if (!verification.isSuccess) {
      return PasswordResetResult(
        isSuccess: false,
        normalizedIdentity: verification.normalizedIdentity,
        sessionsRevoked: false,
        isFallbackMode: verification.isFallbackMode,
        errorCode: verification.errorCode,
        message: verification.message,
      );
    }

    if (evaluatePasswordStrength(newPassword) < 2) {
      return PasswordResetResult(
        isSuccess: false,
        normalizedIdentity: verification.normalizedIdentity,
        sessionsRevoked: false,
        isFallbackMode: !isLiveBackend,
        errorCode: 'weak-password',
        message:
            'Password is too weak. Please use at least 8 characters with letters and numbers.',
      );
    }

    final auth = _liveAuth;
    if (auth != null) {
      try {
        final fbUser = auth.currentUser;
        if (fbUser != null &&
            ((verification.isEmailIdentity &&
                    fbUser.email?.toLowerCase() ==
                        verification.normalizedIdentity.toLowerCase()) ||
                (!verification.isEmailIdentity &&
                    fbUser.phoneNumber == verification.normalizedIdentity))) {
          await fbUser.updatePassword(newPassword);
        } else if (verification.isEmailIdentity) {
          await auth.sendPasswordResetEmail(
            email: verification.normalizedIdentity,
          );
        } else {
          final mappedEmail =
              _emailByNormalizedPhone[verification.normalizedIdentity] ??
                  await _phoneToEmailResolver?.call(
                    verification.normalizedIdentity,
                  );
          if (mappedEmail != null) {
            await auth.sendPasswordResetEmail(email: mappedEmail);
          } else {
            return PasswordResetResult(
              isSuccess: false,
              normalizedIdentity: verification.normalizedIdentity,
              sessionsRevoked: false,
              isFallbackMode: false,
              errorCode: 'phone-reset-requires-email',
              message:
                  'Live Firebase password reset requires your registered email address.',
            );
          }
        }

        if (revokeAllSessions) {
          await _sessionService.revokeAllSessions(
            identity: verification.normalizedIdentity,
            firebaseAuth: auth,
          );
          _setCurrentUser(null);
        }

        return PasswordResetResult(
          isSuccess: true,
          normalizedIdentity: verification.normalizedIdentity,
          sessionsRevoked: revokeAllSessions,
          isFallbackMode: false,
          message: revokeAllSessions
              ? 'Password updated and all device sessions revoked.'
              : 'Password updated successfully.',
        );
      } on FirebaseAuthException catch (e) {
        return PasswordResetResult(
          isSuccess: false,
          normalizedIdentity: verification.normalizedIdentity,
          sessionsRevoked: false,
          isFallbackMode: false,
          errorCode: e.code,
          message: _mapFirebaseAuthError(e),
        );
      } catch (e) {
        return PasswordResetResult(
          isSuccess: false,
          normalizedIdentity: verification.normalizedIdentity,
          sessionsRevoked: false,
          isFallbackMode: false,
          errorCode: 'password-reset-failed',
          message: 'Failed to update password: $e',
        );
      }
    }

    // Local/offline fallback password update
    final emailKey = verification.isEmailIdentity
        ? verification.normalizedIdentity.toLowerCase()
        : _emailByNormalizedPhone[verification.normalizedIdentity];
    if (emailKey != null) {
      final existing = _localAccountsByEmail[emailKey];
      if (existing != null) {
        existing.password = newPassword;
      } else {
        _localAccountsByEmail[emailKey] = _LocalAccountRecord(
          uid: _deterministicUidFor(emailKey),
          fullName: 'Wakil User',
          email: emailKey,
          phoneNumber: '',
          password: newPassword,
        );
      }
    }

    if (revokeAllSessions) {
      await _sessionService.revokeAllSessions(
        identity: verification.normalizedIdentity,
      );
      _setCurrentUser(null);
    }

    return PasswordResetResult(
      isSuccess: true,
      normalizedIdentity: verification.normalizedIdentity,
      sessionsRevoked: revokeAllSessions,
      isFallbackMode: true,
      message: revokeAllSessions
          ? 'Password updated and all active sessions revoked.'
          : 'Password updated successfully.',
    );
  }

  @override
  Future<void> signOut({bool clearRememberedDevice = false}) async {
    final auth = _liveAuth;
    if (auth != null) {
      try {
        if (auth.currentUser != null) {
          await auth.signOut();
        }
      } catch (error) {
        debugPrint('Wakil AuthService Firebase signOut warning: $error');
      }
    }

    if (_googleSignInInitFuture != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Wakil AuthService Google signOut warning: $error');
      }
    }

    _pendingRegistration = null;
    _activeVerificationId = null;
    _activeOtpPhone = null;

    await _sessionService.clearCurrentSession(
      preserveRememberedIdentifier: !clearRememberedDevice,
    );
    _setCurrentUser(null);
  }

  Future<AuthResult> _completeSignIn({
    required String uid,
    required String identifier,
    required String providerId,
    required bool rememberDevice,
    required bool isFallbackMode,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? message,
  }) async {
    final roleResult = await _roleRoutingService.resolveRole(
      identifier: identifier,
      uid: uid,
      allowFirestoreLookup: !isFallbackMode,
    );

    final session = await _sessionService.saveSession(
      userId: uid,
      identifier: identifier,
      email: email,
      phoneNumber: phoneNumber,
      displayName: displayName,
      role: roleResult.role,
      authProvider: providerId,
      rememberDevice: rememberDevice,
      isTestMode: false,
    );

    final user = WakilUser.fromSession(session);
    _setCurrentUser(user);

    return AuthResult.success(
      user: user,
      session: session,
      destination: roleResult.destination,
      isFallbackMode: isFallbackMode,
      message: message,
    );
  }

  void _setCurrentUser(WakilUser? user) {
    _currentUser = user;
    if (!_authStateController.isClosed) {
      _authStateController.add(user);
    }
  }

  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This Wakil account has been suspended or disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'weak-password':
        return 'Password does not meet security requirements.';
      case 'invalid-verification-code':
        return 'The 6-digit verification code is incorrect.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new OTP.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait briefly before retrying.';
      case 'network-request-failed':
        return 'Network unavailable. Check your internet connection.';
      default:
        return e.message ?? 'Authentication error (${e.code}).';
    }
  }

  /// Disposes internal resources.
  Future<void> dispose() async {
    await _authStateController.close();
  }
}
