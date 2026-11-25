import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/otp_verification_screen.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final authService = AuthService();

  setUp(() {
    authService.signOut();
    authService.clearBurnedTokens();
  });

  group('Sprint 2 - US-09: OTP Security & Extreme Security Measures', () {
    testWidgets('US-09: OTP Verification Card renders 6 boxes, phone destination, timer and buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // 1. Verify Card container & phone destination
      expect(find.byKey(const Key('otp_verification_card')), findsOneWidget);
      expect(find.byKey(const Key('otp_phone_destination')), findsOneWidget);
      expect(find.text("+977 9841234567"), findsOneWidget);

      // 2. Verify all 6 PIN boxes are displayed
      for (int i = 0; i < 6; i++) {
        expect(find.byKey(Key('otp_input_box_$i')), findsOneWidget);
      }

      // 3. Verify action buttons
      expect(find.byKey(const Key('clear_otp_button')), findsOneWidget);
      expect(find.byKey(const Key('otp_countdown_timer')), findsOneWidget);
      expect(find.byKey(const Key('verify_otp_button')), findsOneWidget);
    });

    testWidgets('US-09: Auto-advancing digit input and full 6-digit entry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // Enter digits sequentially across all 6 boxes
      final digits = ['1', '2', '3', '4', '5', '6'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('otp_input_box_$i')), digits[i]);
        await tester.pump();
      }

      // Verify all digits populated
      for (int i = 0; i < 6; i++) {
        expect(find.text(digits[i]), findsOneWidget);
      }

      // Verify Verify button is enabled
      final verifyBtn = tester.widget<ElevatedButton>(find.byKey(const Key('verify_otp_button')));
      expect(verifyBtn.onPressed, isNotNull);
    });

    testWidgets('US-09: Full 6-digit paste into box 0 distributes across all boxes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // Paste "987654" into box 0
      await tester.enterText(find.byKey(const Key('otp_input_box_0')), "987654");
      await tester.pump();

      expect(find.text("9"), findsOneWidget);
      expect(find.text("8"), findsOneWidget);
      expect(find.text("7"), findsOneWidget);
      expect(find.text("6"), findsOneWidget);
      expect(find.text("5"), findsOneWidget);
      expect(find.text("4"), findsOneWidget);

      final verifyBtn = tester.widget<ElevatedButton>(find.byKey(const Key('verify_otp_button')));
      expect(verifyBtn.onPressed, isNotNull);
    });

    testWidgets('US-09: Clear Code resets all boxes and error state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // Type 3 digits
      await tester.enterText(find.byKey(const Key('otp_input_box_0')), "1");
      await tester.enterText(find.byKey(const Key('otp_input_box_1')), "2");
      await tester.enterText(find.byKey(const Key('otp_input_box_2')), "3");
      await tester.pump();

      // Tap Clear Code
      await tester.tap(find.byKey(const Key('clear_otp_button')));
      await tester.pump();

      // Verify boxes are empty
      for (int i = 0; i < 6; i++) {
        final field = tester.widget<TextFormField>(find.byKey(Key('otp_input_box_$i')));
        expect(field.controller!.text, isEmpty);
      }
    });

    testWidgets('US-09: Extreme Security - 3-attempt brute-force hard lockout triggers alert & disables inputs', (tester) async {
      // Set failed attempts to 3
      authService.failedAttempts = 3;

      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // 1. Verify lockout warning banner is displayed
      expect(find.byKey(const Key('otp_lockout_warning')), findsOneWidget);
      expect(find.text("Account Locked Out"), findsOneWidget);
      expect(find.text("Anti-Brute Force Protection Active"), findsOneWidget);

      // 2. Verify all 6 PIN boxes are disabled
      for (int i = 0; i < 6; i++) {
        final field = tester.widget<TextFormField>(find.byKey(Key('otp_input_box_$i')));
        expect(field.enabled, isFalse);
      }

      // 3. Verify submit button is disabled
      final verifyBtn = tester.widget<ElevatedButton>(find.byKey(const Key('verify_otp_button')));
      expect(verifyBtn.onPressed, isNull);

      // 4. Tap "Resend via SMS" to reset lockout
      final resendBtn = find.byKey(const Key('resend_otp_button'));
      expect(resendBtn, findsOneWidget);
      await tester.ensureVisible(resendBtn);
      await tester.tap(resendBtn);
      await tester.pump();

      // Lockout is cleared and boxes re-enabled
      expect(authService.isLockedOut, isFalse);
      expect(find.byKey(const Key('otp_lockout_warning')), findsNothing);
    });

    test('US-09: Extreme Security - Single-use token invalidation rejects replayed codes', () async {
      const phone = "+977 9811223344";
      const code = "789012";

      // 1. First verification succeeds and burns token
      final result1 = await authService.verifyOtp(phone, code);
      expect(result1.success, isTrue);
      expect(authService.isTokenBurned(phone, code), isTrue);

      // 2. Replay attack with same OTP code is immediately rejected
      final result2 = await authService.verifyOtp(phone, code);
      expect(result2.success, isFalse);
      expect(result2.errorMessage, contains("single-use security policy"));
    });

    testWidgets('US-09: Full OTP verification flow succeeds and navigates to Dashboard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(phoneNumber: "+977 9841234567"),
        ),
      );

      // Enter valid code
      await tester.enterText(find.byKey(const Key('otp_input_box_0')), "123456");
      await tester.pump();

      // Tap verify
      final verifyBtn = find.byKey(const Key('verify_otp_button'));
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Navigated to Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(authService.isAuthenticated, isTrue);
    });
  });
}
