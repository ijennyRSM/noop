# PR #3 Full-App Visual Port — Screen Inventory

This inventory continues Draft PR #9 from the approved Milestone 1 head
`51c5df894d164f040233325ba2297f417bffbe91`. The Full Beta integration remains
the only data and behavior source. “Port” below means presentation only.

Status values are `baseline`, `redesigned`, `shared presentation`, or
`intentionally unchanged`. `Shared presentation` means the route retains its
specialized controls and state owner while receiving the PR3 scaffold,
typography, grouped-row, and truthful-state language from its parent screen.

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
| 7 | Strength home/history | More → Strength | `StrengthTrainingView.swift` | `StrengthHistoryView` | `WhoopStore`, residual service | high | redesigned |
| 8 | Start Strength | Strength → Start | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | creates draft session | high | redesigned |
| 9 | Active logger | active session | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | autosave, set edits, finish | high | redesigned |
| 10 | Exercise picker | logger sheet | `StrengthTrainingView.swift` | view model | search/favorite/recent | medium | redesigned |
| 11 | Exercise filters | picker | `StrengthTrainingView.swift` | view model | muscle/equipment filters | low | redesigned |
| 12 | Custom exercise | picker sheet | `StrengthTrainingView.swift` | view model | stable custom exercise write | high | shared presentation |
| 13 | Templates | logger sheet | `StrengthTrainingView.swift` | view model | load/save/delete template | high | redesigned |
| 14 | Session detail/editor | history row | `StrengthTrainingView.swift` | `StrengthTrainingViewModel` | edit/delete/recalculate | high | redesigned |
| 15 | Exercise history | session exercise | `StrengthTrainingView.swift` | store query | prior sets/progression | medium | shared presentation |
| 16 | Detected Strength summary | workout detail sheet | `DetectedStrengthDetailsSheet.swift` | existing detected-workout state | reclassify/atomic commit | high | shared presentation |
| 17 | Body Map front | Strength/Today | `MuscleBodyMapView.swift` | `MuscleBodyMapModel` | residual/current load service | high | redesigned |
| 18 | Body Map back | Body Map toggle | `MuscleBodyMapView.swift` | same model | side selection only | medium | redesigned |
| 19 | Muscle detail | Body Map selection | `MuscleBodyMapView.swift` | selected muscle summary | recent sessions/confidence | medium | redesigned |
| 20 | Soreness check-in | Strength/Body Map | `MuscleBodyMapView.swift` | `CoachCheckInStore` | add/edit/delete/skip | high | redesigned |
| 21 | Pain/discomfort state | check-in | `MuscleBodyMapView.swift` | check-in draft/store | sensitive consent-separated write | high | redesigned |

