# PR #9 — Full-App PR3 Visual Expansion

## Scope

- Repository: `ijennyRSM/noop`
- Base: `integration/dx-thai-strength-full`
- Visual branch: `feat/pr3-visual-port-on-dx-full`
- Approved Milestone 1 baseline: `51c5df894d164f040233325ba2297f417bffbe91`
- Final branch SHA: recorded in the PR description and workflow summary after
  the final documentation commit.
- Pull request remains Draft and unmerged.

The six approved screens (root, Today, Today scrolled, Charge, Rest, and
Effort) remain the immutable visual baseline. The expansion applies their
PR3-derived near-black canvas, graphite surfaces, condensed hierarchy,
compact rhythm, and blue action language to secondary modules without
creating a universal card/grid dashboard.

## Inventory and presentation architecture

The inventory contains 82 classified screens and states:

- 6 approved baseline screens;
- 51 directly redesigned screens/states;
- 23 specialized routes that inherit the shared PR3 presentation while
  preserving their existing controls;
- 2 intentionally unchanged active-workout entry surfaces.

New low-level primitives live in `PR3SecondaryComponents.swift`: compact page
heading, section label, grouped row, inline metric, status tag, truthful state,
and secondary button language. Screen hierarchy remains owned by the
individual Strength, Body Map, Coach, planning, workouts, privacy, backup,
settings, device, and data-source views.

## Backend protection

The visual expansion intentionally does not modify:

- repository/database implementations or migrations;
- BLE frames, pairing, sync, or backfill;
- HealthKit ingestion;
- score, Muscular Load, Residual Load, or Total Training Load formulas;
- Strength persistence and transaction contracts;
- Coach provider requests, tools, memory, consent, or Semantic Memory;
- Goal/Plan/Journey state;
- Unified Backup V2, import, or export formats;
- canonical Gregorian date behavior.

Presentation-only localization resolves canonical workout/plan labels for the
UI while retaining their stored identifiers and AI/context representations.

## Thai and accessibility

- Thai catalog validation: 4,251/4,251 entries, placeholder compatible.
- Exercise Library validation: 420 exercises, 22/22 muscles.
- Seeded visual review uses `th_TH` on a compact iPhone simulator.
- Major status components combine text and color.
- Condensed numeric text uses tabular digits.
- Existing VoiceOver labels, minimum control heights, and Reduce Motion
  behavior are preserved.

The 47-screen simulator review is a compact-width visual gate; it is not a
complete VoiceOver rotor or every-Dynamic-Type-size certification.

## Visual evidence

Workflow: `PR3 Full App Visual Review and Unsigned IPA`

Artifacts:

- `NOOP-PR3-Full-App-Thai-Screens`
- `NOOP-PR3-Full-App-Contact-Sheets`
- `NOOP-PR3-Approved-Baseline-Regression`
- `NOOP-AI-Full-Thai-Strength-PR3UI-Unsigned-IPA`

The workflow checks out the PR head SHA explicitly, captures 47 real SwiftUI
routes, compares the six approved screens with the Milestone 1 artifact,
builds a generic real-iPhone Release app with signing disabled, and verifies
the IPA before upload.

## Known limitations and deviations

- Physical-iPhone interaction and visual review remain pending.
- Manual Workout and Live Workout are intentionally unchanged in this pass;
  their active persistence/timing controls were not part of the requested
  47-screen screenshot gate.
- The seeded HR-zone route verifies the workout-detail hierarchy and stored
  zone summary; it does not fabricate raw heart-rate samples merely to draw a
  curve.
- Some system-owned pickers and sheets retain native SwiftUI presentation.
- The visual gate exercises representative consent and restore states; it does
  not perform destructive writes.
- Source-hygiene and full cross-platform i18n jobs may report pre-existing
  Android findings from the integration base. Apple hardcoded-literal audit
  and Thai coverage are required to pass for this branch.

## Release

Expected unsigned IPA filename:

`NOOP-AI-Full-Thai-Strength-PR3UI-v9.2.1-<short-final-sha>-unsigned.ipa`

The IPA keeps the `.noopfull` bundle identity and is intended for later local
signing. It contains no provisioning profile or signing identity. Watch and
PlugIns may be removed by the sideload packaging step, as on the established
Full Beta workflow.
