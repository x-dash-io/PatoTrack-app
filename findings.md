# Findings

Severity legend: `P0` critical, `P1` high, `P2` medium.

## Progress Update (2026-02-23)

- Completed: all P0 items listed below.
- Completed: P1 items 1, 2, 3, 4, 5, 6, 8, 9, 10.
- Completed: P2 item 3 (unused dependencies removed) and P2 item 4 (package renamed to `pato_track`).
- Completed: low-risk P2 lint cleanup pass for warnings (`flutter analyze` now reports infos only, no warnings/errors).
- Remaining follow-up: regenerate `lib/firebase_options.dart` via FlutterFire CLI if web/windows are planned, since their options still point to the legacy Firebase project.

## P0 - Critical

1. Hardcoded Cloudinary API secret in client code.
- Evidence: `lib/helpers/config.dart:6`, used in request signing at `lib/screens/profile_screen.dart:101`.
- Impact: Secret extraction from APK/IPA allows unauthorized uploads and abuse of cloud resources.
- Fix: Move signing to backend endpoint; keep only unsigned upload preset or short-lived signed token flow.

2. Cloud restore can wipe local data on network failure.
- Evidence: local deletes happen first at `lib/helpers/database_helper.dart:309`, `lib/helpers/database_helper.dart:310`, `lib/helpers/database_helper.dart:311`, `lib/helpers/database_helper.dart:312`; remote fetches are in try/catch after deletion.
- Impact: User can lose all local data if Firestore fetch fails.
- Fix: Fetch remote first, validate snapshot, then apply transactional merge/replace.

3. Destructive restore is triggered automatically on app startup.
- Evidence: `lib/screens/home_screen.dart:61` calls restore on init for every signed-in user.
- Impact: Heavy startup latency and repeated data replacement risk; increases chance of accidental data loss.
- Fix: Remove automatic restore; keep explicit user-triggered sync with progress and rollback.

4. Passcode is stored plaintext in SharedPreferences.
- Evidence: read at `lib/screens/passcode_screen.dart:116`, write at `lib/screens/passcode_screen.dart:146`.
- Impact: Weak local security; easy extraction on rooted devices/backups.
- Fix: Use `flutter_secure_storage`, hash+salt, attempt limits, cooldown/lockout, optional biometric step.

5. Error handlers report success to users.
- Evidence: `lib/screens/add_bill_screen.dart:168`, `lib/screens/manage_categories_screen.dart:272` inside `catch` blocks.
- Impact: False trust, hidden failures, data inconsistency.
- Fix: Show accurate failure states and retry actions; only show success on confirmed completion.

6. Account deletion does not clean app data.
- Evidence: only `currentUser?.delete()` at `lib/screens/profile_screen.dart:234`.
- Impact: Firestore/local data may remain after account deletion.
- Fix: Server-driven delete flow: re-auth + delete user doc subtree + local DB purge + sign-out.

## P1 - High

1. Test suite baseline is failing.
- Evidence: `test/widget_test.dart:18` pumps `PatoTrack` without provider wrapper; assertions at `test/widget_test.dart:21` and `test/widget_test.dart:30` target nonexistent counter UI.
- Impact: No CI confidence; regressions are likely.
- Fix: Replace with app-specific widget tests and provider setup.

2. Unresolved merge conflict markers in README.
- Evidence: `README.md:1`, `README.md:3`, `README.md:5`.
- Impact: Repository integrity issue; signals broken review/merge hygiene.
- Fix: Resolve conflict and rewrite README to current architecture.

3. iOS profile/media permissions are missing and brand name is stale.
- Evidence: `ios/Runner/Info.plist:8` (`Ledgerlite`), `ios/Runner/Info.plist:16` (`ledgerlite`), no `NSPhotoLibraryUsageDescription` key.
- Impact: Image upload flow can fail/crash on iOS; app-store metadata inconsistency.
- Fix: Add required privacy usage strings and align branding identifiers.

4. Android/iOS package identifiers still `ledgerlite`.
- Evidence: `android/app/build.gradle.kts:30`, `ios/Runner.xcodeproj/project.pbxproj:550`.
- Impact: Product identity mismatch and release pipeline confusion.
- Fix: Rename application IDs/bundle IDs (with migration plan).

5. Login flow throws non-Firebase exceptions without catch.
- Evidence: explicit `throw Exception(...)` in `lib/screens/login_screen.dart:61`, `lib/screens/login_screen.dart:80`; only Firebase catch block at `lib/screens/login_screen.dart:89`.
- Impact: Unhandled exceptions and stuck loading states.
- Fix: Add generic catch/finally and normalize error handling.

6. Async context safety violations across screens.
- Evidence: analyzer flags in `home`, `profile`, `manage_categories`, `manage_frequencies`, `reports`.
- Impact: Potential crashes/navigation errors when widgets unmount during async operations.
- Fix: consistently guard with `if (!mounted) return;` before context usage after awaits.

7. Over-privileged Android permission set for production.
- Evidence: `android/app/src/main/AndroidManifest.xml:8` (`READ_EXTERNAL_STORAGE`), `:9-10` (SMS read/receive), `:7` exact alarm.
- Impact: Play Store policy/review risk and user trust friction.
- Fix: request least privilege, justify each permission, gate by feature entry.

8. Recurring bill date math can drift for month-end dates.
- Evidence: `lib/screens/home_screen.dart:430` uses `DateTime(year, month + 1, day)`.
- Impact: Jan 31-like dates may roll unexpectedly.
- Fix: implement safe month increment strategy preserving end-of-month semantics.

9. Bill reminder scheduling uses time arithmetic that can miss reminders.
- Evidence: `lib/helpers/notification_service.dart:25` subtract/add hour math from dueDate.
- Impact: reminders may be scheduled at unintended times or skipped.
- Fix: construct explicit local date at desired reminder time (e.g., dueDate-1day at 09:00 local).

10. Currency display is inconsistent across screens.
- Evidence: fixed `KSh` in `lib/screens/reports_screen.dart:24` and `lib/screens/all_transactions_screen.dart:292`; configurable preference in `lib/screens/home_screen.dart:134`.
- Impact: user confusion and reporting inconsistencies.
- Fix: centralized currency preference provider/service.

## P2 - Medium

1. Very large stateful screens reduce maintainability.
- Evidence: `lib/screens/home_screen.dart` (1638 lines), `lib/screens/reports_screen.dart` (1083), `lib/screens/profile_screen.dart` (982).
- Impact: high regression risk and slower development velocity.
- Fix: split by feature widgets/controllers; move business logic to services/view-models.

2. Deprecated API use is widespread.
- Evidence: many `withOpacity` and old widget APIs (from analyzer).
- Impact: upgrade friction and eventual breakages.
- Fix: replace with modern APIs (`withValues`, etc.) in a dedicated cleanup pass.

3. Unused/dead dependencies and imports.
- Evidence: `local_auth`/`flutter_pin_code_fields` in `pubspec.yaml` not used in `lib/`; unused imports flagged by analyzer.
- Impact: bigger app size and maintenance noise.
- Fix: remove unused dependencies/imports.

4. Package naming violates Dart conventions.
- Evidence: `pubspec.yaml:1` uses `PatoTrack` (not lower_snake_case).
- Impact: tooling/lint noise and ecosystem incompatibility.
- Fix: rename package to `pato_track` (planned migration).
