import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/disclaimer_screen.dart';
import 'package:ai39a/view/authentication/login_screen.dart';
import 'package:ai39a/view/authentication/splash_screen.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AuthService().signOut();
  });

  group('Sprint 1 - Prasiddha Gautam Deliverables', () {
    // US-01: Onboarding – Standalone Splash Screen & Emblem (1.0 SP)
    testWidgets('US-01: Splash screen displays emblem, pill, and auto-advances', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoAdvanceDelayMs: 1500),
        ),
      );

      // Verify emblem, title, and status pill are rendered
      expect(find.byKey(const Key('splash_screen')), findsOneWidget);
      expect(find.byKey(const Key('wakil_emblem')), findsOneWidget);
      expect(find.byIcon(Icons.balance), findsOneWidget);
      expect(find.text('Wakil'), findsOneWidget);
      expect(find.text('Legal Intelligence for Nepal'), findsOneWidget);
      expect(find.byKey(const Key('version_status_pill')), findsOneWidget);
      expect(find.text('CONSTITUTION • MULUKI CODES'), findsOneWidget);

      // Advance time past 1500ms
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Verify auto-transitioned to DisclaimerScreen
      expect(find.byType(DisclaimerScreen), findsOneWidget);
    });

    // US-05: Auth – Password Visibility Eye Toggle (2.0 SP)
    testWidgets('US-05: Tapping eye icon toggles password between masked and plain text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final passwordFieldFinder = find.byKey(const Key('signin_password_input'));
      final toggleFinder = find.byKey(const Key('password_visibility_toggle'));

      expect(passwordFieldFinder, findsOneWidget);
      expect(toggleFinder, findsOneWidget);

      // Initially password is obscured (masked) with visibility_off icon
      EditableText editableText = tester.widget(find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableText.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap toggle icon -> becomes plain text with visibility icon
      await tester.tap(toggleFinder);
      await tester.pump();

      editableText = tester.widget(find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableText.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Tap toggle icon again -> masked again
      await tester.tap(toggleFinder);
      await tester.pump();

      editableText = tester.widget(find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableText.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    // US-04: Credential input field interactions and validation
    testWidgets('US-04: Credential validation enforces email/phone and password requirements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final submitBtn = find.byKey(const Key('signin_submit_button'));

      // Submit empty form
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text("Please enter your email or Nepali mobile number."), findsOneWidget);
      expect(find.text("Password is required."), findsOneWidget);

      // Enter invalid email/phone format
      await tester.enterText(find.byKey(const Key('signin_email_phone_input')), "invalid-text");
      await tester.enterText(find.byKey(const Key('signin_password_input')), "123");
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text("Enter a valid email or 10-digit mobile number."), findsOneWidget);
      expect(find.text("Password must be at least 6 characters."), findsOneWidget);

      // Enter valid Nepali credentials
      await tester.enterText(find.byKey(const Key('signin_email_phone_input')), "9841234567");
      await tester.enterText(find.byKey(const Key('signin_password_input')), "NepalLaw@2074");
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    // US-07: Session persistence & test mode state
    testWidgets('US-07: Skip Auth activates test mode state and persists session', (tester) async {
      final auth = AuthService();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isTestMode, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final skipBtn = find.byKey(const Key('skip_auth_button'));
      expect(skipBtn, findsOneWidget);

      await tester.ensureVisible(skipBtn);
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isTestMode, isTrue);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
