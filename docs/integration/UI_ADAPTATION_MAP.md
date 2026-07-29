# DX Performance UI Adaptation Map

The integration changes presentation, not DX ownership or state.

| Functional surface | DX source of truth | Adaptation |
| --- | --- | --- |
| iOS shell and tabs | `RootTabView` | Add Strength routes/entry without a second tab-state model |
| Today | `LiquidTodayView` + `TodayLayoutPrefs` | Apply performance cards and add reorderable/hideable Strength status after Last Workouts |
| Charge/Effort/Rest | Existing DX displays/services | Restyle only; preserve calculations, no WHOOP formulas |
| Coach | DX `CoachView` and entry components | Apply theme tokens, retain streaming/history/provider behavior |
| Goal/Journey | DX Goal/Journey stores and screens | Apply cards/typography without replacing lifecycle logic |
| Plan proposals | DX `PlanTodayCard`/`CoachPlanStore` | Add Strength metadata/action while preserving Accept/Modify/Decline/Swap |
| Updates/Data Sources | Existing DX sections | Preserve content and arrangement behavior |
| Strength | Donor domain and screens | Adapt to DX navigation/theme, add crash recovery and visible errors |
| Body Map | Donor SwiftUI vector map | Preserve front/back anatomy and connect authoritative load services |
| Privacy | DX consent settings | Add Strength and separately gated pain controls |

## Reusable presentation layer

Create StrandDesign components/tokens for `PerformanceTheme`,
`PerformanceCard`, `MetricRing`, `MetricValueBlock`, `StatusPill`,
`ReadinessCard`, `TrainingLoadCard`, `PlanProposalPerformanceCard`,
`StrengthStatusCard`, `MuscleStatusCard` and `CoachEntryPerformanceCard`.

All components must support VoiceOver, Dynamic Type, Reduce Motion, high
contrast and Thai text expansion. Gradients/glow are restrained and no
proprietary WHOOP asset, font or exact layout is copied.

## Strength Today card

- Latest Strength session and freshness.
- Estimated Muscular Load and decomposed Total Training Load.
- Highest current residual muscles and confidence.
- Small original front/back body-map preview.
- Current soreness status; pain is shown only in the appropriate sensitive UI.
- Explicit Open Strength action.
- Reads from the same repositories/services as Strength screens and Coach
  tools; no stored display-only snapshot becomes authoritative.

