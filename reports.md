# PatoTrack Repository Audit Report

Date: 2026-02-23

## Scope
This audit reviewed the Flutter app for production readiness, focusing on security, reliability, code quality, and UI/UX.

## What was reviewed
- Core app flow: `lib/main.dart`, `lib/auth_gate.dart`
- Data/sync layer: `lib/helpers/database_helper.dart`, `lib/helpers/sms_service.dart`, `lib/helpers/notification_service.dart`
- Auth/profile: `lib/screens/login_screen.dart`, `lib/screens/signup_screen.dart`, `lib/screens/profile_screen.dart`, `lib/screens/passcode_screen.dart`
- Core product screens: `lib/screens/home_screen.dart`, `lib/screens/reports_screen.dart`, `lib/screens/all_transactions_screen.dart`, `lib/screens/add_bill_screen.dart`, `lib/screens/add_transaction_screen.dart`, `lib/screens/manage_categories_screen.dart`, `lib/screens/manage_frequencies_screen.dart`
- Platform config: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `android/app/build.gradle.kts`
- Tooling/tests/docs: `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `test/widget_test.dart`

## Validation run
- `flutter analyze` reported `327 issues`.
- `flutter test` failed in `test/widget_test.dart` with `ProviderNotFoundException` and stale counter assertions.

## Current risk snapshot
- `P0 (release blockers)`: security secret exposure, destructive cloud-restore behavior, insecure passcode storage, false success/error handling, incomplete account deletion.
- `P1`: failing tests, unresolved merge conflict, platform config/brand mismatches, async context hazards, permission policy risks.
- `P2`: architecture debt, large widget files, deprecated API usage, dependency hygiene issues.

## Key blocker list (must fix before production)
1. Remove Cloudinary secret from client app (`lib/helpers/config.dart:6`, `lib/screens/profile_screen.dart:101`).
2. Stop destructive restore-on-launch that can wipe local data offline (`lib/screens/home_screen.dart:61`, `lib/helpers/database_helper.dart:309`).
3. Replace plaintext passcode storage with secure, rate-limited auth (`lib/screens/passcode_screen.dart:116`, `lib/screens/passcode_screen.dart:146`).
4. Fix misleading "success" paths inside exception handlers (`lib/screens/add_bill_screen.dart:168`, `lib/screens/manage_categories_screen.dart:272`).
5. Implement full data deletion on account delete (Firestore + local DB) (`lib/screens/profile_screen.dart:234`).
6. Resolve failing test baseline (`test/widget_test.dart:18`, `test/widget_test.dart:21`).

## Report files created
- `findings.md` - prioritized findings with evidence and impact
- `bugs.md` - reproducible bug backlog
- `code_quality.md` - analyzer and maintainability assessment
- `refinements.md` - technical refinement roadmap
- `UI_UX_upgrades.md` - production-level UI/UX upgrade plan
- `security_privacy.md` - security/privacy risk report and remediations
- `testing_strategy.md` - test gap analysis and rollout plan

## Recommended execution order
1. Finish all `P0` items from `findings.md` and `bugs.md`.
2. Stabilize CI baseline (`flutter analyze`, `flutter test`) and fix top runtime bugs.
3. Apply architecture and UX refinements from `refinements.md` and `UI_UX_upgrades.md`.
4. Expand tests per `testing_strategy.md` before adding new features.
