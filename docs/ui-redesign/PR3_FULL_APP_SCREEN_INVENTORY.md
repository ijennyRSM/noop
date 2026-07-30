# PR #3 Full-App Visual Port — Screen Inventory

This inventory continues Draft PR #9 from the approved Milestone 1 head
`51c5df894d164f040233325ba2297f417bffbe91`. The Full Beta integration remains
the only data and behavior source. “Port” below means presentation only.

Status values are `baseline`, `planned`, `in progress`, `redesigned`, or
`intentionally unchanged`.

## Approved regression baseline

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 1 | Root navigation | app shell | `StrandiOS/App/RootTabView.swift` | `RootTabView` | `NavRouter`, `Repository`, existing DX Coach | high | baseline |
| 2 | Today top | Home | `Strand/Liquid/LiquidTodayView.swift` | existing Today state | `Repository`, plan/update stores | high | baseline |
| 3 | Today scrolled | Home scroll | `Strand/Liquid/LiquidTodayView.swift` | existing Today state | workouts, vitals, data sources | high | baseline |
| 4 | Charge detail | Today score | `Strand/Screens/PR3ScoreDetailView.swift` | `Repository` | current score/trend | medium | baseline |
| 5 | Rest detail | Today score | `Strand/Screens/PR3ScoreDetailView.swift` | `Repository` | sleep score/trend | medium | baseline |
| 6 | Effort detail | Today score | `Strand/Screens/PR3ScoreDetailView.swift` | `Repository` | effort score/trend | medium | baseline |

## Strength and muscle load

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 7 | Strength home/history | More → Strength | `StrengthTrainingView.swift` | `StrengthHistoryView` | `WhoopStore`, residual service | high | planned |
| 8 | Start Strength | Strength → Start | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | creates draft session | high | planned |
| 9 | Active logger | active session | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | autosave, set edits, finish | high | planned |
| 10 | Exercise picker | logger sheet | `StrengthTrainingView.swift` | view model | search/favorite/recent | medium | planned |
| 11 | Exercise filters | picker | `StrengthTrainingView.swift` | view model | muscle/equipment filters | low | planned |
| 12 | Custom exercise | picker sheet | `StrengthTrainingView.swift` | view model | stable custom exercise write | high | planned |
| 13 | Templates | logger sheet | `StrengthTrainingView.swift` | view model | load/save/delete template | high | planned |
| 14 | Session detail/editor | history row | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | edit/delete/recalculate | high | planned |
| 15 | Exercise history | session exercise | `StrengthTrainingView.swift` | store query | prior sets/progression | medium | planned |
| 16 | Detected Strength summary | workout detail sheet | `DetectedStrengthDetailsSheet.swift` | existing detected-workout state | reclassify/atomic commit | high | planned |
| 17 | Body Map front | Strength/Today | `MuscleBodyMapView.swift` | `MuscleBodyMapModel` | residual/current load service | high | planned |
| 18 | Body Map back | Body Map toggle | `MuscleBodyMapView.swift` | same model | side selection only | medium | planned |
| 19 | Muscle detail | Body Map selection | `MuscleBodyMapView.swift` | selected muscle summary | recent sessions/confidence | medium | planned |
| 20 | Soreness check-in | Strength/Body Map | `MuscleBodyMapView.swift` | `CoachCheckInStore` | add/edit/delete/skip | high | planned |
| 21 | Pain/discomfort state | check-in | `MuscleBodyMapView.swift` | check-in draft/store | sensitive consent-separated write | high | planned |

