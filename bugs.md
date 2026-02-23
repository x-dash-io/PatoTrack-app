# Bug Backlog
Status legend: `Open`, `Fixed`, `Blocked`.

## B-001 - Client-side secret exposure
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/helpers/config.dart:6`, `lib/screens/profile_screen.dart:101`
- Problem: Cloudinary API secret is embedded in app binary.
- Fix applied: removed API key/secret from client and switched to unsigned upload preset flow.

## B-002 - Data wipe risk during restore
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/helpers/database_helper.dart:309`
- Repro: Trigger restore while offline/intermittent network.
- Expected: local data retained until remote snapshot is confirmed.
- Actual: local data deleted before successful fetch is guaranteed.
- Fix applied: restore now fetches remote first, then replaces local only after successful reads.

## B-003 - Automatic destructive restore on app open
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/home_screen.dart:61`
- Repro: Open app after login; restore runs unconditionally.
- Impact: startup slowdown and repeated destructive sync path.
- Fix applied: startup restore call removed; restore is now explicit user action.

## B-004 - Success message shown on save failure (bills)
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/add_bill_screen.dart:168`
- Repro: force any exception in save path.
- Expected: error message.
- Actual: success snackbar says bill saved.

## B-005 - Success message shown on save failure (categories)
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/manage_categories_screen.dart:272`
- Repro: force exception in category add/update.
- Expected: error message.
- Actual: success snackbar shown.

## B-006 - Passcode stored in plaintext
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/passcode_screen.dart:146`
- Problem: 4-digit passcode stored directly in SharedPreferences.
- Fix applied: moved passcode to `flutter_secure_storage` using salted SHA-256 hash + migration from legacy key.

## B-007 - Account delete leaves app data behind
- Severity: P0
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/profile_screen.dart:234`
- Problem: only auth user delete is attempted; no Firestore/local cleanup.
- Fix applied: deletion now removes Firestore subtree + local DB data before deleting auth user.

## B-008 - Stale test suite fails
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `test/widget_test.dart:18`, `test/widget_test.dart:21`
- Problem: outdated counter test; missing provider setup.
- Fix applied: replaced with app-specific smoke test (`ModernLoadingIndicator renders without crashing`).

## B-009 - README contains merge conflict markers
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `README.md:1`

## B-010 - iOS media permission keys missing
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `ios/Runner/Info.plist`
- Problem: no `NSPhotoLibraryUsageDescription` despite image-picker usage.

## B-011 - Login can throw uncaught non-Firebase exceptions
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/login_screen.dart:61`, `lib/screens/login_screen.dart:80`
- Problem: manual throws only partially handled.

## B-012 - Modal loading state reset bug in forgot-password sheet
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/login_screen.dart:207`
- Problem: `isSendingReset` is local in builder and resets on rebuild.
- Fix applied: moved `isSendingReset` outside builder and kept it in dialog state lifecycle.

## B-013 - Monthly recurrence date drift
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/home_screen.dart:430`
- Problem: month increment can overflow day-of-month unexpectedly.

## B-014 - Reminder scheduling time can be incorrect
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/helpers/notification_service.dart:25`
- Problem: dueDate arithmetic can skip or mis-time reminders.

## B-015 - Inconsistent currency symbol across app
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/reports_screen.dart:24`, `lib/screens/all_transactions_screen.dart:292`
- Problem: ignores saved currency preference.

## B-016 - Category save button can stay disabled after success
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `lib/screens/manage_categories_screen.dart:242`
- Problem: `_isSavingCategory` is set true and not reset on success before dialog close.

## B-017 - Product identity mismatch (Ledgerlite vs PatoTrack)
- Severity: P1
- Status: `Fixed` (2026-02-23)
- Location: `ios/Runner/Info.plist:8`, `android/app/build.gradle.kts:30`, `lib/firebase_options.dart:47`
- Fix applied: Android namespace/applicationId, iOS bundle identifiers, Kotlin package path, and mobile Firebase options are now aligned to `com.patotrack.app` with new Firebase project values.
