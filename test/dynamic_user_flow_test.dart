import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakil_ai/main.dart';

void main() {
  group('Dynamic Verification for User: bhugol.gautam1@gmail.com', () {
    testWidgets('Dynamic Journey: Splash -> Disclaimer -> Register -> OTP (742918) -> Workspace', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.splash));
      await tester.pumpAndSettle();

      // 1. Splash Screen
      expect(find.byKey(const Key('splash_emblem')), findsOneWidget);
      expect(find.text('Wakil'), findsOneWidget);

      // Open Disclaimer
      await tester.tap(find.byKey(const Key('get_started_button')));
      await tester.pumpAndSettle();

      // Accept Disclaimer with Consent
      await tester.tap(find.byKey(const Key('consent_checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept_continue_button')));
      await tester.pumpAndSettle();

      // 2. Navigate to Registration
      expect(find.text('Welcome to Wakil'), findsOneWidget);
      final toSignupFinder = find.byKey(const Key('to_signup_button'));
      await tester.ensureVisible(toSignupFinder);
      await tester.tap(toSignupFinder);
      await tester.pumpAndSettle();

      // 3. Register with user's real email: bhugol.gautam1@gmail.com
      expect(find.byKey(const Key('registration_title')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('registration_name_input')), 'Bhugol Gautam');
      await tester.enterText(find.byKey(const Key('registration_email_input')), 'bhugol.gautam1@gmail.com');
      await tester.enterText(find.byKey(const Key('registration_phone_input')), '9841234567');
      await tester.enterText(find.byKey(const Key('registration_password_input')), 'WakilLegal2026!');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('registration_submit_button')));
      await tester.pumpAndSettle();

      // 4. OTP Verification Screen with dynamic code 742918
      expect(find.byKey(const Key('otp_title')), findsOneWidget);
      const dynamicOtp = '742918';
      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('otp_box_$i')), dynamicOtp[i]);
      }
      await tester.pumpAndSettle();

      // Verify OTP Code
      await tester.tap(find.byKey(const Key('otp_verify_button')));
      await tester.pumpAndSettle();

      // 5. Lands on Main Legal Workspace with user email
      expect(find.byKey(const Key('citizen_workspace_screen')), findsOneWidget);
      expect(find.textContaining('bhugol.gautam1@gmail.com'), findsOneWidget);
      expect(find.text('Main Legal Workspace'), findsOneWidget);
    });

    testWidgets('Dynamic Password Recovery Journey for bhugol.gautam1@gmail.com', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.passwordRecovery));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_title')), findsOneWidget);

      // Verify user identity
      await tester.enterText(find.byKey(const Key('recovery_identity_input')), 'bhugol.gautam1@gmail.com');
      await tester.tap(find.byKey(const Key('recovery_verify_identity_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Identity verified for bhugol.gautam1@gmail.com'), findsOneWidget);

      // Set new password and check strength
      await tester.enterText(find.byKey(const Key('recovery_new_password_input')), 'KathmanduLegal98#');
      await tester.pumpAndSettle();
      expect(find.text('Very Strong'), findsOneWidget);

      // Submit password update
      await tester.tap(find.byKey(const Key('recovery_submit_button')));
      await tester.pumpAndSettle();

      // Returns to Login Screen
      expect(find.text('Welcome to Wakil'), findsOneWidget);
    });

    testWidgets('Dynamic Role-Based Redirection: Admin Console for admin.bhugol@wakil.gov.np', (WidgetTester tester) async {
      await tester.pumpWidget(const WakilApp(initialRoute: AppRouteState.login));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_phone_input')), 'admin.bhugol@wakil.gov.np');
      await tester.enterText(find.byKey(const Key('password_input')), 'AdminSecurity2026!');
      await tester.tap(find.byKey(const Key('sign_in_submit_button')));
      await tester.pumpAndSettle();

      // Verifies Admin Console Workspace
      expect(find.byKey(const Key('admin_workspace_screen')), findsOneWidget);
      expect(find.text('Admin Console Workspace'), findsOneWidget);
      expect(find.textContaining('admin.bhugol@wakil.gov.np'), findsOneWidget);
    });
  });
}
