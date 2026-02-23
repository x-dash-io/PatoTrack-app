# Testing Strategy

## Current state
- Only one test exists: `test/widget_test.dart`.
- That test is template-based and failing.

## Immediate testing goals (Week 1)

1. Replace failing template test with app-aware smoke tests.
- App boot with provider setup.
- AuthGate routing: onboarding -> login -> main/passcode.

2. Add unit tests for high-risk logic.
- `DatabaseHelper.restoreFromFirestore` non-destructive behavior.
- Bill recurrence next-date calculation.
- SMS parsing for common M-Pesa message variants.

3. Add widget tests for critical forms.
- Add/edit transaction validation.
- Add/edit bill validation and duplicate-name handling.
- Profile actions: logout/delete confirmation flows.

## Medium-term goals (Weeks 2-3)

1. Integration tests (happy paths).
- Email login
- Google sign-in mock path
- Transaction CRUD
- Report generation trigger

2. Regression tests for bug backlog.
- Error snackbar correctness (no success in catch blocks).
- Currency consistency across screens.
- Passcode flow behavior and lockout.

## CI gates (after baseline is fixed)
- `flutter test`
- `flutter analyze`
- Release build smoke (`flutter build apk --debug` or platform equivalent)

## Coverage priorities
- P0/P1 findings first.
- Data integrity and auth flows before UI polish tests.
