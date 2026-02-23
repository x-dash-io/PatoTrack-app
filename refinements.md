# Refinements Roadmap

## Phase 0 - Safety and integrity (immediate)
1. Remove client-side Cloudinary secret flow.
2. Disable automatic cloud restore at startup.
3. Rewrite restore to non-destructive merge/replace with prefetch validation.
4. Fix misleading success in error handlers.
5. Replace plaintext passcode storage with secure storage + lockout.

Exit criteria:
- No hardcoded secrets in app code.
- Restore cannot delete data when remote fetch fails.
- All save operations report accurate status.

## Phase 1 - Stability and correctness
1. Replace stale widget test with real app tests and pass CI baseline.
2. Add generic catch/finally in login/auth workflows.
3. Fix async context-after-await violations in top-risk screens.
4. Correct bill recurrence and notification scheduling date/time logic.
5. Resolve README merge conflict and platform naming mismatches.

Exit criteria:
- `flutter test` green.
- Major auth/billing/reporting flows manually verified.

## Phase 2 - Architecture and maintainability
1. Split giant screens into modular widgets + domain services.
2. Introduce state layer for feature screens (e.g., Provider/Riverpod/BLoC per feature).
3. Centralize user settings (currency, theme, locale, security prefs).
4. Standardize error/result types across data layer.

Exit criteria:
- No screen > 500 lines.
- Shared settings consumed from a single source of truth.

## Phase 3 - UX and performance
1. Add explicit sync states and retry UI.
2. Improve list virtualization, loading placeholders, and empty/error states consistency.
3. Add user-facing permission rationale before SMS/notification prompts.
4. Improve accessibility (text scaling, semantics, contrast checks).

Exit criteria:
- End-to-end flows remain responsive on low-end devices.
- Accessibility checklist passes for core screens.

## Phase 4 - Scale readiness
1. Add telemetry/logging strategy (non-PII) for failures.
2. Add integration tests for auth, transaction CRUD, and sync.
3. Add release checklist automation (analyze/test/build checks).

Exit criteria:
- Repeatable release pipeline with quality gates.
- Measurable crash/error reduction.
