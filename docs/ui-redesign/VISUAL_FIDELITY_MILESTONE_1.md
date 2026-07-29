# Visual Fidelity Milestone 1

This milestone deliberately covers only the root navigation, Today, Charge,
Rest, and Effort. It does not claim that the remaining application screens have
passed the visual-fidelity correction.

## Reference priority

1. `00_PRIORITY_latest_navigation_user_reference.png` — authoritative root dock.
2. `01_google_play_current_01.jpg` — primary Today hierarchy.
3. The remaining pack images — secondary detail language only.

The reference images are used only by the ephemeral Actions comparison
artifact. They are not copied to an asset catalog or application bundle.

## Measured navigation target

The supplied navigation crop is 326 × 74 pixels. Its visible proportions are:

- four-item dock: approximately 226 × 43 pixels;
- separate Coach circle: approximately 52 × 52 pixels;
- visible separation between the two surfaces: approximately 16 pixels;
- aligned vertical centre and common bottom safe-area relationship;
- dock-to-Coach width ratio: approximately 4.35:1.

The implementation uses adaptive iPhone-point geometry:

- dock width: 220–280 pt depending on available width;
- dock height: 58 pt;
- Coach diameter: 58 pt;
- inter-surface gap: 10 pt;
- bottom inset: 7 pt;
- compact 16 pt icons and 9 pt labels;
- 7 pt soft shadow instead of the former 18 pt halo.

These values preserve the reference proportions while maintaining useful touch
targets on compact iPhones.

## Before and after checks

| Surface | Previous implementation | Milestone 1 target |
|---|---|---|
| Root dock | Wide generic dock plus an independently draggable 66 pt ECG button that could overlap content | One coordinated compact dock and aligned separate original NOOP sparkle Coach action |
| Today header | Large greeting plus six utility controls | Profile, compact day selector, battery, centred NOOP wordmark |
| Today scores | Generic metric cards / Liquid vessels | Three equal rings in Rest–Charge–Effort order without individual cards |
| Today hierarchy | Generic metric grid before the daily story | Insight, Health/Stress pair, My Day, activity timeline, then remaining DX sections |
| Charge | Coupled Liquid dashboard mixing three scores | Dedicated Charge ring, readiness context, suggested Effort, and workout count |
| Rest | Scenic Liquid vessel | Flat dark Rest ring followed by the existing sleep balance and stage details |
| Effort | Generic Trends screen | Dedicated Effort score, seven-day load, contributing workouts, and HR zones |

## Backend protection

The changes in this milestone are presentation and route composition only.
Repository ownership, DailyMetric values, workout rows, sleep classification,
Charge/Rest/Effort formulas, BLE, HealthKit, AI Coach, Strength, backup,
privacy, and consent logic remain unchanged.

## Screenshot review gate

The workflow captures exactly:

- `root.png`
- `today.png`
- `todayscrolled.png`
- `charge.png`
- `rest.png`
- `effort.png`

The comparison artifact contains `reference/`, `before/`, and `after/`
directories plus this report. No later screen should be redesigned until these
six simulator captures have been reviewed.
