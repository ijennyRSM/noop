# iOS performance-dashboard redesign

This fork gives the NOOP iPhone app a compact, wearable-performance visual
language while keeping NOOP's product identity and functionality. It is an
independent implementation; no proprietary artwork, fonts, or source assets are
included.

## Scope

- Near-black canvas, graphite cards, high-contrast typography, and a restrained
  blue action colour across shared iPhone screens.
- Condensed score and heading typography, tabular numerals, flatter cards, and
  tighter layout rhythm.
- Recovery, Strain, and Sleep rings on Today in place of the former liquid
  vessels.
- A full-width bottom navigation bar with a clear active indicator in place of
  the floating glass capsule.
- Flat iPhone page headers. The decorative day-cycle background remains
  available as an optional personalisation setting, but is off by default.
- Shared controls, segmented selectors, primary buttons, charts, lists, Live,
  workouts, settings, and NOOP-only features inherit the same visual tokens.

## Safety boundary

The redesign changes presentation only. It does not intentionally change BLE
frames, WHOOP protocol handling, collection/backfill, HealthKit import, health
calculations, scoring, database storage, privacy, or offline behaviour.

## Visual source of truth

Most reusable styling lives in:

- `Packages/StrandDesign/Sources/StrandDesign/Palette.swift`
- `Packages/StrandDesign/Sources/StrandDesign/Typography.swift`
- `Packages/StrandDesign/Sources/StrandDesign/Components.swift`
- `Packages/StrandDesign/Sources/StrandDesign/StrandCard.swift`
- `Strand/Screens/ScreenScaffold.swift`
- `StrandiOS/App/RootTabView.swift`

Keeping the redesign concentrated in these files makes future upstream merges
easier. Screen-specific exceptions should use `NoopMetrics` and
`StrandPalette` instead of introducing new literal colours or corner radii.
## Updating from upstream

After merging upstream `main`, resolve changes in the shared design files first,
then build the `NOOPiOS` scheme. New screens that use `ScreenScaffold`,
`NoopCard`, `SectionHeader`, and the shared button styles automatically inherit
the redesigned presentation.
