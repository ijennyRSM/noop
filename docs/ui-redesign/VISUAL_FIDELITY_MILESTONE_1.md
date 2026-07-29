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

## Sampled score colors

Colors were measured from the supplied files rather than estimated from memory.
Dominant saturated arc samples (small compression differences occur across pixels)
were:

- Rest in `13_official_home_three_rings.webp`: approximately `#80A6C0`;
- Effort in the same image: approximately `#0295EB`;
- Charge good in images 13–15: approximately `#18EE05`;
- Charge moderate in `14_official_recovery_ranges.webp`: approximately `#FDE000`;
- Charge poor in image 14: approximately `#FE0127`.

`PerformanceScorePalette` owns those fixed presentation tokens plus the
`#313A41` track and cool-cyan Coach chrome. It is deliberately independent of
`ChartStyle`, the general `StrandPalette` theme, sleep stages, and HR zones.

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

## Measured implementation geometry

The final seeded capture is 1206 × 2622 pixels (402 × 874 points at 3×).
The milestone uses the following explicit layout values:

- Today score-ring diameter: an explicit 92 pt;
- Today score-ring stroke: 6 pt;
- spacing between the three score cells: 10 pt;
- Today score number: 34 pt black rounded, with an 18 pt percent sign;
- detail score-ring diameter: an explicit 248 pt;
- detail score-ring stroke: 9.5 pt;
- detail integer score: 76 pt black rounded, with a 34 pt percent sign;
- detail decimal Effort score: 68 pt black rounded, without a percent sign;
- Today horizontal page gutter: 16 pt;
- Today initial content inset below the safe area: 12 pt;
- centred wordmark inset: 12 pt above and 4 pt below;
- Health/Stress card inner padding: 13 pt;
- Health/Stress card corner radius: 15 pt;
- My Day activity-group padding: 16 pt;
- My Day activity-group corner radius: 16 pt;
- activity-row padding and radius: 8 pt and 11 pt;
- synthesis corner radius: 30 pt;
- detail-screen card inner padding and corner radius: 16 pt and 20 pt;
- base Today section spacing: 12 pt, with 8 pt added before major sections
  (approximately 20 pt total);
- detail-screen section spacing: 24 pt.

Compared with the rejected capture, the rings can no longer expand with their
parent cards, the value dominates the ring centre, and Today/detail screens
resolve color through one fixed semantic API. Rest is blue-gray, Effort is
bright blue, and Charge uses inclusive discrete bands (0–33 poor, 34–66
moderate, 67–100 good). The matching Today key-metric tiles reuse those same
tokens, and Effort is shown without a percent sign. Chart themes cannot recolor
these primary scores.

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
- `charge-poor-20.png`
- `charge-moderate-50.png`
- `charge-good-85.png`

The comparison artifact contains the supplied ring references, the rejected
capture, corrected captures, and browsable `reference/`, `before/`, and
`after/` directories plus this report. No later screen should be redesigned
until this ring/color gate has been reviewed.
