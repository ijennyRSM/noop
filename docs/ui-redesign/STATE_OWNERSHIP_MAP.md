# UI redesign state-ownership map

This branch changes presentation, never state ownership. The table below is the
integration contract used during review.

| Domain | Authoritative owner | UI may do | UI must not do |
|---|---|---|---|
| Root routes | `RootTabView`, `NavigationPath`, `NavRouter`, `TabRoute`, `MoreDestination` | remap the four visible root positions to truthful existing hubs; style dock; preserve paths/reselect/deep links | create a second router, duplicate destinations, invent Community |
| Today | existing `LiquidTodayView`/`TodayView` state, `Repository`, `TodayLayoutPrefs` | reuse the same data and actions in performance presentation | create a parallel Today model, change calculation or hide sections |
| Charge/Rest/Effort | existing repository/readiness/sleep/effort models | format and arrange values | rename semantics, change formulas, infer missing values |
| Health/Trends | `Repository`, `MetricCatalog`, existing view-local range state | style charts/cards, add textual accessibility summaries | modify measurements, windows, sources or provenance |
| Workouts | repository, recorder and workout source models | style list/detail/forms | alter edit/delete/merge/import behaviour |
| Strength | Strength store, view models, `StrengthSessionFinalizer`, `StrengthDerivedCommit` | restyle logger/picker/history | change canonical IDs, autosave/finalization, derived calculations |
| Muscle load | `CurrentMuscleResidualService`, Strength store | display Today/7-day/Residual output | recalculate in a view or persist a second cache |
| Soreness/pain | Strength integration store + consent | show/edit through existing actions | combine pain with soreness/load or expose without consent |
| Coach | `AICoachEngine`, tool catalog, transcript/memory stores | style transcript/composer/tool status; present existing Coach | create another Coach, change provider calls, tool permissions or prompts |
| Goal/Plan/Journey | existing goal and plan stores, Journey models | restyle and route existing actions | auto-accept plans, create sessions before Start, change adherence |
| Consent/privacy | `ToolConsent` and current settings keys | make status and consequence clearer | change defaults, bypass master/Strength/pain gates |
| Semantic Memory | existing coordinator/package | show status/actions | change embedding/index/query behaviour |
| Dates | `CanonicalDay` and existing timestamp contracts | localized display only | parse stored `yyyy-MM-dd` using `Calendar.current` |
| Import/export | existing importers/exporters/document pickers | restyle entry/preview/confirmation | change formats, skip validation, duplicate import state |
| Backup V2 | `UnifiedBackupV2` coordinator | style staging/preview/result | change manifest, whitelist, checksums or rollback |
| BLE/devices | `LiveState`, BLE manager, device registry | style connection/pairing/status | change protocol, commands, collection or backfill |
| HealthKit | existing Health import/export services | show permission/source states | change entitlements, queries or write behaviour |
| Persistence | GRDB repository/migrations | none beyond observation and existing actions | schema/migration/SQL changes |

## Explicitly protected source areas

The UI branch should not modify these unless a compile-only presentation adapter is
unavoidably required and separately justified in the PR:

- `Strand/BLE/`
- `Strand/Collect/`
- `Packages/WhoopProtocol/`, `Packages/OuraProtocol/`, `Packages/PolarProtocol/`
- repository SQL, GRDB migrations and database schemas
- `Strand/Data/UnifiedBackupV2.swift`
- Strength formula/services and canonical exercise resources
- `Strand/AI/Providers/`, Coach tools, consent and semantic-memory internals
- HealthKit/import/export formats
- canonical date implementation

Any diff under a protected area is a release blocker until reviewed against this map.