## Coach, goals, plans, journey, and updates

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 22 | Coach conversation | circular Coach action | `CoachView.swift` | `AICoachEngine` | send/cancel/tool calls/history | high | planned |
| 23 | Coach loading/streaming | conversation | `CoachView.swift` | engine streaming state | cancel/retry | high | planned |
| 24 | Coach tool-call state | conversation | `CoachView.swift` | tool result state | disclose tool status | high | planned |
| 25 | Coach plan proposal | conversation embed | `CoachView.swift`, `PlanTodayCard.swift` | `CoachPlanStore` | accept/modify/decline | high | planned |
| 26 | Conversation history | Coach toolbar | `CoachHistoryView.swift` | transcript store | open/delete conversation | high | planned |
| 27 | Coach identity/persona | Coach settings | `CoachIdentityEditor.swift` | identity store | edit persona | medium | planned |
| 28 | Coach information | Coach settings | `CoachInfoView.swift` | static + preferences | disclosures | low | planned |
| 29 | Coach settings | More/Settings | `CoachSettingsView.swift` | AppStorage + engine stores | provider/privacy/memory | high | planned |
| 30 | Provider/model selection | Coach settings sheet | `ModelSearchSheet.swift`, `CoachSettingsView.swift` | provider settings | choose/test provider/model | high | planned |
| 31 | Semantic Memory | Coach settings | `CoachSettingsView.swift` | semantic memory settings | enable/rebuild/delete | high | planned |
| 32 | Goal hub | Plan tab | `CoachGoalJourneyView.swift` | goal/plan stores | navigate Goal/Plan/Journey | medium | planned |
| 33 | Goal editor/onboarding | Goal hub sheet | `CoachGoalView.swift` | `CoachGoalStore` | add/edit/archive goal | high | planned |
| 34 | Plan Book | Goal hub | `CoachPlanView.swift` | `CoachPlanStore` | schedule/start/skip/swap | high | planned |
| 35 | Plan proposal detail | Plan/Coach | `CoachPlanView.swift` | plan store | accept/modify/decline | high | planned |
| 36 | Plan time/reschedule | Plan sheet | `CoachPlanView.swift` | plan store | schedule/reschedule | high | planned |
| 37 | Plan swap | Plan sheet | `CoachPlanView.swift` | plan store | swap proposal | high | planned |
| 38 | Journey | Goal hub | `JourneyView.swift` | goal/plan/journey derivation | milestone inspection | medium | planned |
| 39 | Updates inbox | Today bell | `UpdatesInboxView.swift` | `UpdateStore` | mark read/clear/route/restore | medium | planned |
| 40 | Updates empty state | inbox | `UpdatesInboxView.swift` | `UpdateStore` | none | low | planned |

## Workouts

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 41 | Workout history | More → Workouts | `WorkoutsView.swift` | `Repository` + local filter state | search/filter/open | high | planned |
| 42 | Workout row/timeline | history | `WorkoutsView.swift` | derived row presentation | selection | medium | planned |
| 43 | Workout detail | history row | `WorkoutDetailView.swift` | `Repository`/workout row | edit/delete/reclassify | high | planned |
| 44 | HR graph/zones | detail | `WorkoutDetailView.swift` | stored samples/zone summary | range inspection | high | planned |
| 45 | Workout route map | detail | `WorkoutDetailView.swift` | stored route | map interaction | medium | planned |
| 46 | Manual workout | quick action | `ManualWorkoutSheet.swift` | draft + repository | save/cancel | high | planned |
| 47 | Live workout | quick action | `LiveWorkoutView.swift` | active workout persistence | start/pause/finish | high | planned |
| 48 | Workout edit/delete confirmations | detail | `WorkoutDetailView.swift` | repository | mutation confirmation | high | planned |

