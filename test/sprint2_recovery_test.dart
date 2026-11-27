import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/login_screen.dart';
import 'package:ai39a/view/authentication/password_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final authService = AuthService();

  setUp(() {
    authService.signOut();
    authService.clearBurnedTokens();
  });

  group('Sprint 2 - US-13: Global Session Revocation Unit Tests', () {
    test(
      'AuthService.updatePasswordWithRevocation with revocation ON increments tokenVersion, revokes other sessions, and preserves current session',
      () async {
        authService.registerSession('current_session');
        authService.registerSession('other_browser_1');
        authService.createSession('other_mobile_2');

        expect(authService.tokenVersion, 1);
        expect(authService.lastRevocationTimestamp, isNull);
        expect(authService.activeSessions.length, 3);

        await authService.updatePasswordWithRevocation(
          newPassword: 'StrongPassword@2026',
          revokeOtherSessions: true,
          currentSessionToken: 'current_session',
        );

        expect(authService.storedPassword, 'StrongPassword@2026');
        expect(authService.currentPassword, 'StrongPassword@2026');
        expect(authService.tokenVersion, 2);
        expect(authService.lastRevocationTimestamp, isNotNull);
        expect(authService.activeSessions, {'current_session'});
        expect(authService.activeSessions.contains('other_browser_1'), isFalse);
        expect(authService.activeSessions.contains('other_mobile_2'), isFalse);
      },
    );

    test(
      'AuthService.updatePasswordWithRevocation with revocation ON and no currentSessionToken revokes all sessions',
      () async {
        authService.registerSession('session_1');
        authService.registerSession('session_2');

        await authService.updatePasswordWithRevocation(
          newPassword: 'ResetPass!99',
          revokeOtherSessions: true,
        );

        expect(authService.storedPassword, 'ResetPass!99');
        expect(authService.tokenVersion, 2);
        expect(authService.lastRevocationTimestamp, isNotNull);
        expect(authService.activeSessions, isEmpty);
      },
    );

    test(
      'AuthService.updatePasswordWithRevocation with revocation OFF updates password, retains other sessions, and keeps tokenVersion unchanged',
      () async {
        authService.registerSession('session_primary');
        authService.registerSession('session_secondary');

        await authService.updatePasswordWithRevocation(
          newPassword: 'UpdatedPass@123',
          revokeOtherSessions: false,
          currentSessionToken: 'session_primary',
        );

        expect(authService.storedPassword, 'UpdatedPass@123');
        expect(authService.tokenVersion, 1);
        expect(authService.lastRevocationTimestamp, isNull);
        expect(
          authService.activeSessions,
          {'session_primary', 'session_secondary'},
        );
      },
    );

    test(
      'AuthService.isSessionValid checks matching and stale tokenVersions',
      () async {
        authService.registerSession('active_session');
        authService.registerSession('revoked_session');

        // Matching tokenVersion 1 before revocation
        expect(authService.isSessionValid('active_session', 1), isTrue);
        expect(authService.isSessionValid('revoked_session', 1), isTrue);
        expect(authService.isSessionValid('active_session', 2), isFalse);
        expect(authService.isSessionValid('unknown_session', 1), isFalse);

        // Trigger global revocation keeping only active_session
        await authService.updatePasswordWithRevocation(
          newPassword: 'HighEntropy@2026',
          revokeOtherSessions: true,
          currentSessionToken: 'active_session',
        );

        expect(authService.tokenVersion, 2);
        // Stale tokenVersion 1 is invalid even for current session
        expect(authService.isSessionValid('active_session', 1), isFalse);
        expect(authService.isSessionValid('revoked_session', 1), isFalse);
        // Revoked session is invalid even with updated tokenVersion
        expect(authService.isSessionValid('revoked_session', 2), isFalse);
        // Current session with matching tokenVersion 2 remains valid
        expect(authService.isSessionValid('active_session', 2), isTrue);
      },
    );
  });

  group('Sprint 2 - US-13: PasswordRecoveryScreen Widget Tests', () {
    testWidgets(
      'Renders top bar, password fields, 4-bar strength meter, revocation toggle, and update password button',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PasswordRecoveryScreen(),
          ),
        );

        // Top bar and branding
        expect(find.byKey(const Key('back_button')), findsOneWidget);
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.byKey(const Key('scales_of_justice_emblem')), findsOneWidget);
        expect(find.byIcon(Icons.balance), findsOneWidget);
        expect(find.text('Create new password'), findsOneWidget);

        // Password fields & visibility toggles
        expect(find.byKey(const Key('new_password_field')), findsOneWidget);
        expect(
          find.byKey(const Key('toggle_new_password_visibility')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
        expect(
          find.byKey(const Key('toggle_confirm_password_visibility')),
          findsOneWidget,
        );

        // 4-bar strength meter
        expect(find.byKey(const Key('password_strength_meter')), findsOneWidget);
        for (int i = 0; i < 4; i++) {
          expect(find.byKey(Key('strength_bar_$i')), findsOneWidget);
        }
        expect(find.byKey(const Key('password_strength_label')), findsOneWidget);
        expect(find.text('Min. 8 chars, mixed cases & symbols'), findsOneWidget);

        // Active Session Renewal card & toggle (defaults ON)
        expect(
          find.byKey(const Key('active_session_renewal_card')),
          findsOneWidget,
        );
        expect(find.text('Active Session Renewal'), findsOneWidget);
        final toggleFinder = find.byKey(
          const Key('global_session_revocation_toggle'),
        );
        expect(toggleFinder, findsOneWidget);
        final toggleWidget = tester.widget<Switch>(toggleFinder);
        expect(toggleWidget.value, isTrue);

        // Action buttons
        expect(find.byKey(const Key('update_password_button')), findsOneWidget);
        expect(find.text('Update Password'), findsOneWidget);
        expect(find.byKey(const Key('cancel_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Dynamic strength meter, visibility toggle, and password match indicator react to input',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PasswordRecoveryScreen(),
          ),
        );

        final newPasswordFinder = find.byKey(const Key('new_password_field'));
        final confirmPasswordFinder = find.byKey(
          const Key('confirm_password_field'),
        );

        // Initially obscured
        EditableText newEditable = tester.widget(
          find.descendant(
            of: newPasswordFinder,
            matching: find.byType(EditableText),
          ),
        );
        expect(newEditable.obscureText, isTrue);

        // Toggle visibility on new password field
        await tester.tap(find.byKey(const Key('toggle_new_password_visibility')));
        await tester.pump();
        newEditable = tester.widget(
          find.descendant(
            of: newPasswordFinder,
            matching: find.byType(EditableText),
          ),
        );
        expect(newEditable.obscureText, isFalse);

        // Weak password
        await tester.enterText(newPasswordFinder, 'abc');
        await tester.pump();
        expect(find.text('WEAK KEY'), findsOneWidget);

        // Strong password
        await tester.enterText(newPasswordFinder, 'NepalLaw@2026');
        await tester.pump();
        expect(find.text('STRONG KEY'), findsOneWidget);

        // Confirm matching password
        await tester.enterText(confirmPasswordFinder, 'NepalLaw@2026');
        await tester.pump();
        expect(find.byKey(const Key('match_indicator')), findsOneWidget);
        expect(find.text('Passwords match securely'), findsOneWidget);
      },
    );

    testWidgets('Interacting with revocation toggle switches its state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordRecoveryScreen(),
        ),
      );

      final toggleFinder = find.byKey(
        const Key('global_session_revocation_toggle'),
      );
      expect(tester.widget<Switch>(toggleFinder).value, isTrue);

      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pump();
      expect(tester.widget<Switch>(toggleFinder).value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pump();
      expect(tester.widget<Switch>(toggleFinder).value, isTrue);
    });

    testWidgets(
      'Given revocation toggle is ON, tapping Update Password revokes all other active sessions, shows success, and navigates back',
      (tester) async {
        authService.registerSession('other_browser_token');
        authService.registerSession('other_mobile_token');

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );

        // Navigate from LoginScreen via Forgot Password?
        final forgotBtn = find.byKey(const Key('forgot_password_button'));
        await tester.ensureVisible(forgotBtn);
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();

        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('new_password_field')),
          'NepalLaw@2026',
        );
        await tester.enterText(
          find.byKey(const Key('confirm_password_field')),
          'NepalLaw@2026',
        );
        await tester.pump();

        // Confirm toggle is ON
        final toggleFinder = find.byKey(
          const Key('global_session_revocation_toggle'),
        );
        expect(tester.widget<Switch>(toggleFinder).value, isTrue);

        // Tap Update Password
        final updateBtn = find.byKey(const Key('update_password_button'));
        await tester.ensureVisible(updateBtn);
        await tester.tap(updateBtn);
        await tester.pump();

        // Success SnackBar shown
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(
              'Password updated successfully. Please sign in.',
            ),
          ),
          findsAtLeastNWidgets(1),
        );

        await tester.pumpAndSettle();

        // Navigated back to LoginScreen
        expect(find.byType(PasswordRecoveryScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);

        // Verify revocation in AuthService
        expect(authService.storedPassword, 'NepalLaw@2026');
        expect(authService.tokenVersion, 2);
        expect(authService.activeSessions, isEmpty);
        expect(authService.lastRevocationTimestamp, isNotNull);
        expect(
          authService.isSessionValid('other_browser_token', 1),
          isFalse,
        );
        expect(
          authService.isSessionValid('other_mobile_token', 1),
          isFalse,
        );
      },
    );

    testWidgets(
      'Given revocation toggle is OFF, tapping Update Password updates password without revoking other sessions and navigates back',
      (tester) async {
        authService.registerSession('other_browser_token');
        authService.registerSession('other_mobile_token');

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );

        final forgotBtn = find.byKey(const Key('forgot_password_button'));
        await tester.ensureVisible(forgotBtn);
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();

        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('new_password_field')),
          'SecurePass@99',
        );
        await tester.enterText(
          find.byKey(const Key('confirm_password_field')),
          'SecurePass@99',
        );
        await tester.pump();

        // Toggle OFF global session revocation
        final toggleFinder = find.byKey(
          const Key('global_session_revocation_toggle'),
        );
        await tester.ensureVisible(toggleFinder);
        await tester.tap(toggleFinder);
        await tester.pump();
        expect(tester.widget<Switch>(toggleFinder).value, isFalse);

        // Tap Update Password
        final updateBtn = find.byKey(const Key('update_password_button'));
        await tester.ensureVisible(updateBtn);
        await tester.tap(updateBtn);
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(
              'Password updated successfully. Please sign in.',
            ),
          ),
          findsAtLeastNWidgets(1),
        );

        await tester.pumpAndSettle();

        // Navigated back to LoginScreen
        expect(find.byType(PasswordRecoveryScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);

        // Verify password updated and other sessions preserved
        expect(authService.storedPassword, 'SecurePass@99');
        expect(authService.tokenVersion, 1);
        expect(authService.lastRevocationTimestamp, isNull);
        expect(
          authService.activeSessions,
          {'other_browser_token', 'other_mobile_token'},
        );
        expect(
          authService.isSessionValid('other_browser_token', 1),
          isTrue,
        );
        expect(
          authService.isSessionValid('other_mobile_token', 1),
          isTrue,
        );
      },
    );

    testWidgets(
      'Mismatched passwords show validation error without revoking sessions or navigating',
      (tester) async {
        authService.registerSession('session_keep');

        await tester.pumpWidget(
          const MaterialApp(
            home: PasswordRecoveryScreen(),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('new_password_field')),
          'StrongPass@1',
        );
        await tester.enterText(
          find.byKey(const Key('confirm_password_field')),
          'DifferentPass@2',
        );
        await tester.pump();

        final updateBtn = find.byKey(const Key('update_password_button'));
        await tester.ensureVisible(updateBtn);
        await tester.tap(updateBtn);
        await tester.pumpAndSettle();

        final errorFinder = find.byKey(const Key('recovery_error_message'));
        expect(errorFinder, findsOneWidget);
        expect(
          tester.widget<Text>(errorFinder).data,
          'Passwords do not match.',
        );
        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
        expect(authService.tokenVersion, 1);
        expect(authService.storedPassword, isNull);
        expect(authService.activeSessions, {'session_keep'});
      },
    );
  });
}
