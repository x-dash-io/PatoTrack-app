# UI/UX Upgrades for Production Readiness

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
