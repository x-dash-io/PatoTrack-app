# Code Quality Assessment

## Current baseline
- Dart files: `37` in `lib/`
- Test files: `1` in `test/`
- Approx app code size: `~13,000+` LOC
- `flutter analyze`: `327 issues`
- `flutter test`: failing baseline

## Main quality signals

1. Static analysis debt is high.
- Common issue groups: deprecated APIs, async-context misuse, unnecessary null assertions, unused imports/variables, production `print` usage.

2. Layering is weak in feature screens.
- UI, network/sync, database calls, and state mutation are mixed inside large widgets.
- Hotspots: `lib/screens/home_screen.dart`, `lib/screens/reports_screen.dart`, `lib/screens/profile_screen.dart`.

3. Error handling is inconsistent.
- Some catches report success on failure (`lib/screens/add_bill_screen.dart:168`, `lib/screens/manage_categories_screen.dart:272`).
- Some thrown exceptions are not covered by generic catch (`lib/screens/login_screen.dart:61`, `lib/screens/login_screen.dart:80`).

4. Reliability and trust gaps.
- Destructive sync behavior in `lib/helpers/database_helper.dart:309` and auto-invocation in `lib/screens/home_screen.dart:61`.
- Security-sensitive local passcode strategy in `lib/screens/passcode_screen.dart:146`.

5. Test quality is not production-ready.
- `test/widget_test.dart` is template-era and not aligned to actual app architecture.

## Code hygiene observations
- `print(...)` calls in `lib/`: 43 occurrences.
- `withOpacity(...)` calls in `lib/`: 152 occurrences.
- No TODO/FIXME markers found, but unresolved README conflict exists (`README.md:1`).

## Quality priorities

### Priority 1
- Fix P0 findings first (security + data integrity + false-success paths).
- Restore passing tests and analyzer gating for new changes.

### Priority 2
- Refactor large screens into feature components + controllers/services.
- Normalize async context patterns and failure-handling patterns.

### Priority 3
- Complete API modernization and dependency cleanup.
- Enforce stricter lint/profile and CI quality gates.

## Suggested quality gate (after stabilization)
- `flutter analyze` with zero warnings in touched files.
- `flutter test` passing for all core flows.
- No secrets in repo (`gitleaks` or similar pre-commit scan).
