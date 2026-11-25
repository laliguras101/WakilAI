import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakil_ai/constants/app_colors.dart';
import 'package:wakil_ai/main.dart';
import 'package:wakil_ai/services/services.dart';
import 'package:wakil_ai/view/authentication/login_screen.dart';
import 'package:wakil_ai/view/authentication/otp_verification_screen.dart';
import 'package:wakil_ai/view/authentication/password_recovery_screen.dart';
import 'package:wakil_ai/view/authentication/registration_screen.dart';
import 'package:wakil_ai/view/authentication/widgets/social_media_card.dart';
import 'package:wakil_ai/view/dashboard/admin_workspace_screen.dart';
import 'package:wakil_ai/view/dashboard/main_workspace_screen.dart';
import 'package:wakil_ai/view/onboarding/legal_disclaimer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobileViewport = Size(390, 844);
  const testViewport = Size(800, 600);
  const viewports = <({String label, Size size})>[
    (label: '390x844 mobile', size: mobileViewport),
    (label: '800x600 test', size: testViewport),
  ];

  void configureViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpAndVerifyNoOverflow(
    WidgetTester tester,
    Widget widget,
  ) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  group('Phase 0 — Theme & Swiss Light Monochrome Design System', () {
    test('AppColors exposes exact Swiss / Gemini Light Monochrome tokens', () {
      // Surface hierarchy
      expect(AppColors.surfacePure.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.surfaceCanvas.toARGB32(), 0xFFF9F9FA);
      expect(AppColors.surfaceLow.toARGB32(), 0xFFF3F3F4);
      expect(AppColors.surfaceContainer.toARGB32(), 0xFFEEEEEF);
      expect(AppColors.surfaceHigh.toARGB32(), 0xFFE8E8E9);
      expect(AppColors.surfaceHighest.toARGB32(), 0xFFE2E2E3);

      // Ink, typography & outlines
      expect(AppColors.primaryBlack.toARGB32(), 0xFF000000);
      expect(AppColors.textPrimary.toARGB32(), 0xFF1A1C1D);
      expect(AppColors.textOnVariant.toARGB32(), 0xFF47464B);
      expect(AppColors.textSecondary.toARGB32(), 0xFF5D5E66);
      expect(AppColors.textMuted.toARGB32(), 0xFF77767B);
      expect(AppColors.outlineVariant.toARGB32(), 0xFFC8C5CB);

      // Error hierarchy
      expect(AppColors.crimsonError.toARGB32(), 0xFFBA1A1A);
      expect(AppColors.onErrorContainer.toARGB32(), 0xFF93000A);
      expect(AppColors.errorContainer.toARGB32(), 0xFFFFDAD6);

      // Google 4-color brand mark tokens
      expect(AppColors.googleBlue.toARGB32(), 0xFF4285F4);
      expect(AppColors.googleGreen.toARGB32(), 0xFF34A853);
      expect(AppColors.googleYellow.toARGB32(), 0xFFFBBC05);
      expect(AppColors.googleRed.toARGB32(), 0xFFEA4335);

      // Semantic aliases
      expect(AppColors.surfaceCard, AppColors.surfacePure);
      expect(AppColors.surfaceBackground, AppColors.surfaceCanvas);
      expect(AppColors.borderSubtle, AppColors.surfaceHighest);
      expect(AppColors.crimsonRed, AppColors.crimsonError);
    });

    testWidgets('WakilApp configures Material 3 Light Monochrome ThemeData', (
      WidgetTester tester,
    ) async {
      final authService = AuthService.localFallback();
      addTearDown(() async => authService.dispose());

      await pumpAndVerifyNoOverflow(
        tester,
        WakilApp(
          initialRoute: AppRouteState.splash,
          authService: authService,
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme!;
      final scheme = theme.colorScheme;

      expect(materialApp.debugShowCheckedModeBanner, isFalse);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor.toARGB32(), 0xFFFFFFFF);
      expect(theme.primaryColor.toARGB32(), 0xFF000000);

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary.toARGB32(), 0xFF000000);
      expect(scheme.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(scheme.secondary.toARGB32(), 0xFF5D5E66);
      expect(scheme.surface.toARGB32(), 0xFFFFFFFF);
      expect(scheme.onSurface.toARGB32(), 0xFF1A1C1D);
      expect(scheme.surfaceContainerLowest.toARGB32(), 0xFFFFFFFF);
      expect(scheme.surfaceContainerLow.toARGB32(), 0xFFF3F3F4);
      expect(scheme.surfaceContainer.toARGB32(), 0xFFEEEEEF);
      expect(scheme.surfaceContainerHigh.toARGB32(), 0xFFE8E8E9);
      expect(scheme.surfaceContainerHighest.toARGB32(), 0xFFE2E2E3);
      expect(scheme.onSurfaceVariant.toARGB32(), 0xFF47464B);
      expect(scheme.outline.toARGB32(), 0xFF77767B);
      expect(scheme.outlineVariant.toARGB32(), 0xFFC8C5CB);
      expect(scheme.error.toARGB32(), 0xFFBA1A1A);
      expect(scheme.errorContainer.toARGB32(), 0xFFFFDAD6);
      expect(scheme.onErrorContainer.toARGB32(), 0xFF93000A);

      expect(theme.appBarTheme.backgroundColor?.toARGB32(), 0xFFFFFFFF);
      expect(theme.appBarTheme.foregroundColor?.toARGB32(), 0xFF1A1C1D);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.bottomSheetTheme.backgroundColor?.toARGB32(), 0xFFFFFFFF);
    });
  });

  group('Phase 0 — FirebaseBootstrap', () {
    setUp(FirebaseBootstrap.resetForTesting);
    tearDown(FirebaseBootstrap.resetForTesting);

    test(
      'starts uninitialized and safely falls back when forced or unconfigured',
      () async {
        expect(FirebaseBootstrap.isLive, isFalse);
        expect(
          FirebaseBootstrap.currentState.mode,
          FirebaseBackendMode.localFallback,
        );
        expect(FirebaseBootstrap.authOrNull, isNull);
        expect(FirebaseBootstrap.firestoreOrNull(), isNull);

        final forcedState = await FirebaseBootstrap.initializeSafely(
          forceLocalFallback: true,
        );
        expect(forcedState.isInitialized, isFalse);
        expect(forcedState.isLive, isFalse);
        expect(forcedState.mode, FirebaseBackendMode.localFallback);
        expect(
          forcedState.firestoreDatabaseId,
          FirebaseBootstrap.defaultFirestoreDatabaseId,
        );
        expect(FirebaseBootstrap.authOrNull, isNull);
        expect(FirebaseBootstrap.firestoreOrNull(), isNull);

        FirebaseBootstrap.resetForTesting();

        // Unconfigured / headless test environment without google-services.json
        // must never throw and must remain in localFallback mode.
        final unconfiguredState = await FirebaseBootstrap.initializeSafely();
        expect(unconfiguredState.isInitialized, isFalse);
        expect(unconfiguredState.isLive, isFalse);
        expect(unconfiguredState.mode, FirebaseBackendMode.localFallback);
        expect(unconfiguredState.failureReason, isNotNull);
        expect(FirebaseBootstrap.authOrNull, isNull);
        expect(FirebaseBootstrap.firestoreOrNull(), isNull);
      },
    );
  });

  group('Phase 0 — SessionService', () {
    test(
      'Remember Device persists & restores session via InMemoryKeyValueStore',
      () async {
        final store = InMemoryKeyValueStore();
        final writerService = SessionService(store: store);
        addTearDown(writerService.dispose);

        expect(await writerService.hasAcceptedDisclaimer(), isFalse);
        await writerService.setDisclaimerAccepted(true);
        expect(await writerService.hasAcceptedDisclaimer(), isTrue);

        final saved = await writerService.saveSession(
          userId: 'uid_citizen_1',
          identifier: 'bhugol.gautam1@gmail.com',
          email: 'bhugol.gautam1@gmail.com',
          phoneNumber: '+9779841234567',
          displayName: 'Bhugol Gautam',
          role: WakilUserRole.citizen,
          authProvider: 'password',
          rememberDevice: true,
          sessionToken: 'tok_remember_123',
        );

        expect(saved.rememberDevice, isTrue);
        expect(saved.revocationEpoch, 0);
        expect(writerService.isAuthenticated, isTrue);
        expect(writerService.rememberDeviceEnabled, isTrue);
        expect(
          await writerService.getRememberedIdentifier(),
          'bhugol.gautam1@gmail.com',
        );

        // Fresh service backed by same store restores remembered session.
        final readerService = SessionService(store: store);
        addTearDown(readerService.dispose);
        final restored = await readerService.restoreRememberedSession();

        expect(restored, isNotNull);
        expect(restored!.userId, 'uid_citizen_1');
        expect(restored.identifier, 'bhugol.gautam1@gmail.com');
        expect(restored.role, WakilUserRole.citizen);
        expect(restored.sessionToken, 'tok_remember_123');
        expect(readerService.isAuthenticated, isTrue);
        expect(await readerService.getRememberDevicePreference(), isTrue);

        // clearCurrentSession removes active token while optionally keeping ID.
        await readerService.clearCurrentSession(
          preserveRememberedIdentifier: true,
        );
        expect(readerService.isAuthenticated, isFalse);
        expect(
          await readerService.getRememberedIdentifier(),
          'bhugol.gautam1@gmail.com',
        );
        expect(await readerService.restoreRememberedSession(), isNull);

        await readerService.clearCurrentSession(
          preserveRememberedIdentifier: false,
        );
        expect(await readerService.getRememberedIdentifier(), isNull);

        // Saving with rememberDevice: false must not persist across restarts.
        await writerService.saveSession(
          userId: 'uid_ephemeral',
          identifier: 'ephemeral@wakil.ai',
          role: WakilUserRole.citizen,
          rememberDevice: false,
        );
        final postEphemeralReader = SessionService(store: store);
        addTearDown(postEphemeralReader.dispose);
        expect(await postEphemeralReader.restoreRememberedSession(), isNull);
        expect(
          await postEphemeralReader.getRememberDevicePreference(),
          isFalse,
        );
      },
    );

    test(
      'ResilientSecureStorage falls back cleanly when platform channel fails',
      () async {
        final failingStorage = _ThrowingSecureStorage();
        final resilientStore = ResilientSecureStorage(storage: failingStorage);
        final service = SessionService(store: resilientStore);
        addTearDown(service.dispose);

        expect(service.isUsingMemoryFallback, isFalse);

        final saved = await service.saveSession(
          userId: 'uid_fallback',
          identifier: 'fallback@wakil.ai',
          role: WakilUserRole.citizen,
          rememberDevice: true,
        );

        expect(service.isUsingMemoryFallback, isTrue);
        expect(saved.identifier, 'fallback@wakil.ai');

        final restored = await service.restoreRememberedSession();
        expect(restored, isNotNull);
        expect(restored!.userId, 'uid_fallback');
      },
    );

    test(
      'US-13 revokeAllSessions increments revocationEpoch and clears tokens',
      () async {
        final store = InMemoryKeyValueStore();
        final hookCalls = <({String? identity, String? uid})>[];
        final service = SessionService(
          store: store,
          remoteRevocationHook: (identity, uid) async {
            hookCalls.add((identity: identity, uid: uid));
          },
        );
        addTearDown(service.dispose);

        await service.saveSession(
          userId: 'uid_admin_1',
          identifier: 'admin@wakil.gov.np',
          role: WakilUserRole.admin,
          rememberDevice: true,
          sessionToken: 'secret_token_abc',
        );
        final originalDeviceId = await store.read(SessionService.deviceIdKey);
        expect(service.revocationEpoch, 0);

        final revocation = await service.revokeAllSessions(
          identity: 'admin@wakil.gov.np',
        );

        expect(revocation.isSuccess, isTrue);
        expect(revocation.revocationEpoch, 1);
        expect(revocation.localTokensCleared, isTrue);
        expect(revocation.identity, 'admin@wakil.gov.np');
        expect(service.revocationEpoch, 1);
        expect(service.isAuthenticated, isFalse);
        expect(service.rememberDeviceEnabled, isFalse);
        expect(await store.read(SessionService.sessionRecordKey), isNull);
        expect(
          await store.read(SessionService.rememberedIdentifierKey),
          isNull,
        );
        expect(
          await store.read(SessionService.deviceIdKey),
          isNot(equals(originalDeviceId)),
        );
        expect(hookCalls.single.identity, 'admin@wakil.gov.np');
        expect(hookCalls.single.uid, 'uid_admin_1');

        // Stale epoch-0 record cannot be restored once epoch >= 1.
        await store.write(
          SessionService.sessionRecordKey,
          '{"userId":"old","identifier":"admin@wakil.gov.np","role":"admin",'
          '"authProvider":"password","rememberDevice":true,"isTestMode":false,'
          '"deviceId":"old-dev","revocationEpoch":0,'
          '"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}',
        );
        expect(await service.restoreRememberedSession(), isNull);
        expect(await store.read(SessionService.sessionRecordKey), isNull);

        // Second revocation advances epoch monotonically.
        final secondRevocation = await service.revokeAllSessions(
          identity: 'admin@wakil.gov.np',
        );
        expect(secondRevocation.revocationEpoch, 2);
      },
    );
  });

  group('Phase 0 — RoleRoutingService (US-14)', () {
    test('evaluates isAdminIdentifier, resolveRoleSync & destinationForRole', () {
      final routing = RoleRoutingService();

      expect(routing.isAdminIdentifier('admin@wakil.gov.np'), isTrue);
      expect(routing.isAdminIdentifier('admin.bhugol@wakil.gov.np'), isTrue);
      expect(routing.isAdminIdentifier('officer@wakil.gov.np'), isTrue);
      expect(routing.isAdminIdentifier('SUPERADMIN@gmail.com'), isTrue);
      expect(routing.isAdminIdentifier('citizen@gmail.com'), isFalse);
      expect(routing.isAdminIdentifier('bhugol.gautam1@gmail.com'), isFalse);
      expect(routing.isAdminIdentifier('+9779841234567'), isFalse);
      expect(routing.isAdminIdentifier('   '), isFalse);

      expect(
        routing.resolveRoleSync('admin@wakil.gov.np'),
        WakilUserRole.admin,
      );
      expect(
        routing.resolveRoleSync('citizen@gmail.com'),
        WakilUserRole.citizen,
      );
      expect(
        routing.destinationForRole(WakilUserRole.admin),
        WorkspaceDestination.adminWorkspace,
      );
      expect(
        routing.destinationForRole(WakilUserRole.citizen),
        WorkspaceDestination.mainWorkspace,
      );
      expect(
        routing.destinationForIdentifier('officer@wakil.gov.np'),
        WorkspaceDestination.adminWorkspace,
      );
      expect(
        routing.destinationForIdentifier('citizen@gmail.com'),
        WorkspaceDestination.mainWorkspace,
      );
    });

    test('resolveRole honors custom Firestore lookup hook & test-mode bypass', () async {
      final elevatedRouting = RoleRoutingService(
        customRoleLookup: (uid, identifier) async {
          if (uid == 'uid_promoted' && identifier == 'citizen@gmail.com') {
            return WakilUserRole.admin;
          }
          if (uid == 'uid_demoted') {
            return WakilUserRole.citizen;
          }
          return null;
        },
      );

      final promoted = await elevatedRouting.resolveRole(
        identifier: 'citizen@gmail.com',
        uid: 'uid_promoted',
      );
      expect(promoted.role, WakilUserRole.admin);
      expect(promoted.isAdmin, isTrue);
      expect(promoted.destination, WorkspaceDestination.adminWorkspace);
      expect(promoted.source, 'custom_role_lookup');

      final demoted = await elevatedRouting.resolveRole(
        identifier: 'officer@wakil.gov.np',
        uid: 'uid_demoted',
      );
      expect(demoted.role, WakilUserRole.citizen);
      expect(demoted.isAdmin, isFalse);
      expect(demoted.destination, WorkspaceDestination.mainWorkspace);
      expect(demoted.source, 'custom_role_lookup');

      final testModeBypass = await elevatedRouting.resolveRole(
        identifier: 'citizen@gmail.com',
        uid: 'uid_promoted',
        isTestMode: true,
      );
      expect(testModeBypass.role, WakilUserRole.citizen);
      expect(testModeBypass.source, 'test_mode_rule');

      final failingHookRouting = RoleRoutingService(
        customRoleLookup: (_, _) async => throw StateError('Firestore offline'),
      );
      final fallbackResult = await failingHookRouting.resolveRole(
        identifier: 'admin.bhugol@wakil.gov.np',
        uid: 'uid_any',
      );
      expect(fallbackResult.role, WakilUserRole.admin);
      expect(fallbackResult.destination, WorkspaceDestination.adminWorkspace);
      expect(fallbackResult.source, 'identifier_rule');
    });
  });

  group('Phase 0 — AuthService.localFallback', () {
    test('validates emails, Nepali phone numbers, and password strength', () {
      expect(AuthService.isValidEmail('bhugol.gautam1@gmail.com'), isTrue);
      expect(AuthService.isValidEmail('invalid-email'), isFalse);
      expect(AuthService.isValidEmail('   '), isFalse);

      expect(AuthService.normalizeNepaliPhone('9841234567'), '+9779841234567');
      expect(
        AuthService.normalizeNepaliPhone('+977 984-1234567'),
        '+9779841234567',
      );
      expect(
        AuthService.normalizeNepaliPhone('009779712345678'),
        '+9779712345678',
      );
      expect(
        AuthService.normalizeNepaliPhone('9779812345678'),
        '+9779812345678',
      );
      expect(AuthService.normalizeNepaliPhone('9612345678'), isNull);
      expect(AuthService.normalizeNepaliPhone('12345'), isNull);

      expect(AuthService.evaluatePasswordStrength(''), 0);
      expect(AuthService.evaluatePasswordStrength('abc'), 1);
      expect(AuthService.evaluatePasswordStrength('abcdefg1'), 2);
      expect(AuthService.evaluatePasswordStrength('Abcdefg1'), 3);
      expect(AuthService.evaluatePasswordStrength('StrongPass2026!'), 4);
    });

    test(
      'sign-in validates email & Nepali phone and routes Admin vs Citizen',
      () async {
        final auth = AuthService.localFallback();
        addTearDown(auth.dispose);
        expect(auth.isLiveBackend, isFalse);

        final emptyId = await auth.signInWithIdentifierAndPassword(
          identifier: '  ',
          password: 'Password123',
        );
        expect(emptyId.isSuccess, isFalse);
        expect(emptyId.errorCode, 'empty-identifier');

        final badPhone = await auth.signInWithIdentifierAndPassword(
          identifier: '12345',
          password: 'Password123',
        );
        expect(badPhone.isSuccess, isFalse);
        expect(badPhone.errorCode, 'invalid-phone-number');

        final badEmail = await auth.signInWithIdentifierAndPassword(
          identifier: 'not-an-email',
          password: 'Password123',
        );
        expect(badEmail.isSuccess, isFalse);
        expect(badEmail.errorCode, 'invalid-identifier');

        final shortPass = await auth.signInWithIdentifierAndPassword(
          identifier: 'citizen@gmail.com',
          password: '123',
        );
        expect(shortPass.isSuccess, isFalse);
        expect(shortPass.errorCode, 'weak-password');

        final adminSignIn = await auth.signInWithIdentifierAndPassword(
          identifier: 'admin@wakil.gov.np',
          password: 'AdminPassword123',
          rememberDevice: true,
        );
        expect(adminSignIn.isSuccess, isTrue);
        expect(adminSignIn.isFallbackMode, isTrue);
        expect(adminSignIn.user!.isAdmin, isTrue);
        expect(adminSignIn.destination, WorkspaceDestination.adminWorkspace);

        final phoneSignIn = await auth.signInWithIdentifierAndPassword(
          identifier: '9841234567',
          password: 'CitizenPass123',
          rememberDevice: true,
        );
        expect(phoneSignIn.isSuccess, isTrue);
        expect(phoneSignIn.user!.identifier, '+9779841234567');
        expect(phoneSignIn.user!.phoneNumber, '+9779841234567');
        expect(phoneSignIn.user!.isAdmin, isFalse);
        expect(phoneSignIn.destination, WorkspaceDestination.mainWorkspace);
      },
    );

    test('signInWithGoogle (US-06) & enterTestMode (US-07) & signOut', () async {
      final store = InMemoryKeyValueStore();
      final auth = AuthService.localFallback(
        sessionService: SessionService(store: store),
        fallbackGoogleEmail: 'bhugol.gautam1@gmail.com',
      );
      addTearDown(auth.dispose);

      final googleResult = await auth.signInWithGoogle(rememberDevice: true);
      expect(googleResult.isSuccess, isTrue);
      expect(googleResult.isFallbackMode, isTrue);
      expect(googleResult.user!.providerId, 'google.com');
      expect(googleResult.user!.email, 'bhugol.gautam1@gmail.com');
      expect(googleResult.destination, WorkspaceDestination.mainWorkspace);

      // Sign out preserving remembered identifier, then test clearRememberedDevice
      await auth.signOut(clearRememberedDevice: false);
      expect(auth.currentUser, isNull);
      expect(
        await auth.sessionService.getRememberedIdentifier(),
        'bhugol.gautam1@gmail.com',
      );

      await auth.signOut(clearRememberedDevice: true);
      expect(await auth.sessionService.getRememberedIdentifier(), isNull);

      // Test Mode (US-07)
      final testModeResult = await auth.enterTestMode();
      expect(testModeResult.isSuccess, isTrue);
      expect(testModeResult.user!.isTestMode, isTrue);
      expect(testModeResult.user!.providerId, 'test_mode');
      expect(testModeResult.session!.rememberDevice, isFalse);
      expect(testModeResult.destination, WorkspaceDestination.mainWorkspace);

      final restoredAfterTestMode = await auth.restoreSession();
      expect(restoredAfterTestMode, isNull);
    });

    test(
      'registerWithDetails, sendOtp, resendOtp & verifyOtp (US-08 to US-11)',
      () async {
        final auth = AuthService.localFallback(expectedTestOtp: '742918');
        addTearDown(auth.dispose);

        final badReg = await auth.registerWithDetails(
          fullName: '',
          email: 'bhugol.gautam1@gmail.com',
          phoneNumber: '9841234567',
          password: 'WakilLegal2026!',
        );
        expect(badReg.isSuccess, isFalse);
        expect(badReg.errorCode, 'invalid-name');

        final regResult = await auth.registerWithDetails(
          fullName: 'Bhugol Gautam',
          email: 'bhugol.gautam1@gmail.com',
          phoneNumber: '9841234567',
          password: 'WakilLegal2026!',
        );
        expect(regResult.isSuccess, isTrue);
        expect(regResult.requiresOtpVerification, isTrue);
        expect(regResult.verificationId, isNotEmpty);
        expect(regResult.user!.phoneNumber, '+9779841234567');

        final invalidSend = await auth.sendOtp(phoneNumber: '123');
        expect(invalidSend.isSuccess, isFalse);
        expect(invalidSend.errorCode, 'invalid-phone-number');

        final resend = await auth.resendOtp(phoneNumber: '9841234567');
        expect(resend.isSuccess, isTrue);
        expect(resend.phoneNumber, '+9779841234567');
        expect(resend.isFallbackMode, isTrue);

        final shortOtp = await auth.verifyOtp(otpCode: '742');
        expect(shortOtp.isSuccess, isFalse);
        expect(shortOtp.errorCode, 'invalid-otp-format');

        final wrongOtp = await auth.verifyOtp(otpCode: '000000');
        expect(wrongOtp.isSuccess, isFalse);
        expect(wrongOtp.errorCode, 'invalid-verification-code');

        final verified = await auth.verifyOtp(
          otpCode: '742918',
          verificationId: resend.verificationId,
          phoneNumber: '9841234567',
          rememberDevice: true,
        );
        expect(verified.isSuccess, isTrue);
        expect(verified.user!.providerId, 'phone');
        expect(verified.user!.email, 'bhugol.gautam1@gmail.com');
        expect(verified.destination, WorkspaceDestination.mainWorkspace);

        // Duplicate registration for verified account is rejected.
        final dupReg = await auth.registerWithDetails(
          fullName: 'Bhugol Gautam',
          email: 'bhugol.gautam1@gmail.com',
          phoneNumber: '9841234567',
          password: 'WakilLegal2026!',
        );
        expect(dupReg.isSuccess, isFalse);
        expect(dupReg.errorCode, 'email-already-in-use');

        // Phone sign-in now enforces the registered password.
        final wrongPhonePass = await auth.signInWithIdentifierAndPassword(
          identifier: '9841234567',
          password: 'WrongPassword123',
        );
        expect(wrongPhonePass.isSuccess, isFalse);
        expect(wrongPhonePass.errorCode, 'wrong-password');
      },
    );

    test(
      'verifyRecoveryIdentity & resetPassword with global revocation (US-12 & US-13)',
      () async {
        final store = InMemoryKeyValueStore();
        final auth = AuthService.localFallback(
          sessionService: SessionService(store: store),
        );
        addTearDown(auth.dispose);

        final invalidIdentity = await auth.verifyRecoveryIdentity('bad-input');
        expect(invalidIdentity.isSuccess, isFalse);
        expect(invalidIdentity.errorCode, 'invalid-identity');

        final phoneIdentity = await auth.verifyRecoveryIdentity('9841234567');
        expect(phoneIdentity.isSuccess, isTrue);
        expect(phoneIdentity.isEmailIdentity, isFalse);
        expect(phoneIdentity.normalizedIdentity, '+9779841234567');

        final emailIdentity = await auth.verifyRecoveryIdentity(
          'bhugol.gautam1@gmail.com',
        );
        expect(emailIdentity.isSuccess, isTrue);
        expect(emailIdentity.isEmailIdentity, isTrue);

        // Sign in first so an active remembered session exists.
        await auth.signInWithIdentifierAndPassword(
          identifier: 'bhugol.gautam1@gmail.com',
          password: 'OldPassword123!',
          rememberDevice: true,
        );
        expect(auth.sessionService.isAuthenticated, isTrue);
        expect(auth.sessionService.revocationEpoch, 0);

        // Weak password rejected.
        final weakReset = await auth.resetPassword(
          identity: 'bhugol.gautam1@gmail.com',
          newPassword: 'abc',
          revokeAllSessions: true,
        );
        expect(weakReset.isSuccess, isFalse);
        expect(weakReset.errorCode, 'weak-password');

        // Strong reset with global session revocation ON.
        final revokedReset = await auth.resetPassword(
          identity: 'bhugol.gautam1@gmail.com',
          newPassword: 'KathmanduLegal98#',
          revokeAllSessions: true,
        );
        expect(revokedReset.isSuccess, isTrue);
        expect(revokedReset.sessionsRevoked, isTrue);
        expect(auth.currentUser, isNull);
        expect(auth.sessionService.isAuthenticated, isFalse);
        expect(auth.sessionService.revocationEpoch, 1);
        expect(await auth.restoreSession(), isNull);

        // Old password fails while new password succeeds.
        final oldPassAttempt = await auth.signInWithIdentifierAndPassword(
          identifier: 'bhugol.gautam1@gmail.com',
          password: 'OldPassword123!',
        );
        expect(oldPassAttempt.isSuccess, isFalse);
        expect(oldPassAttempt.errorCode, 'wrong-password');

        final newPassAttempt = await auth.signInWithIdentifierAndPassword(
          identifier: 'bhugol.gautam1@gmail.com',
          password: 'KathmanduLegal98#',
        );
        expect(newPassAttempt.isSuccess, isTrue);

        // Reset with revokeAllSessions: false leaves epoch unchanged.
        final noRevokeReset = await auth.resetPassword(
          identity: 'bhugol.gautam1@gmail.com',
          newPassword: 'KathmanduLegal99#',
          revokeAllSessions: false,
        );
        expect(noRevokeReset.isSuccess, isTrue);
        expect(noRevokeReset.sessionsRevoked, isFalse);
        expect(auth.sessionService.revocationEpoch, 1);
      },
    );
  });

  group('Phase 0 — Widget & Responsive Flows (390x844 & 800x600)', () {
    for (final vp in viewports) {
      testWidgets(
        'LegalDisclaimerSheet Skip Auth path without overflow (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          final authService = AuthService.localFallback();
          addTearDown(authService.dispose);

          await pumpAndVerifyNoOverflow(
            tester,
            WakilApp(
              initialRoute: AppRouteState.splash,
              authService: authService,
            ),
          );

          await tester.tap(find.byKey(const Key('get_started_button')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('disclaimer_title')), findsOneWidget);
          final checkbox = tester.widget<Checkbox>(
            find.byKey(const Key('consent_checkbox')),
          );
          expect(checkbox.value, isFalse);

          // Skip Auth works directly without checking consent box.
          final skipFinder = find.byKey(const Key('skip_auth_button'));
          await tester.ensureVisible(skipFinder);
          await tester.tap(skipFinder);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('citizen_workspace_screen')),
            findsOneWidget,
          );
          expect(authService.currentUser?.isTestMode, isTrue);
          expect(authService.sessionService.activeSession?.isTestMode, isTrue);
        },
      );
    }

    testWidgets(
      'LegalDisclaimerSheet standalone validates consent & triggers onSkip',
      (WidgetTester tester) async {
        configureViewport(tester, mobileViewport);
        var acceptedCount = 0;
        var skippedCount = 0;

        await pumpAndVerifyNoOverflow(
          tester,
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: LegalDisclaimerSheet(
                  onAccepted: () => acceptedCount++,
                  onSkip: () => skippedCount++,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('accept_continue_button')));
        await tester.pumpAndSettle();
        expect(acceptedCount, 0);
        expect(
          find.textContaining('You must agree to the Terms'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('skip_auth_button')));
        await tester.pumpAndSettle();
        expect(skippedCount, 1);
      },
    );

    for (final vp in viewports) {
      testWidgets(
        'LoginScreen Remember Device toggle & Google Sign-In (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          final authService = AuthService.localFallback();
          addTearDown(authService.dispose);

          await pumpAndVerifyNoOverflow(
            tester,
            WakilApp(
              initialRoute: AppRouteState.login,
              authService: authService,
            ),
          );

          final checkboxFinder = find.byKey(
            const Key('remember_device_checkbox'),
          );
          expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

          await tester.ensureVisible(checkboxFinder);
          await tester.tap(checkboxFinder);
          await tester.pumpAndSettle();
          expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

          await tester.tap(find.text('Remember Device'));
          await tester.pumpAndSettle();
          expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

          final googleFinder = find.byKey(const Key('google_signin_button'));
          expect(googleFinder, findsOneWidget);
          expect(tester.widget<SocialMediaCard>(googleFinder), isA<SocialMediaCard>());
          expect(
            find.descendant(
              of: googleFinder,
              matching: find.byType(CustomPaint),
            ),
            findsWidgets,
          );

          await tester.ensureVisible(googleFinder);
          await tester.tap(googleFinder);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('citizen_workspace_screen')),
            findsOneWidget,
          );
          expect(authService.sessionService.isAuthenticated, isTrue);
          expect(
            authService.sessionService.activeSession?.role,
            WakilUserRole.citizen,
          );
          expect(
            authService.sessionService.activeSession?.identifier,
            'citizen.google@wakil.ai',
          );
        },
      );
    }

    testWidgets(
      'LoginScreen exposes Remember Device toggle state cleanly standalone',
      (WidgetTester tester) async {
        configureViewport(tester, testViewport);
        String? signedInIdentifier;

        await pumpAndVerifyNoOverflow(
          tester,
          MaterialApp(
            home: LoginScreen(
              onToRegistration: () {},
              onToForgotPassword: () {},
              onLoginSuccess: (id) => signedInIdentifier = id,
              onSkipAuth: () {},
            ),
          ),
        );

        final googleFinder = find.byKey(const Key('google_signin_button'));
        await tester.ensureVisible(googleFinder);
        await tester.tap(googleFinder);
        await tester.pumpAndSettle();

        expect(signedInIdentifier, isNotNull);
        expect(
          RoleRoutingService().isAdminIdentifier(signedInIdentifier!),
          isFalse,
        );
      },
    );

    for (final vp in viewports) {
      testWidgets(
        'RegistrationScreen validation & submit without overflow (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          String? submittedEmail;
          String? submittedPhone;

          await pumpAndVerifyNoOverflow(
            tester,
            MaterialApp(
              home: RegistrationScreen(
                onToSignIn: () {},
                onRegistrationSuccess: (_, email, phone, _) {
                  submittedEmail = email;
                  submittedPhone = phone;
                },
              ),
            ),
          );

          expect(find.byKey(const Key('registration_title')), findsOneWidget);
          expect(find.text('+977'), findsOneWidget);

          await tester.enterText(
            find.byKey(const Key('registration_name_input')),
            'Bhugol Gautam',
          );
          await tester.enterText(
            find.byKey(const Key('registration_email_input')),
            'bhugol.gautam1@gmail.com',
          );
          await tester.enterText(
            find.byKey(const Key('registration_phone_input')),
            '9841234567',
          );
          await tester.enterText(
            find.byKey(const Key('registration_password_input')),
            'WakilLegal2026!',
          );
          final submitFinder = find.byKey(
            const Key('registration_submit_button'),
          );
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          expect(submittedEmail, 'bhugol.gautam1@gmail.com');
          expect(submittedPhone, '+9779841234567');
        },
      );
    }

    for (final vp in viewports) {
      testWidgets(
        'OtpVerificationScreen Clear Code disables Verify & 6 digits enables/verifies (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          var verifiedCount = 0;

          await pumpAndVerifyNoOverflow(
            tester,
            MaterialApp(
              home: OtpVerificationScreen(
                phoneNumber: '+977 9841234567',
                onBack: () {},
                onOtpVerified: () => verifiedCount++,
                initialTimerSeconds: 0,
              ),
            ),
          );

          final verifyButtonFinder = find.byKey(const Key('otp_verify_button'));
          expect(
            tester.widget<ElevatedButton>(verifyButtonFinder).onPressed,
            isNull,
          );

          // Enter 5 digits -> still disabled
          for (var i = 0; i < 5; i++) {
            await tester.enterText(find.byKey(Key('otp_box_$i')), '${i + 1}');
          }
          await tester.pumpAndSettle();
          expect(
            tester.widget<ElevatedButton>(verifyButtonFinder).onPressed,
            isNull,
          );

          // Enter 6th digit -> verify button becomes enabled
          await tester.enterText(find.byKey(const Key('otp_box_5')), '6');
          await tester.pumpAndSettle();
          expect(
            tester.widget<ElevatedButton>(verifyButtonFinder).onPressed,
            isNotNull,
          );

          // Clear Code resets all 6 boxes and disables otp_verify_button again
          final clearFinder = find.byKey(const Key('otp_clear_button'));
          await tester.ensureVisible(clearFinder);
          await tester.tap(clearFinder);
          await tester.pumpAndSettle();

          for (var i = 0; i < 6; i++) {
            final field = tester.widget<TextFormField>(
              find.byKey(Key('otp_box_$i')),
            );
            expect(field.controller!.text, isEmpty);
          }
          expect(
            tester.widget<ElevatedButton>(verifyButtonFinder).onPressed,
            isNull,
          );
          expect(verifiedCount, 0);

          // Re-enter 6 digits -> tap Verify -> invokes onOtpVerified
          const otp = '742918';
          for (var i = 0; i < 6; i++) {
            await tester.enterText(find.byKey(Key('otp_box_$i')), otp[i]);
          }
          await tester.pumpAndSettle();
          expect(
            tester.widget<ElevatedButton>(verifyButtonFinder).onPressed,
            isNotNull,
          );

          await tester.ensureVisible(verifyButtonFinder);
          await tester.tap(verifyButtonFinder);
          await tester.pumpAndSettle();
          expect(verifiedCount, 1);
        },
      );
    }

    for (final vp in viewports) {
      testWidgets(
        'PasswordRecoveryScreen 4-bar strength gauge & global revocation ON (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          String? resetIdentity;
          String? resetPassword;
          bool? resetRevoke;

          await pumpAndVerifyNoOverflow(
            tester,
            MaterialApp(
              home: PasswordRecoveryScreen(
                onBack: () {},
                onResetSuccess: (id, pwd, revoke) {
                  resetIdentity = id;
                  resetPassword = pwd;
                  resetRevoke = revoke;
                },
              ),
            ),
          );

          await tester.enterText(
            find.byKey(const Key('recovery_identity_input')),
            'bhugol.gautam1@gmail.com',
          );
          await tester.tap(
            find.byKey(const Key('recovery_verify_identity_button')),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Identity verified for bhugol.gautam1@gmail.com'),
            findsOneWidget,
          );

          List<Color?> barColors() {
            final gauge = tester.widget<Row>(
              find.byKey(const Key('password_strength_gauge')),
            );
            return gauge.children
                .whereType<Expanded>()
                .map((e) => e.child)
                .whereType<Container>()
                .map((c) => (c.decoration as BoxDecoration?)?.color)
                .toList();
          }

          Future<void> assertStrengthTier({
            required String input,
            required String expectedLabel,
            required int expectedFilledBars,
          }) async {
            await tester.enterText(
              find.byKey(const Key('recovery_new_password_input')),
              input,
            );
            await tester.pumpAndSettle();

            final label = tester.widget<Text>(
              find.byKey(const Key('password_strength_label')),
            );
            expect(label.data, expectedLabel);

            final colors = barColors();
            expect(colors.length, 4);
            for (var i = 0; i < 4; i++) {
              expect(
                colors[i],
                i < expectedFilledBars
                    ? AppColors.primaryBlack
                    : AppColors.surfaceHighest,
              );
            }
          }

          expect(
            tester
                .widget<Text>(find.byKey(const Key('password_strength_label')))
                .data,
            'None',
          );
          expect(
            barColors(),
            List<Color>.filled(4, AppColors.surfaceHighest),
          );

          await assertStrengthTier(
            input: 'abc',
            expectedLabel: 'Weak',
            expectedFilledBars: 1,
          );
          await assertStrengthTier(
            input: 'abcdefg1',
            expectedLabel: 'Fair',
            expectedFilledBars: 2,
          );
          await assertStrengthTier(
            input: 'Abcdefg1',
            expectedLabel: 'Strong',
            expectedFilledBars: 3,
          );
          await assertStrengthTier(
            input: 'StrongPass2026!',
            expectedLabel: 'Very Strong',
            expectedFilledBars: 4,
          );

          final switchFinder = find.byKey(
            const Key('global_session_revocation_switch'),
          );
          await tester.ensureVisible(switchFinder);
          expect(tester.widget<Switch>(switchFinder).value, isTrue);

          // Toggle OFF then back ON to confirm interactive state before submit.
          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(switchFinder).value, isFalse);

          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(switchFinder).value, isTrue);

          final submitFinder = find.byKey(const Key('recovery_submit_button'));
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          expect(resetIdentity, 'bhugol.gautam1@gmail.com');
          expect(resetPassword, 'StrongPass2026!');
          expect(resetRevoke, isTrue);
        },
      );
    }

    testWidgets(
      'WakilApp PasswordRecoveryScreen global revocation ON bumps revocationEpoch',
      (WidgetTester tester) async {
        configureViewport(tester, testViewport);
        final store = InMemoryKeyValueStore();
        final authService = AuthService.localFallback(
          sessionService: SessionService(store: store),
        );
        addTearDown(authService.dispose);

        await authService.signInWithIdentifierAndPassword(
          identifier: 'bhugol.gautam1@gmail.com',
          password: 'OldPassword123!',
          rememberDevice: true,
        );
        expect(authService.sessionService.revocationEpoch, 0);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            initialRoute: AppRouteState.passwordRecovery,
            authService: authService,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('recovery_identity_input')),
          'bhugol.gautam1@gmail.com',
        );
        await tester.tap(
          find.byKey(const Key('recovery_verify_identity_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('recovery_new_password_input')),
          'KathmanduLegal98#',
        );
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(const Key('recovery_submit_button'));
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(find.text('Welcome to Wakil'), findsOneWidget);
        expect(authService.sessionService.revocationEpoch, 1);
        expect(authService.sessionService.isAuthenticated, isFalse);
      },
    );

    testWidgets(
      'US-07: Unchecking Remember Device in LoginScreen propagates rememberDevice=false and skips restart restore',
      (WidgetTester tester) async {
        configureViewport(tester, testViewport);
        final sharedStore = InMemoryKeyValueStore();
        final auth1 = AuthService.localFallback(
          sessionService: SessionService(store: sharedStore),
        );
        addTearDown(auth1.dispose);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            initialRoute: AppRouteState.login,
            authService: auth1,
          ),
        );

        final checkboxFinder = find.byKey(
          const Key('remember_device_checkbox'),
        );
        expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

        await tester.ensureVisible(checkboxFinder);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

        await tester.enterText(
          find.byKey(const Key('email_phone_input')),
          'bhugol.gautam1@gmail.com',
        );
        await tester.enterText(
          find.byKey(const Key('password_input')),
          'WakilPass123!',
        );
        final submitFinder = find.byKey(const Key('sign_in_submit_button'));
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('citizen_workspace_screen')),
          findsOneWidget,
        );
        expect(auth1.sessionService.isAuthenticated, isTrue);
        expect(auth1.sessionService.rememberDeviceEnabled, isFalse);
        expect(auth1.sessionService.activeSession?.rememberDevice, isFalse);
        expect(
          await sharedStore.read(SessionService.sessionRecordKey),
          isNull,
        );

        // Simulated restart with fresh AuthService on same store stays on splash.
        final auth2 = AuthService.localFallback(
          sessionService: SessionService(store: sharedStore),
        );
        addTearDown(auth2.dispose);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            key: const ValueKey('restarted_app'),
            initialRoute: AppRouteState.splash,
            authService: auth2,
          ),
        );
        expect(find.byKey(const Key('splash_emblem')), findsOneWidget);
        expect(
          find.byKey(const Key('citizen_workspace_screen')),
          findsNothing,
        );
        expect(await auth2.restoreSession(), isNull);
      },
    );

    testWidgets(
      'US-13 -> US-07: Global Session Revocation leaves LoginScreen checkbox unchecked until re-checked',
      (WidgetTester tester) async {
        configureViewport(tester, testViewport);
        final sharedStore = InMemoryKeyValueStore();
        final authService = AuthService.localFallback(
          sessionService: SessionService(store: sharedStore),
        );
        addTearDown(authService.dispose);

        await authService.signInWithIdentifierAndPassword(
          identifier: 'bhugol.gautam1@gmail.com',
          password: 'OldPassword123!',
          rememberDevice: true,
        );
        expect(authService.sessionService.rememberDeviceEnabled, isTrue);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            initialRoute: AppRouteState.passwordRecovery,
            authService: authService,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('recovery_identity_input')),
          'bhugol.gautam1@gmail.com',
        );
        await tester.tap(
          find.byKey(const Key('recovery_verify_identity_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('recovery_new_password_input')),
          'KathmanduLegal98#',
        );
        await tester.pumpAndSettle();

        final resetSubmitFinder = find.byKey(
          const Key('recovery_submit_button'),
        );
        await tester.ensureVisible(resetSubmitFinder);
        await tester.tap(resetSubmitFinder);
        await tester.pumpAndSettle();

        expect(find.text('Welcome to Wakil'), findsOneWidget);
        expect(authService.sessionService.revocationEpoch, 1);
        expect(authService.sessionService.isAuthenticated, isFalse);

        final checkboxFinder = find.byKey(
          const Key('remember_device_checkbox'),
        );
        expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

        // Re-check Remember Device and sign in -> persists rememberDevice = true
        await tester.ensureVisible(checkboxFinder);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

        await tester.enterText(
          find.byKey(const Key('email_phone_input')),
          'bhugol.gautam1@gmail.com',
        );
        await tester.enterText(
          find.byKey(const Key('password_input')),
          'KathmanduLegal98#',
        );
        final signInFinder = find.byKey(const Key('sign_in_submit_button'));
        await tester.ensureVisible(signInFinder);
        await tester.tap(signInFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('citizen_workspace_screen')),
          findsOneWidget,
        );
        expect(authService.sessionService.rememberDeviceEnabled, isTrue);
        expect(authService.sessionService.activeSession?.rememberDevice, isTrue);
        expect(
          await sharedStore.read(SessionService.sessionRecordKey),
          isNotNull,
        );
      },
    );

    testWidgets(
      'US-07 & US-14: WakilApp splash auto-restores remembered Citizen & Admin sessions to matching workspace',
      (WidgetTester tester) async {
        configureViewport(tester, testViewport);

        // 1. Citizen persisted session restores directly to MainWorkspaceScreen.
        final citizenStore = InMemoryKeyValueStore();
        final citizenWriter = SessionService(store: citizenStore);
        await citizenWriter.saveSession(
          userId: 'uid_citizen_saved',
          identifier: 'bhugol.gautam1@gmail.com',
          email: 'bhugol.gautam1@gmail.com',
          role: WakilUserRole.citizen,
          rememberDevice: true,
        );
        await citizenWriter.dispose();

        final citizenAuth = AuthService.localFallback(
          sessionService: SessionService(store: citizenStore),
        );
        addTearDown(citizenAuth.dispose);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            initialRoute: AppRouteState.splash,
            authService: citizenAuth,
          ),
        );
        expect(
          find.byKey(const Key('citizen_workspace_screen')),
          findsOneWidget,
        );
        expect(find.textContaining('bhugol.gautam1@gmail.com'), findsOneWidget);

        // 2. Admin persisted session restores directly to AdminWorkspaceScreen.
        final adminStore = InMemoryKeyValueStore();
        final adminWriter = SessionService(store: adminStore);
        await adminWriter.saveSession(
          userId: 'uid_admin_saved',
          identifier: 'admin.bhugol@wakil.gov.np',
          email: 'admin.bhugol@wakil.gov.np',
          role: WakilUserRole.admin,
          rememberDevice: true,
        );
        await adminWriter.dispose();

        final adminAuth = AuthService.localFallback(
          sessionService: SessionService(store: adminStore),
        );
        addTearDown(adminAuth.dispose);

        await pumpAndVerifyNoOverflow(
          tester,
          WakilApp(
            key: const ValueKey('admin_restore_app'),
            initialRoute: AppRouteState.splash,
            authService: adminAuth,
          ),
        );
        expect(find.byKey(const Key('admin_workspace_screen')), findsOneWidget);
        expect(
          find.textContaining('admin.bhugol@wakil.gov.np'),
          findsOneWidget,
        );
      },
    );

    for (final vp in viewports) {
      testWidgets(
        'MainWorkspaceScreen prompt chip tap & zero overflow (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          var signedOut = false;

          await pumpAndVerifyNoOverflow(
            tester,
            MaterialApp(
              home: MainWorkspaceScreen(
                userIdentifier: 'bhugol.gautam1@gmail.com',
                onSignOut: () => signedOut = true,
              ),
            ),
          );

          expect(find.text('Namaste, User'), findsOneWidget);
          expect(find.byKey(const Key('main_workspace_title')), findsOneWidget);
          expect(find.text('SUGGESTED TOPICS'), findsOneWidget);
          expect(
            find.textContaining('bhugol.gautam1@gmail.com'),
            findsOneWidget,
          );

          const prompt = 'Analyze a residential tenancy agreement in Nepal';
          final chipFinder = find.text(prompt);
          await tester.ensureVisible(chipFinder);
          await tester.tap(chipFinder);
          await tester.pumpAndSettle();

          final queryField = tester.widget<TextField>(find.byType(TextField));
          expect(queryField.controller?.text, prompt);

          // Open workspace drawer & verify statutory collections
          await tester.tap(find.byTooltip('Workspace Menu'));
          await tester.pumpAndSettle();
          expect(find.text('Constitution of Nepal (2072)'), findsOneWidget);
          expect(find.text('Muluki Dewani Samhita'), findsOneWidget);
          expect(find.text('Muluki Apradh Samhita'), findsOneWidget);

          await tester.tap(find.text('Sign Out'));
          await tester.pumpAndSettle();
          expect(signedOut, isTrue);
        },
      );
    }

    for (final vp in viewports) {
      testWidgets(
        'AdminWorkspaceScreen KPIs, Trigger Index Sync & Ingestion Logs (${vp.label})',
        (WidgetTester tester) async {
          configureViewport(tester, vp.size);
          var signedOut = false;

          await pumpAndVerifyNoOverflow(
            tester,
            MaterialApp(
              home: AdminWorkspaceScreen(
                userEmail: 'admin.bhugol@wakil.gov.np',
                onSignOut: () => signedOut = true,
              ),
            ),
          );

          expect(find.byKey(const Key('admin_console_title')), findsOneWidget);
          expect(
            find.textContaining('admin.bhugol@wakil.gov.np'),
            findsOneWidget,
          );
          expect(find.text('All Systems Operational'), findsOneWidget);
          expect(find.text('ap-south-1 (KTM Edge)'), findsOneWidget);

          // KPI Cards
          expect(find.text('Total Users'), findsOneWidget);
          expect(find.text('14,820'), findsOneWidget);
          expect(find.text('Daily Queries'), findsOneWidget);
          expect(find.text('8,430'), findsOneWidget);
          expect(find.text('Avg RAG Latency'), findsOneWidget);
          expect(find.text('412'), findsOneWidget);
          expect(find.text('Flagged Query'), findsOneWidget);
          expect(find.text('14'), findsOneWidget);

          // Query Volume & RAG Pipeline cards
          expect(find.text('QUERY VOLUME'), findsOneWidget);
          expect(find.text('Peak: Friday'), findsOneWidget);
          expect(find.text('Gemini 1.5 Pro'), findsOneWidget);
          expect(find.text('Qdrant Vector DB'), findsOneWidget);
          expect(find.text('Sync Pending'), findsOneWidget);
          expect(find.text('BM25 Hybrid Corpus'), findsOneWidget);

          // Trigger Index Sync transitions Qdrant Vector DB from Sync Pending -> Synced
          final syncButtonFinder = find.text('Trigger Index Sync');
          await tester.ensureVisible(syncButtonFinder);
          await tester.tap(syncButtonFinder);
          await tester.pumpAndSettle();

          expect(find.text('Sync Pending'), findsNothing);
          expect(find.text('Synced'), findsNWidgets(2));
          expect(
            find.text(
              'Qdrant Vector DB index synchronized with 128k legal embeddings.',
            ),
            findsOneWidget,
          );

          // View Ingestion & Error Logs opens bottom sheet
          final logsButtonFinder = find.text('View Ingestion & Error Logs');
          await tester.ensureVisible(logsButtonFinder);
          await tester.tap(logsButtonFinder);
          await tester.pumpAndSettle();

          expect(find.text('Ingestion & Error Logs'), findsOneWidget);
          expect(
            find.text('BM25 Hybrid Corpus refreshed (48 Nepal Acts)'),
            findsOneWidget,
          );
          expect(
            find.text('Qdrant Vector DB delta embeddings verified'),
            findsOneWidget,
          );

          // Dismiss bottom sheet and let sync SnackBar auto-expire before tapping nav tabs
          await tester.tapAt(const Offset(20, 20));
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();

          // Switch secondary bottom nav tabs with zero overflow
          for (final tabLabel in ['Corpus', 'Users', 'Audit & Config']) {
            await tester.tap(find.text(tabLabel));
            await tester.pumpAndSettle();
          }

          await tester.tap(find.byKey(const Key('admin_sign_out_button')));
          await tester.pumpAndSettle();
          expect(signedOut, isTrue);
        },
      );
    }
  });
}

class _ThrowingSecureStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw MissingPluginException('No platform channel in headless test');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw MissingPluginException('No platform channel in headless test');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw MissingPluginException('No platform channel in headless test');
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw MissingPluginException('No platform channel in headless test');
  }
}
