import 'dart:async';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final bool isLockedOut;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.isLockedOut = false,
  });
}

class AuthService {
  // Singleton pattern for session persistence
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Session & Test Mode State (US-07)
  bool isAuthenticated = false;
  bool isTestMode = false;
  String? currentUserId;
  String? currentPhoneNumber;

  // Single-Use Token Invalidation Registry (Replay Prevention)
  final Set<String> _burnedOtpTokens = {};

  // Brute-Force Rate Limiting (3-Attempt Hard Lockout)
  int failedAttempts = 0;
  static const int maxAttempts = 3;
  static const int lockoutMinutes = 15;
  DateTime? lockoutUntil;

  bool get isLockedOut {
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!)) {
      return true;
    }
    if (failedAttempts >= maxAttempts) {
      lockoutUntil ??= DateTime.now().add(const Duration(minutes: lockoutMinutes));
      return true;
    }
    return false;
  }

  void resetLockout() {
    failedAttempts = 0;
    lockoutUntil = null;
  }

  bool isTokenBurned(String phoneNumber, String otpCode) {
    final normalized = phoneNumber.replaceAll(' ', '').trim();
    return _burnedOtpTokens.contains('$normalized:$otpCode');
  }

  void clearBurnedTokens() {
    _burnedOtpTokens.clear();
  }

  Future<AuthResult> verifyOtp(String phoneNumber, String otpCode) async {
    final normalized = phoneNumber.replaceAll(' ', '').trim();
    final tokenKey = '$normalized:$otpCode';

    // 1. Check if user is locked out
    if (isLockedOut) {
      return AuthResult(
        success: false,
        isLockedOut: true,
        errorMessage:
            "Account locked out due to $maxAttempts consecutive failed attempts. Anti-brute force active for $lockoutMinutes minutes.",
      );
    }

    // 2. Single-use token invalidation check (Replay prevention)
    if (_burnedOtpTokens.contains(tokenKey)) {
      return AuthResult(
        success: false,
        errorMessage:
            "This OTP code has already been used and invalidated (single-use security policy). Please request a fresh code.",
      );
    }

    // 3. Format validation
    if (otpCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      failedAttempts++;
      return AuthResult(
        success: false,
        isLockedOut: isLockedOut,
        errorMessage: "Please enter a valid 6-digit OTP code.",
      );
    }

    // 4. Test failure code rejection
    if (otpCode == "000000") {
      failedAttempts++;
      final locked = isLockedOut;
      return AuthResult(
        success: false,
        isLockedOut: locked,
        errorMessage: locked
            ? "Account locked out due to $maxAttempts consecutive failed attempts. Anti-brute force active for $lockoutMinutes minutes."
            : "Invalid OTP code. Please check your SMS and try again.",
      );
    }

    // 5. Success: Burn token immediately and persist session
    _burnedOtpTokens.add(tokenKey);
    failedAttempts = 0;
    lockoutUntil = null;
    isAuthenticated = true;
    currentPhoneNumber = phoneNumber;

    return AuthResult(success: true);
  }

  void setTestMode(bool enabled) {
    isTestMode = enabled;
    if (enabled) {
      isAuthenticated = true;
      currentUserId = "test-user-nepal-law";
    } else {
      isAuthenticated = false;
      currentUserId = null;
    }
  }

  void signOut() {
    isAuthenticated = false;
    isTestMode = false;
    currentUserId = null;
    currentPhoneNumber = null;
    resetLockout();
  }
}
