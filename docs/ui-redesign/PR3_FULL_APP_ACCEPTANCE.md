# PR #3 Full-App Visual Port — Acceptance

## Regression baseline

- [ ] `root`, `today`, `todayscrolled`, `charge`, `rest`, and `effort` are
      recaptured from real SwiftUI simulator views.
- [ ] Each is compared against approved SHA `51c5df894d164f040233325ba2297f417bffbe91`.
- [ ] Geometry changes are absent or documented with a functional/accessibility reason.
- [ ] PR #9 root dock and separate DX Coach action remain functional.

## Module acceptance

- [ ] Strength Home has a screen-specific hierarchy led by current muscle status.
- [ ] Active Logger uses a compact set table and preserves every edit/autosave action.
- [ ] Exercise Picker, templates, history, detail, and completed editing are redesigned.
- [ ] Body Map front/back, modes, detail, soreness, and pain states are redesigned.
- [ ] Coach is a purpose-built full-height conversation, not a dashboard.
- [ ] Goal, Plan Book/proposals, Journey, and Updates remain distinct experiences.
- [ ] Workouts use compact timeline/detail compositions.
- [ ] Privacy and consent remain explicit, text-labelled, and enforce the same state.
- [ ] Backup/import/export retain validation, warnings, conflicts, rollback, and results.
- [ ] Settings and device/data-source screens use dense grouped rows.
- [ ] Loading, empty, error, stale, low-confidence, and confirmation states are truthful.

## Design-language checks

- [ ] Near-black canvas, graphite surfaces, restrained borders, limited nesting.
- [ ] Condensed major numerals/headings with tabular digits.
- [ ] PR #9 Charge/Rest/Effort colors do not regress.
- [ ] Blue/cyan primary actions; no purple navigation chrome.
- [ ] Generic components are only low-level primitives, never a universal layout engine.
- [ ] Pain is visually and semantically separate from muscular load and soreness.

## Behavior and backend checks

- [ ] No duplicate Today, Coach, route, repository, database, or derived-load state.
- [ ] Strength, workout, plan, privacy, backup, import/export, device actions call
      their original owners.
- [ ] No migration, formula, BLE, HealthKit, provider, consent, or backup-contract change.
- [ ] Gregorian canonical-date behavior and custom Coach prompt behavior remain intact.

## Thai and accessibility

- [ ] Thai localization validator and placeholder parity pass.
- [ ] Compact iPhone width and long Thai consent/chat text are visually inspected.
- [ ] Dynamic Type, VoiceOver labels, Reduce Motion, contrast, and practical targets pass.
- [ ] Score/status meaning is available as text and not only color.
- [ ] Charts include readable text summaries.

## Evidence and release

- [ ] Existing source hygiene, i18n, package, macOS, iOS, Android, exercise,
      Strength, Coach consent, migration, and backup tests pass.
- [ ] Targeted route/action/presentation tests pass.
- [ ] 47 seeded Thai screenshots are uploaded in module contact sheets.
- [ ] Baseline `approved-pr9/current-final/difference-report.md` artifact is uploaded.
- [ ] Generic iPhone Release build succeeds with signing disabled.
- [ ] Unsigned `.noopfull` IPA contains exactly one main app and required resources.
- [ ] PR #9 description has final SHA, evidence, limitations, and deviations.
- [ ] PR #9 remains Draft and unmerged for physical-iPhone review.

The redesign is not complete while any user-facing item in
`PR3_FULL_APP_SCREEN_INVENTORY.md` remains unclassified.
