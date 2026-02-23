# UI/UX Upgrades for Production Readiness

## Implementation Progress (2026-02-23)

### Completed in this pass

- Global premium design system:
  - Updated `lib/main.dart` theme tokens (typography, component radii, button/input/navigation styles).
  - Migrated app typography usage from `Inter` to `Manrope` with `Sora` headlines in the core theme.
- Home (`lib/screens/home_screen.dart`):
  - Removed startup SMS permission prompt and automatic SMS sync.
  - Added explicit `M-Pesa SMS Import` card with trust copy, enable/sync CTA, status badge, and last-sync timestamp.
  - Added richer gradient shell to align with premium visual language.
- Reports (`lib/screens/reports_screen.dart`):
  - Added explicit period scope messaging with inclusive boundaries.
  - Clarified business-only filtering in UI.
  - Added PDF export confirmation dialog with scope preview (period + transaction count).
- Profile (`lib/screens/profile_screen.dart`):
  - Added cloud restore transparency via persisted last-restore timestamp in Data & Sync section.
- Forms:
  - Added reusable `StandardDateSelectorTile` (`lib/widgets/input_fields.dart`) to replace transient date controllers.
  - Applied to:
    - `lib/screens/add_transaction_screen.dart`
    - `lib/screens/add_bill_screen.dart`
    - `lib/screens/transaction_detail_screen.dart`
- Screen shell consistency:
  - Added reusable premium background component `lib/widgets/app_screen_background.dart`.
  - Applied across onboarding/auth/profile/transactions/reporting core surfaces.

### Validation status

- `flutter test`: passed.
- `flutter analyze`: no errors/warnings; infos remain (legacy lint/deprecation backlog).

### Remaining for next UI pass

- Full screen-by-screen polish on:
  - `help_screen.dart`
  - `faq_screen.dart`
  - `manage_categories_screen.dart`
  - `manage_frequencies_screen.dart`
  - `passcode_screen.dart`
- Accessibility hardening:
  - semantic labels for icon-only actions
  - large-text overflow audit
  - contrast checks on tinted/gradient surfaces
- Motion pass:
  - staged entry transitions on key cards
  - consistent interaction feedback across list rows and bottom sheets

## Priority UX upgrades

1. Permission trust flow redesign.
- Current behavior requests SMS permission during home init (`lib/screens/home_screen.dart:55`).
- Upgrade: ask only when user enables SMS import feature; include rationale and fallback path.

2. Sync transparency.
- Current behavior silently restores cloud data at startup.
- Upgrade: explicit "Syncing from cloud" states, timestamps, retry, and conflict messaging.

3. Currency consistency.
- Current behavior mixes configurable and fixed currency labels (`home` vs `reports`/`all transactions`).
- Upgrade: global currency state applied app-wide, including reports/PDF export.

4. Form interaction quality.
- Current behavior creates transient date controllers in build for multiple forms.
- Upgrade: convert date fields to read-only display tiles or persistent controllers; improve keyboard and validation feedback.

5. Error state quality.
- Current behavior includes false-success messages in failure paths.
- Upgrade: user messages must reflect operation outcome with clear next action.

## Information architecture and navigation

1. Split heavy profile/settings into sections with dedicated detail screens.
2. Surface data safety actions (restore, delete account) with stronger warnings and progress states.
3. Add transaction quick-actions with undo for destructive operations.

## Visual consistency upgrades

1. Standardize spacing/typography tokens across screens.
2. Replace extensive ad-hoc gradients with reusable theme tokens.
3. Reduce mixed icon styles and inconsistent card paddings.

## Accessibility and inclusivity

1. Ensure minimum tap targets and semantic labels for icon-only actions.
2. Verify color contrast for gradients and tinted text.
3. Support larger text scale without clipping/overflow.
4. Add screen-reader-friendly labels for charts and summaries.

## Reporting UX improvements

1. Add explicit period chips with inclusive date boundaries.
2. Clarify "business-only" filtering in report header.
3. Add export preview and confirmation for report scope.

## Production-ready UX checklist
- No unexpected permission prompts.
- Every long-running action has loading + cancel/retry behavior.
- Error messages are actionable and truthful.
- Empty states offer next best action.
- Core flows are usable with larger text and screen readers.