## Coach, goals, plans, journey, and updates

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 22 | Coach conversation | circular Coach action | `CoachView.swift` | `AICoachEngine` | send/cancel/tool calls/history | high | redesigned |
| 23 | Coach loading/streaming | conversation | `CoachView.swift` | engine streaming state | cancel/retry | high | redesigned |
| 24 | Coach tool-call state | conversation | `CoachView.swift` | tool result state | disclose tool status | high | redesigned |
| 25 | Coach plan proposal | conversation embed | `CoachView.swift`, `PlanTodayCard.swift` | `CoachPlanStore` | accept/modify/decline | high | redesigned |
| 26 | Conversation history | Coach toolbar | `CoachHistoryView.swift` | transcript store | open/delete conversation | high | shared presentation |
| 27 | Coach identity/persona | Coach settings | `CoachIdentityEditor.swift` | identity store | edit persona | medium | shared presentation |
| 28 | Coach information | Coach settings | `CoachInfoView.swift` | static + preferences | disclosures | low | shared presentation |
| 29 | Coach settings | More/Settings | `CoachSettingsView.swift` | AppStorage + engine stores | provider/privacy/memory | high | redesigned |
| 30 | Provider/model selection | Coach settings sheet | `ModelSearchSheet.swift`, `CoachSettingsView.swift` | provider settings | choose/test provider/model | high | redesigned |
| 31 | Semantic Memory | Coach settings | `CoachSettingsView.swift` | semantic memory settings | enable/rebuild/delete | high | redesigned |
| 32 | Goal hub | Plan tab | `CoachGoalJourneyView.swift` | goal/plan stores | navigate Goal/Plan/Journey | medium | redesigned |
| 33 | Goal editor/onboarding | Goal hub sheet | `CoachGoalView.swift` | `CoachGoalStore` | add/edit/archive goal | high | shared presentation |
| 34 | Plan Book | Goal hub | `CoachPlanView.swift` | `CoachPlanStore` | schedule/start/skip/swap | high | redesigned |
| 35 | Plan proposal detail | Plan/Coach | `CoachPlanView.swift` | plan store | accept/modify/decline | high | redesigned |
| 36 | Plan time/reschedule | Plan sheet | `CoachPlanView.swift` | plan store | schedule/reschedule | high | redesigned |
| 37 | Plan swap | Plan sheet | `CoachPlanView.swift` | plan store | swap proposal | high | redesigned |
| 38 | Journey | Goal hub | `JourneyView.swift` | goal/plan/journey derivation | milestone inspection | medium | redesigned |
| 39 | Updates inbox | Today bell | `UpdatesInboxView.swift` | `UpdateStore` | mark read/clear/route/restore | medium | redesigned |
| 40 | Updates empty state | inbox | `UpdatesInboxView.swift` | `UpdateStore` | none | low | redesigned |

## Workouts

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 41 | Workout history | More → Workouts | `WorkoutsView.swift` | `Repository` + local filter state | search/filter/open | high | redesigned |
| 42 | Workout row/timeline | history | `WorkoutsView.swift` | derived row presentation | selection | medium | redesigned |
| 43 | Workout detail | history row | `WorkoutDetailView.swift` | `Repository`/workout row | edit/delete/reclassify | high | redesigned |
| 44 | HR graph/zones | detail | `WorkoutDetailView.swift` | stored samples/zone summary | range inspection | high | redesigned |
| 45 | Workout route map | detail | `WorkoutDetailView.swift` | stored route | map interaction | medium | shared presentation |
| 46 | Manual workout | quick action | `ManualWorkoutSheet.swift` | draft + repository | save/cancel | high | intentionally unchanged |
| 47 | Live workout | quick action | `LiveWorkoutView.swift` | active workout persistence | start/pause/finish | high | intentionally unchanged |
| 48 | Workout edit/delete confirmations | detail | `WorkoutDetailView.swift` | repository | mutation confirmation | high | redesigned |

## Privacy, backup, import/export

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 49 | Privacy presets | Coach settings | `CoachSettingsView.swift` | consent preferences | preset apply | high | redesigned |
| 50 | Individual purpose consent | privacy | `CoachSettingsView.swift` | `ToolConsent` | purpose toggle | high | redesigned |
| 51 | Strength consent | privacy | `CoachSettingsView.swift` | Strength consent | enable/revoke | high | redesigned |
| 52 | Pain-sensitive consent | privacy | `CoachSettingsView.swift` | pain-sensitive consent | explicit confirmation | high | redesigned |
| 53 | Provider disclosure | privacy/provider | `CoachSettingsView.swift` | provider configuration | review disclosure | high | redesigned |
| 54 | Backup home | Settings → Backup | `BackupSyncView.swift` | backup preferences/status | export/import/auto backup | high | redesigned |
| 55 | Restore file picker | Backup | `BackupSyncView.swift` | restore staging state | select/validate file | high | redesigned |
| 56 | Restore preview/conflict | restore flow | `BackupSyncView.swift` | Unified Backup V2 | confirm/cancel/rollback | high | redesigned |
| 57 | Import validation/result | Settings/import route | `SettingsView.swift`, system picker | repository/import service | validate/import | high | shared presentation |
| 58 | Export success/failure | Settings/export route | `SettingsView.swift`, `FileExport.swift` | repository/export service | share/dismiss | high | shared presentation |
| 59 | Migration preview/warning | restore/import | existing backup/import flow | staging result | continue/cancel | high | shared presentation |

