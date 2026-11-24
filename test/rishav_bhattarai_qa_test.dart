import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakil_ai/main.dart';
import 'package:wakil_ai/view/authentication/otp_verification_screen.dart';

/// Sprint 1 & 2 QA Automation Suite
/// Author: Rishav Bhattarai (rishavbhattarai101@gmail.com)
///
/// Verifies:
/// - US-02: Bilingual Mandatory Legal Disclaimer & Legal Practitioners Act 2050 Citation
/// - US-06: Google OAuth One-Tap Sign-In
/// - US-10: OTP Security 2-Minute Countdown Timer & Resend Button
/// - US-14: Automated Role-Based Routing
void main() {
  group('Rishav Bhattarai QA Suite – Sprint 1 & Sprint 2', () {
    testWidgets('US-02: Verify Bilingual Disclaimer & Legal Practitioners Act 2050',
        (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.splash));
      await tester.pumpAndSettle();

      // Open Disclaimer Sheet
      await tester.tap(find.byKey(const Key('get_started_button')));
      await tester.pumpAndSettle();

      // 1. Verify Bilingual Title & Subtitle
      expect(find.byKey(const Key('disclaimer_title')), findsOneWidget);
      expect(find.textContaining('कानुनी सूचना'), findsOneWidget);
      expect(find.textContaining('वकिलले नेपाली ऐन'), findsOneWidget);

      // 2. Expand Accordion
      await tester.tap(find.byKey(const Key('scope_accordion_toggle')));
      await tester.pumpAndSettle();

      // 3. Verify Statutory Citations: Muluki Samhita and Legal Practitioners Act 2050
      expect(find.textContaining('Constitution of Nepal'), findsOneWidget);
      expect(find.textContaining('Legal Practitioners Act 2050'), findsOneWidget);
      expect(find.textContaining('नेपाल कानुन व्यवसायी परिषद ऐन, २०५०'), findsOneWidget);

      // 4. Verify Bilingual Checkbox Consent Text
      expect(find.textContaining('म स्वीकार गर्दछु'), findsOneWidget);
    });

    testWidgets('US-06: Verify Google One-Tap Social Sign-In',
        (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.login));
      await tester.pumpAndSettle();

      final googleBtn = find.byKey(const Key('google_signin_button'));
      expect(googleBtn, findsOneWidget);
      expect(find.text('Google One-Tap'), findsOneWidget);

      // Tap Google One-Tap advances to Main Workspace
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('citizen_workspace_screen')), findsOneWidget);
      expect(find.text('Main Legal Workspace'), findsOneWidget);
    });

    testWidgets('US-10: Verify OTP 2-Minute Timer & Resend Mechanism',
        (WidgetTester tester) async {
      // Test at 0s (Expired state)
      await tester.pumpWidget(MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: '+977 9841234567',
          onBack: () {},
          onOtpVerified: () {},
          initialTimerSeconds: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Verify Bilingual Title
      expect(find.byKey(const Key('otp_title')), findsOneWidget);
      expect(find.textContaining('फोन प्रमाणीकरण'), findsOneWidget);

      // 2. Timer displays 00:00 and Resend button is active
      expect(find.byKey(const Key('otp_timer_text')), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);

      final resendBtn = find.byKey(const Key('otp_resend_button'));
      expect(resendBtn, findsOneWidget);

      // 3. Tap Resend dispatches code and restarts timer
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('A new 6-digit security OTP was sent'), findsOneWidget);
    });

    testWidgets('US-14: Verify Automated Role-Based Redirection',
        (WidgetTester tester) async {
      // 1. Admin login routes directly to Admin Console
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.login));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_phone_input')), 'admin@wakil.gov.np');
      await tester.enterText(find.byKey(const Key('password_input')), 'AdminPassword123');
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_workspace_screen')), findsOneWidget);
      expect(find.text('Admin Console Workspace'), findsOneWidget);

      // Sign out
      await tester.tap(find.byKey(const Key('admin_sign_out_button')));
      await tester.pumpAndSettle();

      // 2. Citizen login routes to Citizen Workspace
      await tester.enterText(find.byKey(const Key('email_phone_input')), 'citizen@gmail.com');
      await tester.enterText(find.byKey(const Key('password_input')), 'CitizenPass123');
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('citizen_workspace_screen')), findsOneWidget);
      expect(find.text('Main Legal Workspace'), findsOneWidget);
    });
  });
}
