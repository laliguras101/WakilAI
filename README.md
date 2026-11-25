# Wakil AI (वकील AI)

**Legal Intelligence for Nepal** — Flutter 3 / Dart 3 client application aligned for Sprint 1–2 Phase 0 (onboarding, statutory compliance consent, multi-modal authentication, OTP verification, password recovery with global session revocation, role-based workspace routing, Firebase/Firestore security foundations, and Swiss / Gemini Light Monochrome design system alignment).

---

## Tech Stack & Dependencies

- **Framework:** Flutter (`>=3.47.0`, verified on Flutter `3.47.5`) / Dart (`^3.13.4`)
- **Application Package:** `wakil_ai` (`version: 1.0.0+1`)
- **Android Application ID:** `np.gov.wakil.wakil_ai` (`android/app/build.gradle.kts`)
- **Core Packages (`pubspec.yaml`):**
  - `firebase_core: ^5.2.0` (`5.2.0` locked)
  - `firebase_auth: ^7.1.0` (`7.1.0` locked)
  - `cloud_firestore: ^7.2.0` (`7.2.0` locked)
  - `google_sign_in: ^7.2.0` (`7.2.0` locked)
  - `flutter_secure_storage: ^11.2.0` (`11.2.0` locked)
  - `cupertino_icons: ^1.0.8`
- **Dev Dependencies:**
  - `flutter_test` (SDK)
  - `flutter_lints: ^6.0.0`

---

## Phase 0 Architecture

```text
WakilAI/
├── .env.example                            # Optional local Firebase/emulator overrides (never commit .env)
├── .gitignore                              # Ignores .env, keystores, service-account JSONs, .firebase/, node_modules/
├── firebase.json                           # Named Firestore DB binding + local emulator config (127.0.0.1:8085)
├── firestore.rules                         # Default-deny owner-scoped security rules & schema validators
├── firebase-blueprint.json                 # Entity schemas for all 7 user-scoped Firestore collections
├── firestore.test.js                       # Node.js (@firebase/rules-unit-testing) Firestore security rules suite
├── pubspec.yaml / pubspec.lock             # Flutter & Firebase dependencies
├── android/app/build.gradle.kts            # Android namespace & applicationId: np.gov.wakil.wakil_ai
├── lib/
│   ├── main.dart                           # main() -> FirebaseBootstrap.initializeSafely(), WakilApp, Light Monochrome ThemeData, service-wired routing
│   ├── constants/
│   │   └── app_colors.dart                 # AppColors Swiss / Gemini Light Monochrome tokens & semantic aliases
│   ├── services/
│   │   ├── services.dart                   # Barrel export for Wakil backend/session services
│   │   ├── firebase_bootstrap.dart         # FirebaseBootstrap (live init + deterministic localFallback)
│   │   ├── auth_service.dart               # WakilAuthRepository & AuthService (Auth, Google, OTP, Recovery, Test Mode)
│   │   ├── session_service.dart            # SessionService, ResilientSecureStorage, Remember Device & Revocation
│   │   └── role_routing_service.dart       # RoleRoutingService (US-14 Admin vs Citizen resolution)
│   └── view/
│       ├── onboarding/
│       │   ├── splash_screen.dart          # US-01 Splash screen & emblem branding
│       │   └── legal_disclaimer_sheet.dart # US-02 & US-03 Mandatory legal disclaimer & consent checkbox
│       ├── authentication/
│       │   ├── login_screen.dart           # US-04..US-07 Sign In, Remember Device, Skip Auth (Test Mode)
│       │   ├── registration_screen.dart    # US-08 Sign Up form with +977 Nepali phone validation
│       │   ├── otp_verification_screen.dart# US-09..US-11 6-digit OTP card, 120s timer, resend & Clear Code
│       │   ├── password_recovery_screen.dart# US-12 & US-13 Identity verification, 4-bar gauge & revocation
│       │   └── widgets/
│       │       └── social_media_card.dart  # US-06 Google Sign-In pill card
│       └── dashboard/
│           ├── main_workspace_screen.dart  # US-14 Citizen / Legal Advocate workspace
│           └── admin_workspace_screen.dart # US-14 System Administrator workspace
└── test/
    ├── widget_test.dart                    # Sprint 1–2 user story widget test suite (US-01–US-14)
    └── dynamic_user_flow_test.dart         # End-to-end CUJ widget verification journeys
```

---

## Swiss / Gemini Light Monochrome Design Tokens

`lib/constants/app_colors.dart` (`AppColors`) defines the **Swiss / Gemini Light Monochrome** token palette, mapped in `lib/main.dart` (`_buildLightMonochromeTheme()` -> `ThemeData` with `useMaterial3: true`, `Brightness.light`, `ColorScheme.light(...)`, pill-shaped button themes, `#F3F3F4` inputs, and `#000000` checkboxes/switches):