## Settings, devices, and data sources

| # | Screen/state | Route | Source | State owner | Actions/services | Risk | Status |
|---:|---|---|---|---|---|---|---|
| 60 | Settings root | More → Settings | `SettingsView.swift` | AppStorage/Profile/Repository | open/edit all preferences | high | redesigned |
| 61 | Profile/account | Settings | `SettingsView.swift` | `ProfileStore` | edit user fields | medium | redesigned |
| 62 | Appearance/units/Effort scale | Settings | `SettingsView.swift` | AppStorage | change presentation units | medium | redesigned |
| 63 | Today arrangement | Settings | `DashboardCardsEditorSheet.swift` | layout prefs | reorder/hide | medium | shared presentation |
| 64 | Notifications | Settings | `NotificationSettingsView.swift` | notification prefs | authorization/toggles | high | shared presentation |
| 65 | Device list | More → Devices | `DevicesView.swift` | `Repository`/BLE coordinator | pair/switch/remove | high | redesigned |
| 66 | Add device wizard | Devices | `AddDeviceWizard.swift` | wizard state + repository | scan/pair/cancel | high | shared presentation |
| 67 | Device sync/offload | Devices/Live | `DevicesView.swift`, `LiveView.swift` | BLE/repository | sync/diagnostics | high | redesigned |
| 68 | Data Sources | More → Data Sources | `DataSourcesView.swift` | `Repository` | open source detail | medium | redesigned |
| 69 | Apple Health | Data Sources | `AppleHealthView.swift` | HealthKit bridge/repository | authorize/import | high | shared presentation |
| 70 | Imported/source records | Data Sources | `FusedRecordView.swift` | repository | source selection | high | shared presentation |
| 71 | Storage | Settings | `StorageView.swift` | repository/store | inspect/prune/export | high | shared presentation |
| 72 | Diagnostics/Test Centre | Settings | `TestCentreView.swift` | diagnostics state | capture/export report | high | shared presentation |
| 73 | About/What’s New | Settings/Updates | `HowNoopWorksView.swift`, `WhatsNewView.swift` | project/update metadata | disclosure/open links | low | shared presentation |

## Cross-cutting states

| # | State | Owners | Required treatment | Status |
|---:|---|---|---|---|
| 74 | Loading/skeleton | each screen state owner | compact neutral progress, no fake metrics | redesigned |
| 75 | Empty/no data | repository/store query | truthful explanation + primary action | redesigned |
| 76 | Insufficient baseline | analytics result | explain confidence and missing history | shared presentation |
| 77 | Permission denied | HealthKit/Bluetooth/notifications | explicit permission route | shared presentation |
| 78 | Disconnected device | BLE/repository | status + reconnect guidance | shared presentation |
| 79 | Provider unavailable/AI error | Coach engine/provider | retry/settings without data loss | redesigned |
| 80 | Import/restore/session failure | transaction owner | error detail + safe recovery | redesigned |
| 81 | Destructive confirmation | owning screen | explicit object and impact | redesigned |
| 82 | Stale/low-confidence data | analytics/store | text status, not color only | shared presentation |

Inventory count: **82 classified screens/states**. Newly discovered user-facing
routes must be added here before they can be marked redesigned.

Current classification: **51 redesigned**, **6 approved baseline**, **23 shared
presentation**, and **2 intentionally unchanged**. Manual and live workout
entry remain deliberately unchanged because their timing/persistence controls
were not part of the 47-screen visual gate; this is a documented deviation,
not an unreviewed claim of completion.
