import 'dart:async';

import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'services/services.dart';
import 'view/authentication/login_screen.dart';
import 'view/authentication/otp_verification_screen.dart';
import 'view/authentication/password_recovery_screen.dart';
import 'view/authentication/registration_screen.dart';
import 'view/dashboard/admin_workspace_screen.dart';
import 'view/dashboard/main_workspace_screen.dart';
import 'view/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeSafely();
  runApp(const WakilApp());
}

enum AppRouteState {
  splash,
  login,
  registration,
  otpVerification,
  passwordRecovery,
  adminWorkspace,
  mainWorkspace,
}

class WakilApp extends StatefulWidget {
  final AppRouteState initialRoute;
  final AuthService? authService;

  const WakilApp({
    super.key,
    this.initialRoute = AppRouteState.splash,
    this.authService,
  });

  @override
  State<WakilApp> createState() => _WakilAppState();
}

class _WakilAppState extends State<WakilApp> {
  late final AuthService _authService;
  late final bool _ownsAuthService;
  late AppRouteState _currentRoute;
  String _userIdentifier = 'citizen@wakil.gov.np';
  String _registeredPhone = '+977 9841234567';
  Future<void> _pendingAuthTask = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _ownsAuthService = widget.authService == null;
    _authService = widget.authService ?? AuthService();
    _currentRoute = widget.initialRoute;
  }

  @override
  void dispose() {
    if (_ownsAuthService) {
      unawaited(
        _pendingAuthTask.whenComplete(() => _authService.dispose()),
      );
    }
    super.dispose();
  }

  void _runBackground(Future<void> Function() action) {
    _pendingAuthTask = _pendingAuthTask.then((_) async {
      try {
        await action();
      } catch (error) {
        debugPrint('Wakil background auth/session task warning: $error');
      }
    });
    unawaited(_pendingAuthTask);
  }

  void _routeToWorkspace(String identifier) {
    final isAdmin =
        _authService.roleRoutingService.isAdminIdentifier(identifier);
    setState(() {
      _userIdentifier = identifier;
      _currentRoute = isAdmin
          ? AppRouteState.adminWorkspace
          : AppRouteState.mainWorkspace;
    });
  }

  void _handleAuthenticatedNavigation(
    String identifier, {
    required String authProvider,
  }) {
    _routeToWorkspace(identifier);
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return;
    }
    _runBackground(() async {
      if (_authService.currentUser?.identifier.toLowerCase() ==
              cleanId.toLowerCase() &&
          _authService.sessionService.isAuthenticated) {
        return;
      }
      final role = _authService.roleRoutingService.resolveRoleSync(cleanId);
      final isEmail = AuthService.isValidEmail(cleanId);
      final normalizedPhone = AuthService.normalizeNepaliPhone(cleanId);
      await _authService.sessionService.saveSession(
        userId: 'wakil_${cleanId.toLowerCase()}',
        identifier: cleanId,
        email: isEmail ? cleanId : null,
        phoneNumber: normalizedPhone,
        role: role,
        authProvider: authProvider,
        rememberDevice: _authService.sessionService.rememberDeviceEnabled,
      );
    });
  }

  void _enterTestMode([String identifier = 'test_mode_user']) {
    _routeToWorkspace(identifier);
    _runBackground(() => _authService.enterTestMode(identifier: identifier));
  }

  ThemeData _buildLightMonochromeTheme() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primaryBlack,
      onPrimary: AppColors.surfacePure,
      secondary: AppColors.textSecondary,
      onSecondary: AppColors.surfacePure,
      surface: AppColors.surfacePure,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.surfacePure,
      surfaceContainerLow: AppColors.surfaceLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      onSurfaceVariant: AppColors.textOnVariant,
      outline: AppColors.textMuted,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.crimsonError,
      onError: AppColors.surfacePure,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surfacePure,
      primaryColor: AppColors.primaryBlack,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfacePure,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlack,
          foregroundColor: AppColors.surfacePure,
          disabledBackgroundColor: AppColors.surfaceHighest,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.surfaceHighest),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlack,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLow,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textOnVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlack,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.crimsonError,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.crimsonError,
            width: 1.5,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBlack;
          }
          return AppColors.surfacePure;
        }),
        checkColor: WidgetStateProperty.all(AppColors.surfacePure),
        side: const BorderSide(color: AppColors.textMuted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surfacePure;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBlack;
          }
          return AppColors.surfaceHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceHighest,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfacePure,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wakil - Legal Intelligence',
      theme: _buildLightMonochromeTheme(),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentRoute) {
      case AppRouteState.splash:
        return SplashScreen(
          onContinueToAuth: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
            _runBackground(
              () => _authService.sessionService.setDisclaimerAccepted(true),
            );
          },
          onSkipAuth: () {
            _enterTestMode();
          },
        );

      case AppRouteState.login:
        return LoginScreen(
          onToRegistration: () {
            setState(() {
              _currentRoute = AppRouteState.registration;
            });
          },
          onToForgotPassword: () {
            setState(() {
              _currentRoute = AppRouteState.passwordRecovery;
            });
          },
          onLoginSuccess: (email) {
            _handleAuthenticatedNavigation(email, authProvider: 'password');
          },
          onSkipAuth: () {
            _enterTestMode();
          },
        );

      case AppRouteState.registration:
        return RegistrationScreen(
          onToSignIn: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
          },
          onRegistrationSuccess: (fullName, email, phone, password) {
            setState(() {
              _registeredPhone = phone;
              _userIdentifier = email;
              _currentRoute = AppRouteState.otpVerification;
            });
          },
        );

      case AppRouteState.otpVerification:
        return OtpVerificationScreen(
          phoneNumber: _registeredPhone,
          onBack: () {
            setState(() {
              _currentRoute = AppRouteState.registration;
            });
          },
          onOtpVerified: () {
            _handleAuthenticatedNavigation(
              _userIdentifier,
              authProvider: 'phone',
            );
          },
        );

      case AppRouteState.passwordRecovery:
        return PasswordRecoveryScreen(
          onBack: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
          },
          onResetSuccess: (identity, newPassword, revokeAllSessions) {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
            _runBackground(() async {
              final result = await _authService.resetPassword(
                identity: identity,
                newPassword: newPassword,
                revokeAllSessions: revokeAllSessions,
              );
              if (revokeAllSessions && !result.sessionsRevoked) {
                await _authService.sessionService.revokeAllSessions(
                  identity: identity,
                );
              }
            });
          },
        );

      case AppRouteState.adminWorkspace:
        return AdminWorkspaceScreen(
          userEmail: _userIdentifier,
          onSignOut: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
            _runBackground(() => _authService.signOut());
          },
        );

      case AppRouteState.mainWorkspace:
        return MainWorkspaceScreen(
          userIdentifier: _userIdentifier,
          onSignOut: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
            _runBackground(() => _authService.signOut());
          },
        );
    }
  }
}
