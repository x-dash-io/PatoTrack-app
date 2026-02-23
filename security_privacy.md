# Security and Privacy Review

## Critical risks

1. Embedded API secret in mobile app
- Evidence: `lib/helpers/config.dart:6`
- Risk: credential extraction and cloud abuse.
- Action: server-side signing only, key rotation, revoke leaked key.

2. Weak local app lock implementation
- Evidence: passcode read/write in `lib/screens/passcode_screen.dart:116` and `lib/screens/passcode_screen.dart:146`
- Risk: plaintext credential, brute-forceable 4-digit PIN.
- Action: secure storage, salted hash, attempt throttling/lockout, optional biometric unlock.

3. Incomplete account deletion
- Evidence: only auth delete at `lib/screens/profile_screen.dart:234`
- Risk: retained personal/financial data in Firestore/local DB.
- Action: full-delete workflow with re-authentication and data purge.

4. Over-privileged permissions
- Evidence: `android/app/src/main/AndroidManifest.xml:8-10`
- Risk: app-store compliance rejection and user distrust.
- Action: remove unneeded permissions; request at point-of-use with clear UX rationale.

## Data integrity and privacy concerns

1. Destructive restore behavior can erase local data (`lib/helpers/database_helper.dart:309`).
2. Automatic restore on startup amplifies risk (`lib/screens/home_screen.dart:61`).
3. Logging via `print` includes operational details; sanitize and centralize logging.

## Recommended remediation order
1. Rotate/revoke Cloudinary secret and ship secure upload flow.
2. Patch restore mechanism to non-destructive strategy.
3. Upgrade passcode security model.
4. Implement full account/data deletion path.
5. Permission minimization and privacy disclosure updates.

## Minimum security acceptance criteria before release
- No secrets in source or binaries.
- Sensitive local data stored only in secure storage.
- Account deletion removes all user data.
- Permission set matches actual feature use and policy requirements.
