# PR #3 Full-App Visual Port — Acceptance

## Regression baseline

- [x] `root`, `today`, `todayscrolled`, `charge`, `rest`, and `effort` are
      recaptured from real SwiftUI simulator views.
- [x] Each is compared against approved SHA `51c5df894d164f040233325ba2297f417bffbe91`.
- [x] Geometry changes are absent or documented with a functional/accessibility reason.
- [x] PR #9 root dock and separate DX Coach action remain functional.

## Module acceptance

- [x] Strength Home has a screen-specific hierarchy led by current muscle status.
- [x] Active Logger uses a compact set table and preserves every edit/autosave action.
- [x] Exercise Picker, templates, history, detail, and completed editing are redesigned.
- [x] Body Map front/back, modes, detail, soreness, and pain states are redesigned.
- [x] Coach is a purpose-built full-height conversation, not a dashboard.
- [x] Goal, Plan Book/proposals, Journey, and Updates remain distinct experiences.
- [x] Workouts use compact timeline/detail compositions.
- [x] Privacy and consent remain explicit, text-labelled, and enforce the same state.
- [x] Backup/import/export retain validation, warnings, conflicts, rollback, and results.
- [x] Settings and device/data-source screens use dense grouped rows.
- [x] Loading, empty, error, stale, low-confidence, and confirmation states are truthful.

## Design-language checks

- [x] Near-black canvas, graphite surfaces, restrained borders, limited nesting.
- [x] Condensed major numerals/headings with tabular digits.
- [x] PR #9 Charge/Rest/Effort colors do not regress.
- [x] Blue/cyan primary actions; no purple navigation chrome.
- [x] Generic components are only low-level primitives, never a universal layout engine.
- [x] Pain is visually and semantically separate from muscular load and soreness.

## Behavior and backend checks

- [x] No duplicate Today, Coach, route, repository, database, or derived-load state.
- [x] Strength, workout, plan, privacy, backup, import/export, device actions call
      their original owners.
- [x] No migration, formula, BLE, HealthKit, provider, consent, or backup-contract change.
- [x] Gregorian canonical-date behavior and custom Coach prompt behavior remain intact.

## Thai and accessibility

- [x] Thai localization validator and placeholder parity pass.
- [x] Compact iPhone width and long Thai consent/chat text are visually inspected.
- [ ] Dynamic Type, VoiceOver labels, Reduce Motion, contrast, and practical targets pass.
- [x] Score/status meaning is available as text and not only color.
- [x] Charts include readable text summaries.

## Evidence and release

- [ ] Existing source hygiene, i18n, package, macOS, iOS, Android, exercise,
      Strength, Coach consent, migration, and backup tests pass.
- [x] Targeted route/action/presentation tests pass.
- [x] 47 seeded Thai screenshots are uploaded in module contact sheets.
- [x] Baseline `approved-pr9/current-final/difference-report.md` artifact is uploaded.
- [x] Generic iPhone Release build succeeds with signing disabled.
- [x] Unsigned `.noopfull` IPA contains exactly one main app and required resources.
- [ ] PR #9 description has final SHA, evidence, limitations, and deviations.
- [x] PR #9 remains Draft and unmerged for physical-iPhone review.

The unchecked accessibility item requires hands-on VoiceOver and every Dynamic
Type size on a physical device. The aggregate cross-platform CI item remains
unchecked if the integration base's pre-existing Android hygiene/i18n findings
are still reported; Apple hardcoded-string audit and Thai validation pass.

The redesign is not complete while any user-facing item in
`PR3_FULL_APP_SCREEN_INVENTORY.md` remains unclassified.
