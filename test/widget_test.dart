import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakil_ai/main.dart';
import 'package:wakil_ai/view/authentication/otp_verification_screen.dart';
import 'package:wakil_ai/view/authentication/password_recovery_screen.dart';

void main() {
  group('Sprint 1 & Sprint 2 User Story Widget Tests', () {
    testWidgets('US-01, US-02, US-03: Splash, Disclaimer Sheet & Consent Checkbox', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.splash));
      await tester.pumpAndSettle();

      // US-01: Verify emblem and title
      expect(find.byKey(const Key('splash_emblem')), findsOneWidget);
      expect(find.text('Wakil'), findsOneWidget);
      expect(find.text('Legal Intelligence for Nepal'), findsOneWidget);

      // Open Disclaimer Sheet
      await tester.tap(find.byKey(const Key('get_started_button')));
      await tester.pumpAndSettle();

      // US-02: Verify Disclaimer Sheet and Expandable Accordion
      expect(find.byKey(const Key('disclaimer_title')), findsOneWidget);
      expect(find.byKey(const Key('scope_accordion_toggle')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scope_accordion_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Constitution of Nepal'), findsOneWidget);

      // US-03: Consent Validation: clicking Accept without checking box fails
      await tester.tap(find.byKey(const Key('accept_continue_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('You must agree to the Terms'), findsOneWidget);

      // Check consent checkbox and continue
      await tester.tap(find.byKey(const Key('consent_checkbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accept_continue_button')));
      await tester.pumpAndSettle();

      // Advances to Login Screen
      expect(find.text('Welcome to Wakil'), findsOneWidget);
    });

    testWidgets('US-04, US-05, US-06, US-07: Login Form, Password Toggle, Social Card & Remember Device', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.login));
      await tester.pumpAndSettle();

      // US-04: Verify fields
      expect(find.byKey(const Key('email_phone_input')), findsOneWidget);
      expect(find.byKey(const Key('password_input')), findsOneWidget);
      expect(find.byKey(const Key('google_signin_button')), findsOneWidget);
      expect(find.byKey(const Key('remember_device_checkbox')), findsOneWidget);

      // US-05: Password visibility toggle
      final toggleFinder = find.byKey(const Key('password_visibility_toggle'));
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // US-04: Validation failure on empty
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth_error_message')), findsOneWidget);

      // US-07: Test Mode Skip Auth
      final skipButton = find.byKey(const Key('skip_auth_test_mode_button'));
      await tester.ensureVisible(skipButton);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('citizen_workspace_screen')), findsOneWidget);
    });

    testWidgets('US-08: Registration Form Validation & Nepali Phone Format', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.registration));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('registration_title')), findsOneWidget);

      // Validation failure on empty submit
      await tester.tap(find.byKey(const Key('registration_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Full Name is required.'), findsOneWidget);

      // Fill Name, invalid email
      await tester.enterText(find.byKey(const Key('registration_name_input')), 'Bhugol Gautam');
      await tester.enterText(find.byKey(const Key('registration_email_input')), 'invalidemail');
      await tester.tap(find.byKey(const Key('registration_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);

      // Valid email, invalid phone
      await tester.enterText(find.byKey(const Key('registration_email_input')), 'bhugol.gautam1@gmail.com');
      await tester.enterText(find.byKey(const Key('registration_phone_input')), '12345');
      await tester.tap(find.byKey(const Key('registration_submit_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('valid 10-digit Nepali mobile number'), findsOneWidget);

      // Valid phone, valid password -> Submit advances to OTP
      await tester.enterText(find.byKey(const Key('registration_phone_input')), '9841234567');
      await tester.enterText(find.byKey(const Key('registration_password_input')), 'SecurePass123!');
      await tester.tap(find.byKey(const Key('registration_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_title')), findsOneWidget);
    });

    testWidgets('US-09, US-10, US-11: OTP 6-Digit Card, Timer, Resend & Clear Action', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: '+977 9841234567',
          onBack: () {},
          onOtpVerified: () {},
          initialTimerSeconds: 0, // start at 0 to test active resend
        ),
      ));
      await tester.pumpAndSettle();

      // US-09: 6 PIN Boxes
      expect(find.byKey(const Key('otp_card')), findsOneWidget);
      for (int i = 0; i < 6; i++) {
        expect(find.byKey(Key('otp_box_$i')), findsOneWidget);
        await tester.enterText(find.byKey(Key('otp_box_$i')), '$i');
      }
      await tester.pumpAndSettle();

      // US-11: Clear Code Action Button
      await tester.tap(find.byKey(const Key('otp_clear_button')));
      await tester.pumpAndSettle();

      // US-10: Timer and Resend Button
      expect(find.byKey(const Key('otp_timer_text')), findsOneWidget);
      final resendButton = find.byKey(const Key('otp_resend_button'));
      expect(resendButton, findsOneWidget);
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('A new 6-digit security OTP was sent'), findsOneWidget);
    });

    testWidgets('US-12, US-13: Password Recovery Identity, 4-Bar Strength Gauge & Revocation', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PasswordRecoveryScreen(
          onBack: () {},
          onResetSuccess: (identity, password, revoke) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_title')), findsOneWidget);

      // Verify Identity
      await tester.enterText(find.byKey(const Key('recovery_identity_input')), 'bhugol.gautam1@gmail.com');
      await tester.tap(find.byKey(const Key('recovery_verify_identity_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Identity verified'), findsOneWidget);
      expect(find.byKey(const Key('recovery_new_password_input')), findsOneWidget);
      expect(find.byKey(const Key('password_strength_gauge')), findsOneWidget);

      // Type weak password -> Gauge shows Weak
      await tester.enterText(find.byKey(const Key('recovery_new_password_input')), 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Weak'), findsOneWidget);

      // Type very strong password -> Gauge shows Very Strong
      await tester.enterText(find.byKey(const Key('recovery_new_password_input')), 'StrongPass2026!');
      await tester.pumpAndSettle();
      expect(find.text('Very Strong'), findsOneWidget);

      // US-13: Global Session Revocation Switch
      final switchFinder = find.byKey(const Key('global_session_revocation_switch'));
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('US-14: Role-Based Routing for Admin vs Citizen', (WidgetTester tester) async {
      // Test 1: Admin routing
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.login));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_phone_input')), 'admin@wakil.gov.np');
      await tester.enterText(find.byKey(const Key('password_input')), 'AdminPassword123');
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_workspace_screen')), findsOneWidget);
      expect(find.text('Admin Console Workspace'), findsOneWidget);

      // Test 2: Sign Out returns to Login
      await tester.tap(find.byKey(const Key('admin_sign_out_button')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Wakil'), findsOneWidget);

      // Test 3: Citizen routing
      await tester.enterText(find.byKey(const Key('email_phone_input')), 'citizen@gmail.com');
      await tester.enterText(find.byKey(const Key('password_input')), 'CitizenPass123');
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('citizen_workspace_screen')), findsOneWidget);
      expect(find.text('Main Legal Workspace'), findsOneWidget);
    });
  });
}