## Privacy, backup, import/export

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 49 | Privacy presets | Coach settings | `CoachSettingsView.swift` | consent preferences | preset apply | high | planned |
| 50 | Individual purpose consent | privacy | `CoachSettingsView.swift` | `ToolConsent` | purpose toggle | high | planned |
| 51 | Strength consent | privacy | `CoachSettingsView.swift` | Strength consent | enable/revoke | high | planned |
| 52 | Pain-sensitive consent | privacy | `CoachSettingsView.swift` | pain-sensitive consent | explicit confirmation | high | planned |
| 53 | Provider disclosure | privacy/provider | `CoachSettingsView.swift` | provider configuration | review disclosure | high | planned |
| 54 | Backup home | Settings → Backup | `BackupSyncView.swift` | backup preferences/status | export/import/auto backup | high | planned |
| 55 | Restore file picker | Backup | `BackupSyncView.swift` | restore staging state | select/validate file | high | planned |
| 56 | Restore preview/conflict | restore flow | `BackupSyncView.swift` | Unified Backup V2 | confirm/cancel/rollback | high | planned |
| 57 | Import validation/result | Settings/import route | `SettingsView.swift`, system picker | repository/import service | validate/import | high | planned |
| 58 | Export success/failure | Settings/export route | `SettingsView.swift`, `FileExport.swift` | repository/export service | share/dismiss | high | planned |
| 59 | Migration preview/warning | restore/import | existing backup/import flow | staging result | continue/cancel | high | planned |

## Settings, devices, and data sources

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 60 | Settings root | More → Settings | `SettingsView.swift` | AppStorage/Profile/Repository | open/edit all preferences | high | planned |
| 61 | Profile/account | Settings | `SettingsView.swift` | `ProfileStore` | edit user fields | medium | planned |
| 62 | Appearance/units/Effort scale | Settings | `SettingsView.swift` | AppStorage | change presentation units | medium | planned |
| 63 | Today arrangement | Settings | `DashboardCardsEditorSheet.swift` | layout prefs | reorder/hide | medium | planned |
| 64 | Notifications | Settings | `NotificationSettingsView.swift` | notification prefs | authorization/toggles | high | planned |
| 65 | Device list | More → Devices | `DevicesView.swift` | `Repository`/BLE coordinator | pair/switch/remove | high | planned |
| 66 | Add device wizard | Devices | `AddDeviceWizard.swift` | wizard state + repository | scan/pair/cancel | high | planned |
| 67 | Device sync/offload | Devices/Live | `DevicesView.swift`, `LiveView.swift` | BLE/repository | sync/diagnostics | high | planned |
| 68 | Data Sources | More → Data Sources | `DataSourcesView.swift` | `Repository` | open source detail | medium | planned |
| 69 | Apple Health | Data Sources | `AppleHealthView.swift` | HealthKit bridge/repository | authorize/import | high | planned |
| 70 | Imported/source records | Data Sources | `FusedRecordView.swift` | repository | source selection | high | planned |
| 71 | Storage | Settings | `StorageView.swift` | repository/store | inspect/prune/export | high | planned |
| 72 | Diagnostics/Test Centre | Settings | `TestCentreView.swift` | diagnostics state | capture/export report | high | planned |
| 73 | About/What’s New | Settings/Updates | `HowNoopWorksView.swift`, `WhatsNewView.swift` | project/update metadata | disclosure/open links | low | planned |

## Cross-cutting states

| # | State | Owners | Required treatment | Status |
|---:|---|---|---|---|
| 74 | Loading/skeleton | each screen state owner | compact neutral progress, no fake metrics | planned |
| 75 | Empty/no data | repository/store query | truthful explanation + primary action | planned |
| 76 | Insufficient baseline | analytics result | explain confidence and missing history | planned |
| 77 | Permission denied | HealthKit/Bluetooth/notifications | explicit permission route | planned |
| 78 | Disconnected device | BLE/repository | status + reconnect guidance | planned |
| 79 | Provider unavailable/AI error | Coach engine/provider | retry/settings without data loss | planned |
| 80 | Import/restore/session failure | transaction owner | error detail + safe recovery | planned |
| 81 | Destructive confirmation | owning screen | explicit object and impact | planned |
| 82 | Stale/low-confidence data | analytics/store | text status, not color only | planned |

Inventory count: **82 classified screens/states**. Newly discovered user-facing
routes must be added here before they can be marked redesigned.