### Surface Hierarchy

| Hex | `AppColors` Constant | Role / Usage |
|---|---|---|
| `#FFFFFF` | `surfacePure` (alias `surfaceCard`) | Primary scaffold canvas, elevated modal/sheet cards, header fill |
| `#F9F9FA` | `surfaceCanvas` (alias `surfaceBackground`) | Subtle off-white canvas and backdrop surface |
| `#F3F3F4` | `surfaceLow` | Form inputs, starter prompt chips, Google pill, OTP digit pills, KPI/service cards, accordion, security card, emblem squircle |
| `#EEEEEF` | `surfaceContainer` | Trust/status/role/peak pills (`CONSTITUTION • MULUKI CODES`, `All Systems Operational`, `ADMIN`, `Peak: Friday`) |
| `#E8E8E9` | `surfaceHigh` | Active/focused OTP digit box, `+977` phone prefix chip, password reset icon circle |
| `#E2E2E3` | `surfaceHighest` (alias `borderSubtle`) | 1px dividers, secondary outline/fill pills (`View Ingestion & Error Logs`), unfilled strength bars, progress tracks, non-peak chart bars |

### Inks, Outlines & Semantic Tokens

| Hex | `AppColors` Constant | Role / Usage |
|---|---|---|
| `#000000` | `primaryBlack` | Primary pill CTAs, brand emblem circles, active status dots, waveform button, filled strength bars, active checkbox/switch, peak chart bar |
| `#1A1C1D` | `textPrimary` | Display/section headings, body input text, KPI values, active navigation labels |
| `#47464B` | `textOnVariant` | Registration field labels, KPI titles/sublabels, inactive navigation labels, jurisprudence pill text |
| `#5D5E66` | `textSecondary` | Subtitles, helper copy, `Ask Wakil...` placeholder, secondary links |
| `#77767B` | `textMuted` | Input placeholders, `SUGGESTED TOPICS`, footer disclaimer, unfilled OTP `·` indicator |
| `#C8C5CB` | `outlineVariant` | Bottom-sheet drag handle (rendered at `0.60` opacity) |
| `#BA1A1A` | `crimsonError` (alias `crimsonRed`) | Validation error messages, alert icons, error status dots |
| `#93000A` | `onErrorContainer` | Text inside error/alert banners |
| `#FFDAD6` | `errorContainer` | Background fill for error/alert banners |

### Google 4-Color Brand Mark (`SocialMediaCard`)

| Hex | `AppColors` Constant | Role / Usage |
|---|---|---|
| `#4285F4` | `googleBlue` | Google "G" mark — blue segment |
| `#34A853` | `googleGreen` | Google "G" mark — green segment |
| `#FBBC05` | `googleYellow` | Google "G" mark — yellow segment |
| `#EA4335` | `googleRed` | Google "G" mark — red segment |

---

## Firebase Setup & Android Guardrail

### 1. Android `applicationId` Guardrail (`np.gov.wakil.wakil_ai`)

`android/app/build.gradle.kts` sets:

```kotlin
namespace = "np.gov.wakil.wakil_ai"
defaultConfig {
    applicationId = "np.gov.wakil.wakil_ai"
}
```

> **WARNING:** **Never** copy the legacy Android/Kotlin `google-services.json` (`package_name: "com.aistudio.wakillegal.nplk7q"`) into `android/app/`. A mismatched `google-services.json` package name breaks Android Gradle builds. Always generate Firebase config specifically for `np.gov.wakil.wakil_ai`.

### 2. Configuring Live Firebase with `flutterfire configure`

To attach your Firebase project for live Authentication and Firestore:

1. Install and authenticate the Firebase CLI and FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   firebase login
   ```
2. Run FlutterFire configuration targeting `np.gov.wakil.wakil_ai`:
   ```bash
   flutterfire configure --android-package-name=np.gov.wakil.wakil_ai
   ```
   This generates `lib/firebase_options.dart` and an Android `android/app/google-services.json` bound to `np.gov.wakil.wakil_ai`.

### 3. Named Cloud Firestore Database, Rules & Blueprint

- **Named Database (`firebase.json` & `FirebaseBootstrap`):**
  - Database ID: `ai-studio-android-wakil-77bdd334-2113-412c-86b4-be03ef0044f1`
  - Configured in `firebase.json` under `firestore[0].database` and referenced by `FirebaseBootstrap.defaultFirestoreDatabaseId` (`lib/services/firebase_bootstrap.dart`).
  - `FirebaseBootstrap.firestoreOrNull()` retrieves `FirebaseFirestore.instanceFor(app: targetApp, databaseId: databaseId ?? _state.firestoreDatabaseId)`.
- **Security Rules (`firestore.rules`):**
  - Enforces a global default-deny (`match /{document=**} { allow read, write: if false; }`) and owner-only (`isOwner(userId)` + `isValidId(...)`) access under `/users/{userId}` with strict field whitelists (`hasAll` / `hasOnly`), type/bound validation, timestamp guards (`<= request.time`), and a parent-existence gate on chat messages (`exists(/databases/$(database)/documents/users/$(userId)/chats/$(chatId))`).
- **Schema Blueprint (`firebase-blueprint.json`):**
  - Defines the 7 user-scoped entities and Firestore paths:
    - `/users/{userId}/chats/{chatId}` (`ChatSession`)
    - `/users/{userId}/chats/{chatId}/messages/{messageId}` (`ChatMessage`)
    - `/users/{userId}/documents/{docId}` (`LegalDocument`)
    - `/users/{userId}/corpus/{corpusId}` (`CorpusDocument`)
    - `/users/{userId}/managed_users/{managedUserId}` (`ManagedUser`)
    - `/users/{userId}/flagged_audits/{auditId}` (`FlaggedAudit`)
    - `/users/{userId}/settings/{settingId}` (`SystemConfig`)

### 4. Local Environment Overrides (`.env.example`)

- Firebase AI Logic (`Firebase.ai`) uses App Check, so no client-side `GEMINI_API_KEY` is required.
- For optional local overrides, copy `.env.example` to `.env` (never commit `.env` — `.gitignore` ignores `.env` and `.env.*` while preserving `!.env.example`):
  - `GCP_PROJECT`
  - `FIRESTORE_EMULATOR_HOST=127.0.0.1:8085`
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_API_KEY`
  - `FIREBASE_APP_ID`
  - `FIREBASE_MESSAGING_SENDER_ID`

### 5. Offline & `Skip Auth (Test Mode)` Local Fallback

Wakil is designed to run cleanly without crashing when `google-services.json` or `firebase_options.dart` is absent, when offline, in `Skip Auth (Test Mode)`, or in headless `flutter test`:

- **`FirebaseBootstrap.initializeSafely(...)`** catches configuration, plugin, and platform-channel errors and transitions to `FirebaseBackendMode.localFallback`.
- **`AuthService` (`WakilAuthRepository`)** uses live `FirebaseAuth` and `GoogleSignIn` when `FirebaseBootstrap.authOrNull` is available, and automatically switches to deterministic local/offline behavior otherwise (or via `AuthService.localFallback(...)`).
- **`SessionService` (`ResilientSecureStorage`)** wraps `FlutterSecureStorage` (`AndroidOptions(storageNamespace: 'wakil_ai_session')`) and transparently switches to `InMemoryKeyValueStore` / in-memory fallback when native platform channels are unavailable.
- **`Skip Auth (Test Mode)`** (`Explore in Test Mode` on `SplashScreen`, `Skip Auth (Test Mode)` on `LegalDisclaimerSheet` and `LoginScreen`) enters the workspace immediately via `AuthService.enterTestMode(...)` with `isTestMode: true` and `rememberDevice: false`.

---

## Implemented User Stories (`US-01`–`US-14`)

