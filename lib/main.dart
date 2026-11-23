import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'view/onboarding/splash_screen.dart';
import 'view/authentication/login_screen.dart';
import 'view/authentication/registration_screen.dart';
import 'view/authentication/otp_verification_screen.dart';
import 'view/authentication/password_recovery_screen.dart';
import 'view/dashboard/admin_workspace_screen.dart';
import 'view/dashboard/main_workspace_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  const WakilApp({
    super.key,
    this.initialRoute = AppRouteState.splash,
  });

  @override
  State<WakilApp> createState() => _WakilAppState();
}

class _WakilAppState extends State<WakilApp> {
  late AppRouteState _currentRoute;
  String _userIdentifier = 'citizen@wakil.gov.np';
  String _registeredPhone = '+977 9841234567';

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
  }

  bool _isAdmin(String email) {
    final clean = email.toLowerCase().trim();
    return clean.contains('admin') || clean.endsWith('@wakil.gov.np');
  }

  void _routeToWorkspace(String identifier) {
    setState(() {
      _userIdentifier = identifier;
      if (_isAdmin(identifier)) {
        _currentRoute = AppRouteState.adminWorkspace;
      } else {
        _currentRoute = AppRouteState.mainWorkspace;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wakil - Legal Intelligence',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primaryNavy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryNavy,
          primary: AppColors.primaryNavy,
          secondary: AppColors.primaryGold,
          surface: AppColors.surfaceBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
      ),
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
          },
          onSkipAuth: () {
            _routeToWorkspace('test_user@wakil.gov.np');
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
            _routeToWorkspace(email);
          },
          onSkipAuth: () {
            _routeToWorkspace('test_mode_user');
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
            _routeToWorkspace(_userIdentifier);
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
          },
        );

      case AppRouteState.adminWorkspace:
        return AdminWorkspaceScreen(
          userEmail: _userIdentifier,
          onSignOut: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
          },
        );

      case AppRouteState.mainWorkspace:
        return MainWorkspaceScreen(
          userIdentifier: _userIdentifier,
          onSignOut: () {
            setState(() {
              _currentRoute = AppRouteState.login;
            });
          },
        );
    }
  }
}
