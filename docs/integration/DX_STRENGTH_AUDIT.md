# DX + Thai Strength Full Integration Audit

## Recorded sources

The integration was started on 2026-07-29 after fetching every configured remote.

| Role | Repository/ref | SHA |
| --- | --- | --- |
| Target base | `ijennyRSM/noop main` | `cffa14a211858c2b40db8fcd87c2bad7071daff9` |
| Application/Coach foundation | `DX23876/noop main` | `6c6e3e8fdb4731226e143abfddb2ab4d891c563f` |
| Thai/Strength donor | `ijennyRSM/noop agent/noop-coach-strength-foundation` | `e9f558f2a801d93721e4964d943e370e13a7c832` |
| Protocol upstream | `ryanbr/noop main` | `498304423ce142e3d4a9c127897985a858c33a4a` |

The immutable donor reference is the annotated tag
`thai-strength-donor-stable-e9f558f`. The integration branch is based directly
on DX main; donor history is not merged or bulk cherry-picked.

## Repository relationship

- Target main and DX share `7f501530`; target has 2 unique commits and DX has
  189 unique commits.
- DX and donor share upstream base `e4651963`; DX has 16 unique commits and the
  donor has 43 unique commits.
- File inventory at the recorded SHAs: 1,910 shared paths, 207 DX-only paths,
  and 53 donor-only paths.

## Architecture findings

### DX foundation

- `AICoach.swift` owns provider requests, streaming, tool dispatch, prompt
  budgeting and lifecycle.
- `CoachTools`, `ToolConsent`, `CoachMemory`, `CoachGoal`, `CoachPlanStore`,
  `CoachTranscriptStore`, `Journey*` and `CoachSemanticMemory` form a connected
  architecture and must remain authoritative.
- `RootTabView` and `LiquidTodayView` own iOS navigation and Today state.
  `TodayLayoutPrefs` already provides one reorder/hide model shared with
  Android.
- `Packages/SemanticMemory`, the pinned Nomic GGUF and the llama XCFramework
  are the Full on-device semantic runtime. Binary inputs are intentionally
  ignored by Git and installed by `Tools/bootstrap-nomic.sh` before XcodeGen.
- DX WhoopStore currently ends at migration `v31-deep-capture-channels`.
- The existing `.noopbak` implementation already provides integrity checks,
  sidecar rollback and legacy ZIP/plain-SQLite support, but only archives the
  database plus a small whitelisted `settings.json`.

### Donor implementation

- Strength is additive and starts at `v32-strength-training` in the same
  WhoopStore database.
- Donor-only modules provide the 420-exercise offline library, stable exercise
  IDs, 22-muscle taxonomy, logger/store, templates, session/daily/residual
  derived data, quick summaries and the anatomical SwiftUI body map.
- `CurrentMuscleResidualService` recalculates residual load from session
  history and treats snapshots as cache/fallback.
- `CanonicalDay` fixes Gregorian day-key handling under Thai/Buddhist user
  calendars. `CoachDurationFormatter` provides natural duration text.
- Donor `AICoach.swift` and `CoachSnapshot.swift` are a smaller alternative
  Coach architecture and must not replace DX.
- Donor profile and soreness values are stored in UserDefaults. Historical
  donor `.noopbak` files do not contain those keys because they are not in the
  backup whitelist.

## Integration risks and controls

| Risk | Control |
| --- | --- |
| Replacing DX Coach with donor snapshot logic | Do not copy donor `AICoach` or `CoachSnapshot`; expose Strength through DX tools and adapters |
| Migration collision | Reserve donor `v32-strength-training`; put integration-only schema in `v33-strength-integration` |
| Competing Today state | Extend `TodaySection` and render from DX repositories only |
| Buddhist-calendar stale data | Make `CanonicalDay` the only parser for stored day keys |
| Pain leaking through Strength consent | Store pain separately and require an additional `painSensitive` permission before serialization |
| Stale residual snapshots | Recalculate from session-level source rows, cache for 15 minutes, invalidate on mutations/foreground |
| Semantic overcollection | Embed only approved prose; query numerical Strength history through deterministic tools |
| Backup partial restore | Stage and verify all V2 entries, preserve a rollback set, then atomically replace |
| Free-account sideload failures | Keep main app independent of Watch/widgets and strip embedded extensions in unsigned packaging |
| Nomic missing from an apparently successful build | Bootstrap before XcodeGen and inspect the final app for GGUF and llama framework |

## License and resource findings

- The project remains under the existing PolyForm Noncommercial license.
- Exercise data source, revision and per-record license metadata are carried by
  the donor resource and documented in `EXERCISE_LIBRARY*.md`.
- The body map is original SwiftUI vector code; no proprietary anatomical or
  WHOOP artwork is imported.
- WHOOP-inspired adaptation is limited to reusable presentation principles,
  not proprietary fonts, assets, formulas or pixel-identical screens.