| Story | Area | Summary of Implementation |
|---|---|---|
| **US-01** | Onboarding Splash | `SplashScreen` displays the Scales of Justice emblem (`Key('splash_emblem')`), `'Wakil'` title (`Key('app_title')`), `'Legal Intelligence for Nepal'` tagline (`Key('app_tagline')`), statutory scope pill (`CONSTITUTION • MULUKI CODES`), `'Get Started'` CTA (`Key('get_started_button')`), and `'Explore in Test Mode'` (`Key('skip_to_test_mode')`). |
| **US-02** | Legal Disclaimer Sheet | `LegalDisclaimerSheet` presents the informational-only AI legal notice (`Key('disclaimer_title')`) and an expandable statutory scope accordion (`Key('scope_accordion_toggle')`) referencing the Constitution of Nepal and Muluki Codes. |
| **US-03** | Consent Validation | Mandatory `Checkbox` (`Key('consent_checkbox')`, defaulting to `false`) blocks `'Accept & Continue'` (`Key('accept_continue_button')`) with `'You must agree to the Terms & Legal Disclaimer to continue.'` until checked; consent persistence is supported in `SessionService` (`hasAcceptedDisclaimer` / `setDisclaimerAccepted`). |
| **US-04** | Sign-In Form | `LoginScreen` validates email or Nepali mobile (`+977`) identifier (`Key('email_phone_input')`) and password (`Key('password_input')`, minimum 6 characters), backed by `AuthService.signInWithIdentifierAndPassword`. |
| **US-05** | Password Visibility Toggle | Interactive eye-icon toggle (`Key('password_visibility_toggle')` on `LoginScreen`, `Key('registration_password_toggle')` on `RegistrationScreen`, `Key('recovery_password_toggle')` on `PasswordRecoveryScreen`). |
| **US-06** | Google One-Tap / OAuth | `SocialMediaCard` (`Key('google_signin_button')`) triggers `AuthService.signInWithGoogle` (live credential flow when Firebase is configured, deterministic fallback otherwise). |
| **US-07** | **Remember Device & Test Mode** | `LoginScreen` includes the `'Remember Device'` checkbox (`Key('remember_device_checkbox')`, persisted via `SessionService.saveSession` and `restoreRememberedSession`) alongside `'Skip Auth (Test Mode)'` (`Key('skip_auth_test_mode_button')`), enabling immediate workspace entry without live credentials. |
| **US-08** | User Registration | `RegistrationScreen` validates Full Name, email format, and 10-digit Nepali mobile numbers starting with `98` or `97` (normalized to `+977XXXXXXXXXX` via `AuthService.normalizeNepaliPhone`), plus password length, before advancing to OTP verification. |
| **US-09** | 6-Digit SMS OTP Card | `OtpVerificationScreen` renders an elevated OTP card (`Key('otp_card')`) with 6 auto-advancing single-digit fields (`Key('otp_box_0')`–`Key('otp_box_5')`) and `Verify & Proceed` (`Key('otp_verify_button')`). |
| **US-10** | Countdown Timer & Resend | Live 120-second countdown (`Key('otp_timer_text')`) disables `'Resend via SMS'` (`Key('otp_resend_button')`) until reaching `00:00`, then resets the timer and shows `'A new 6-digit security OTP was sent to ...'`. |
| **US-11** | **Clear Code Action** | `'Clear Code'` (`Key('otp_clear_button')`) clears all 6 OTP digit controllers, clears error state, and returns keyboard focus to the first box (`otp_box_0`). |
| **US-12** | **Dual Identity Verification & 4-Bar Strength Gauge** | `PasswordRecoveryScreen` enforces Step 1 email/`+977` identity verification (`Key('recovery_identity_input')`, `Key('recovery_verify_identity_button')`, rendering `'Identity verified for <identity>...'`) before unlocking Step 2 with a live 4-bar strength gauge (`Key('password_strength_gauge')`, `Key('password_strength_label')`: `None`, `Weak`, `Fair`, `Strong`, `Very Strong`). |
| **US-13** | **Global Session Revocation** | `PasswordRecoveryScreen` provides `'Global Session Revocation'` (`Key('global_session_revocation_switch')`, default `true`). On reset, `SessionService.revokeAllSessions` increments `revocationEpoch`, clears persisted session records and remembered identifiers, rotates `deviceId`, signs out Firebase Auth, and triggers any configured `RemoteSessionRevocationHook`. |
| **US-14** | **Role-Based Workspace Routing** | `RoleRoutingService` and `WakilApp` deterministically route identifiers containing `'admin'` or ending with `'@wakil.gov.np'` (or Firestore `managed_users` records with `accountStatus == 'ADMIN'`) to `AdminWorkspaceScreen` (`Key('admin_workspace_screen')`, `'Admin Console Workspace'`), and all other users to `MainWorkspaceScreen` (`Key('citizen_workspace_screen')`, `'Main Legal Workspace'`). |

---

## Development & QA Verification Commands

Run these commands from the repository root (`WakilAI/`):

### 1. Install Flutter Dependencies

```bash
flutter pub get
```

### 2. Static Analysis

```bash
flutter analyze
```

Verified clean: `No issues found!`.

### 3. Automated Widget & User-Journey Tests

```bash
flutter test
```

Runs all 9 tests across `test/widget_test.dart` and `test/dynamic_user_flow_test.dart` (verified: `9/9` passing).

### 4. Firestore Security Rules Emulator Tests (`firestore.test.js`, port `8085`)

`firebase.json` binds the Firestore emulator to `127.0.0.1:8085`. Install `@firebase/rules-unit-testing` locally (ignored via `node_modules/` in `.gitignore`) and run `firestore.test.js` with the Firebase emulator:

```bash
npm install --no-save @firebase/rules-unit-testing
firebase emulators:exec --only firestore "node --test firestore.test.js"
```

If the Firestore emulator is already running on `127.0.0.1:8085`:

```bash
node --test firestore.test.js
```
