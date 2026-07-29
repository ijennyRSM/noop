# Visual reference mapping

The authoritative pack was inspected outside the repository. Its 23 checksums passed:
five documentation/checksum files and images `00` through `18`. None of those files may
be added to application resources or committed as product assets.

## Priority and extracted design facts

1. `00_PRIORITY_latest_navigation_user_reference.png`
   - Authoritative root navigation.
   - One compact floating rounded dock with four destinations.
   - Icon above a short label.
   - A restrained active-tab surface.
   - A separate circular action aligned to the right.
   - NOOP mapping: Home, Health, Progress, More; circular action opens the existing DX Coach.
2. `01`–`08` current store images
   - Blue-black canvas, dark cards, large values, tight vertical rhythm.
   - Circular score hierarchy for daily metrics.
   - Thin dividers, compact rows, short labels, charts without decoration.
   - Focused detail pages put one metric hero above drivers and interpretation.
3. `09` modern community screenshot
   - Dense workout detail, clear cardio/muscular separation, compact chart and destructive sheet.
4. `10`–`16` official editorial images
   - Strength logger density, set cards, compact chart tiles and three-score grouping.
   - Used for hierarchy only; no imagery, logos, fonts, icons or wording is copied.
5. `17`–`18` older reviews
   - Secondary chart and range-control references only.
   - Never override image 00 navigation or current store density.

## Screen mapping

| NOOP surface | Primary references | Original implementation direction |
|---|---|---|
| Root dock | 00 | Floating capsule dock + separate NOOP Coach circle |
| Today | 01, 09, 13, 16 | Charge / Rest / Effort score hierarchy, then authoritative Today sections |
| Charge | 03, 14–16 | Large Charge ring; status, confidence, drivers, baseline, provenance |
| Rest/Sleep | 02, 11 | Rest hero; duration/need/debt/stages/consistency in compact rows |
| Effort | 04, 16 | Effort ring and target; HR zones/workouts; Muscular Load remains separate |
| Health Monitor | 03, 12, 15 | Dense metric grid with text status and baseline deltas |
| Stress | 12, 18 | Current-state hero, thin chart, periods, existing Breathe action |
| Trends | 18 | Range segmented control, textual summary, sparse-data state, compact chart |
| Workouts | 09, 16 | Dense list/detail, duration, Effort, zones and existing editing |
| Strength Home | 09, 10 | Session status, templates/history/body-map entries in shared cards |
| Logger | 10 | Dense exercise/set cards, practical controls, no reduced tap targets |
| Body Map | shared tokens only | Preserve original NOOP vector anatomy and authoritative load service |
| Coach | 00, 06 | Separate root action; restrained transcript, tool state and composer |
| Goal/Plan/Journey | 01, 07 | Compact progress/proposal cards and timeline; existing actions unchanged |
| Privacy/Settings/Backup | 07 plus shared cards | Explicit status rows, full disclosure, strong confirmation hierarchy |

## Brand and implementation boundary

- Use only SF Symbols and original NOOP shapes.
- Use system/project-approved fonts.
- Do not introduce a WHOOP wordmark, W mark, proprietary icon, proprietary anatomical
  art, screenshot, photograph, illustration, font, or branded copy.
- Use NOOP metric names and meanings: Charge, Rest, Effort, Muscular Load and Total
  Training Load are not renamed to imitate another product.
- Reusable components live in `StrandDesign`; screen adapters remain in the app layer.
