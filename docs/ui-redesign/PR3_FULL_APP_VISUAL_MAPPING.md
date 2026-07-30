# PR #3 Full-App Visual Mapping

## Fixed source priority

1. Approved PR #9 Milestone 1 at `51c5df894d164f040233325ba2297f417bffbe91`
2. PR #3 donor at `3b0ad22fa6add28d96aaa71940e65403aaad2d54`
3. PR #3 reference screenshot
4. Current WHOOP references
5. Existing NOOP functionality

The first six screens are immutable visual regression fixtures. Secondary
screens inherit their character, not a universal dashboard template.

## Shared presentation primitives

| Primitive | Approved behavior | Allowed use |
|---|---|---|
| Canvas | near-black `surfaceBase` | every screen |
| Surface | graphite, flat, one restrained hairline | grouping and focused controls |
| Typography | `HelveticaNeue-CondensedBold` for scores/page performance headings; readable Helvetica/system body | numeric hierarchy and headings |
| Numerals | explicit sizes, tight tracking, tabular digits | scores, timers, weights, reps |
| Actions | blue/cyan primary; neutral secondary; red destructive | buttons and selected controls |
| Status | text plus color; Charge band colors preserved | confidence/freshness/state |
| Motion | short, restrained, Reduce Motion aware | transitions only |
| Empty/error | truthful text, single useful action | state handling |

`StrandCard`/surface modifiers may supply fill, border, and radius. They may
not determine section order, hero geometry, or force a metric grid.

## Screen-specific mapping

| Module | Composition | Milestone reference | Explicitly avoid |
|---|---|---|---|
| Strength Home | compact header → muscle-status lead → Start → modes → templates/history → map/check-in | Today hierarchy, My Day density | equal two-column metric dashboard |
| Active Logger | sticky summary → exercise header → compact set table → actions | activity timeline density | one large card per set |
| Exercise Picker | fixed search → chips → dense recent/favorite/all rows | More compact rows | oversized exercise tiles |
| Strength Detail | score strip → exercise/set table → muscle contribution | score hero typography | mixing cardio and muscle scores |
| Body Map | compact header/modes → large figure → legend → top muscles | Rest detail restraint | external anatomy art |
| Check-in | scale row → per-muscle list → separate pain panel → notes/actions | Health/Stress flat grouping | pain colored like load |
| Coach | identity header → full transcript → inline tool/proposal → fixed composer | separate Coach dock identity | dashboard cards above chat |
| Goal | active-goal hero → progress/adherence → next action | detail hero hierarchy | invented progress |
| Plan Book | week strip → chronological session rows → visible actions | My Day timeline | hidden gesture-only actions |
| Journey | compact vertical milestone timeline | activity timeline | motivational filler |
| Updates | compact unread/read rows | PR #9 graphite surfaces | second notification store |
| Workout History | date grouping → dense activity timeline rows | My Day activities | nested metric grids |
| Workout Detail | activity header → primary summary → HR chart/zones → optional Strength → provenance/actions | detail score hierarchy | equal tiles for all values |
| Privacy | preset lead → purpose groups → explicit state/disclosure → revoke/delete | compact settings density | hiding sensitive explanations |
| Backup/Restore | last state → export/import → contents/exclusions → staged preview/warnings | purposeful action hierarchy | suppressing checks/conflicts |
| Settings | compact header → grouped rows with current values → destructive footer | More rows | one card per setting |
| Devices/Data Sources | source status lead → compact source rows → sync/diagnostics | Health/Stress paired semantics | vendor imitation badges |
| Loading/Empty/Error | centered concise state within screen hierarchy | PR #9 neutral canvas | fake scores or decorative glow |

## Color contracts

- Charge: `PR3ScorePalette.charge(score:)` discrete red/yellow/green.
- Rest: fixed cool blue-gray.
- Effort: fixed blue.
- Primary action/Coach: restrained blue/cyan.
- Muscular load: existing load scale only.
- Soreness: warm neutral warning scale.
- Pain: separate red warning treatment and explicit “Pain/discomfort” text.
- Chart themes may color detailed charts but never primary score identity.

## Baseline geometry

See `PR3_VISUAL_PORT_MILESTONE_1.md`. Regression capture compares approved
images with the current branch. Any geometry change to the six baseline screens
must be explained in the difference report.
