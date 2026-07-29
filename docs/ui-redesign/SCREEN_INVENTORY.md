# NOOP AI Full Beta iOS screen inventory

Audit base: `integration/dx-thai-strength-full` at
`6c460d1e44091d1f410f9a6133cb1eab1a7870dd`.

This inventory covers the iPhone application shell and every reachable user-facing
screen family. A row can contain a tightly coupled sheet or state owned by the same
view; those surfaces are called out explicitly in the **Surface / states** column.
`Presentation` means this branch may change layout, typography, colour, motion, and
navigation chrome only. It never authorizes a repository, calculation, persistence,
privacy, import/export, BLE, HealthKit, or AI request change.

Status legend:

- `P0`: root or daily-use surface; redesign and screenshot required.
- `P1`: major detail or data-entry surface; redesign required.
- `P2`: supporting/configuration surface; shared design-system migration required.
- `Protected`: presentation wrapper only; business behaviour stays byte-for-byte.

| # | Surface / states | Source | Route / presentation | State owner | Actions and backend services | Reference | Status | Risk |
|---:|---|---|---|---|---|---|---|---|
| 1 | Launch, terms gate, changelog | `StrandiOS/App/StrandiOSApp.swift`, `Strand/App/TermsGateView.swift`, `Strand/Screens/WhatsNewView.swift` | app root / sheet | app root `@AppStorage` | accept terms, dismiss changelog | 01–08 cards | P2 | High |
| 2 | First-run onboarding, permissions, pairing | `Strand/Onboarding/OnboardingWizard.swift`, `Strand/Screens/AddDeviceWizard.swift` | app-root overlay / sheet | wizard + `LiveState` | Bluetooth/Health permission, scan, pair | 01, grouped cards | P1 Protected | High |
| 3 | Root dock and Coach action | `StrandiOS/App/RootTabView.swift`, `Strand/Screens/CoachEntry.swift` | root overlay | `RootTabView` tab paths + `AICoachEngine` | switch/reselect tabs, present Coach | **00** | P0 | High |
| 4 | Home / Today top and scrolled dashboard | `Strand/Liquid/LiquidTodayView.swift`, `Strand/Screens/TodayView.swift`, `StrandiOS/Redesign/*` | Home tab | existing Today state + `Repository` | day navigation, open details, refresh | 01, 09, 13, 16 | P0 Protected | High |
| 5 | Arrange Today, hide/reorder, reset | `Strand/Data/TodayLayoutPrefs.swift` | Today sheet | `TodayLayoutPrefs` | move, hide/show, reset | compact grouped sheet | P1 Protected | Medium |
| 6 | Today loading, unavailable and stale data | Today implementations and `DashboardCards.swift` | inline states | existing Today loaders | retry/open sources | 01–04 state language | P0 | Medium |
| 7 | Charge hero and breakdown | `Strand/Screens/CoupledView.swift`, `StrandiOS/Redesign/HeuteChargeBreakdownView.swift`, Today sheets | Health / Today detail | `Repository`, existing readiness model | inspect drivers/baseline/provenance | 03, 14–16 | P0 Protected | High |
| 8 | Rest / Sleep overview | `Strand/Screens/SleepView.swift` | Health hub / deep link | `SleepView` existing state | select night/range, edit wake, add nap | 02, 11 | P0 Protected | High |
| 9 | Rest: edit wake, add nap, main-sleep explanation | `Strand/Screens/SleepView.swift` | sheets/popover | Sleep state + repository | save/delete/confirm | 02 | P1 Protected | High |
| 10 | Effort / daily cardiovascular load | `Strand/Screens/TodayView.swift`, `Strand/Liquid/LiquidTodayView.swift`, `Strand/Screens/TrendsView.swift` | Health hub/detail | existing effort/readiness data | inspect contributors/target | 04, 16 | P0 Protected | High |
| 11 | Health hub | `Strand/Screens/HealthView.swift`, `Strand/Screens/VitalSignsSummary.swift` | Health tab | `Repository` | open metrics, refresh | 12, 15 | P0 Protected | Medium |
| 12 | Health Monitor metric grid and alerts | `Strand/Screens/HealthView.swift`, `Strand/Screens/HealthAlertBanner.swift` | Health hub | repository + metric catalog | open metric/source | 03, 12, 15 | P0 Protected | High |
| 13 | Metric Explorer and metric detail | `Strand/Screens/MetricExplorerView.swift` | Health / More / `TabRoute.metric*` | metric view state + repository | choose range/source, inspect readings | 15, 18 | P1 Protected | High |
| 14 | Full-day HR chart and scrub | `Strand/Screens/FullDayChartView.swift` | `TabRoute.fullDayChart` | repository chart state | range/scrub | 09, 18 | P1 Protected | High |
| 15 | HRV snapshot | `Strand/Screens/HRVSnapshotView.swift` | Live sheet | `LiveState` | capture/read result | compact metric detail | P2 Protected | High |
| 16 | Stress monitor, daily chart, unavailable | `Strand/Screens/StressView.swift`, `Strand/Screens/StressCheckInCard.swift` | Health hub / More | existing stress model | check-in, open Breathe | 12, 18 | P0 Protected | High |
| 17 | Breathe / biofeedback | `Strand/Screens/BreathingView.swift`, `BiofeedbackController.swift`, `BiofeedbackPrefs.swift` | quick action / More | controller + live HR | start/pause/end/configure | dark focused session | P1 Protected | High |
| 18 | Trends overview and sparse data | `Strand/Screens/TrendsView.swift` | Health tab/hub | repository trend state | select range/metric, open report | 18 | P0 Protected | High |
| 19 | Trends report and export | `Strand/Screens/TrendsReportView.swift` | Trends sheet | report renderer | render/share/dismiss | 18 | P1 Protected | Medium |
| 20 | Weekly digest | `Strand/Screens/WeeklyDigestView.swift` | Updates/insight route | repository | inspect week | 07, 18 | P2 Protected | Medium |
| 21 | Compare | `Strand/Screens/CompareView.swift` | More/analysis | repository | select metrics/ranges | 18 | P1 Protected | High |
| 22 | Insights hub and intelligence | `InsightsHubView.swift`, `IntelligenceView.swift` | More/analysis | repository/intelligence engine | filter/open insight | 07, 18 | P1 Protected | High |
| 23 | Journal, reminders, rename | `InsightsView.swift`, `JournalLogCard.swift`, `JournalReminderCard.swift` | More / quick action | behavior store | add/edit/delete/rename | 07, 11 | P1 Protected | High |
| 24 | Hydration | `HydrationView.swift`, `HydrationStore.swift` | metric route | hydration store | add/edit/delete/custom amount | compact cards | P2 Protected | Medium |
| 25 | Caffeine | `CaffeineLogCard.swift`, `CaffeineLog.swift` | journal card | caffeine store | add/delete | compact row | P2 Protected | Medium |
| 26 | Workouts history, search/filter and empty state | `Strand/Screens/WorkoutsView.swift` | More / `TabRoute.workouts` | repository + workout state | filter, start, add/edit/merge, open detail | 09, 16 | P0 Protected | High |
| 27 | Workout add/edit/start sheets | `ManualWorkoutSheet.swift`, `LiveWorkoutView.swift` | Workouts sheets | existing recorder/repository | create/start/save/cancel | 09, 10 | P1 Protected | High |
| 28 | Workout detail, HR zones, maps, delete confirmation | `WorkoutDetailView.swift` | Workouts sheet / Today route | repository | edit/delete/open Strength | 09, 16 | P0 Protected | High |
| 29 | Live HR and active workout | `LiveView.swift`, `LiveWorkoutView.swift`, `Strand/Liquid/LiveSessionView.swift` | quick action/sheet/cover | `LiveState`, workout recorder | start/stop, zones, capture | focused dark session | P1 Protected | High |
| 30 | Interval timer | `IntervalTimerView.swift` | More | local timer state | start/pause/reset | focused dark session | P2 Protected | Medium |
| 31 | Strength Home / start session | `Strand/Screens/StrengthTrainingView.swift` | More | `StrengthTrainingViewModel`, Strength store | start/resume/open history/template/map | 10, 09 | P0 Protected | High |
| 32 | Active Strength Logger and autosave recovery | `StrengthTrainingView.swift` | Strength navigation | active session view model | sets/reps/weight/RPE/RIR/type/note/rest/finalize | 10 | P0 Protected | Critical |
| 33 | Exercise Picker, search/filter, favorites, recents | `StrengthTrainingView.swift` | logger sheet | exercise library/store | choose/favorite/create | 10 | P0 Protected | High |
| 34 | Custom exercise editor | `StrengthTrainingView.swift` | picker sheet | exercise store | create/save/cancel | dense form | P1 Protected | High |
| 35 | Strength templates | `StrengthTrainingView.swift` | Strength sheet | template store | choose/create/delete | 10 | P1 Protected | High |
| 36 | Strength history and detail | `StrengthTrainingView.swift` | Strength navigation/sheet | Strength store | inspect/edit/delete | 09, 10 | P0 Protected | High |
| 37 | Detected Strength details | `DetectedStrengthDetailsSheet.swift` | workout detail sheet | derived finalizer/store | classify/save/error | 09, 10 | P1 Protected | Critical |
| 38 | Body Map front/back, Today/7-day/Residual | `MuscleBodyMapView.swift`, `AnatomicalMuscleMap.swift` | Strength navigation | `CurrentMuscleResidualService` + store | switch mode/side/open muscle | original NOOP anatomy; shared language | P0 Protected | Critical |
| 39 | Muscle detail | `MuscleBodyMapView.swift` | Body Map sheet | body-map model | inspect load/frequency/confidence | 09, 10 | P1 Protected | High |
| 40 | Soreness check-in | `MuscleBodyMapView.swift`, Strength integration store | Body Map/Strength sheet | check-in store | edit/delete/skip | compact status cards | P0 Protected | Critical |
| 41 | Pain/discomfort confirmation | Strength check-in surfaces | check-in sheet | pain store + consent | confirm/note/delete | explicit warning cards | P1 Protected | Critical |
| 42 | Coach chat, composer, streaming and errors | `CoachView.swift`, `CoachStreamingText.swift`, `CoachMarkdownTheme.swift` | circular Coach cover | `AICoachEngine` | send/stop/retry/tool approval/open card | 06 | P0 Protected | Critical |
| 43 | Coach tool-call/chart status | `CoachView.swift`, `Strand/AI/CoachChart.swift` | transcript inline/sheet | Coach engine/tool catalog | inspect chart/tool result | 06, 18 | P1 Protected | Critical |
| 44 | Coach conversation history | `CoachHistoryView.swift` | Coach sheet | transcript store | open/delete conversation | 06 | P1 Protected | High |
| 45 | Coach identity/persona | `CoachIdentityEditor.swift`, `CoachInfoView.swift`, `CoachAvatarView.swift` | Coach settings | Coach identity settings | edit/select/reset | 06 | P1 Protected | High |
| 46 | AI provider/model configuration and errors | `CoachSettingsView.swift`, `ModelSearchSheet.swift`, `Strand/AI/Providers/*` | More / Coach settings | provider settings | choose/test/save key/model | grouped privacy-first cards | P0 Protected | Critical |
| 47 | Semantic Memory settings | `CoachSettingsView.swift`, `CoachSemanticMemory.swift` | Coach settings | semantic-memory coordinator | enable/rebuild/clear | explicit status rows | P1 Protected | Critical |
| 48 | Goal hub, onboarding and editor | `CoachGoalJourneyView.swift`, `CoachGoalOnboardingFlow.swift`, `CoachGoalView.swift` | Progress tab | goal store | create/edit/pause/archive | compact progress cards | P0 Protected | Critical |
| 49 | Plan Book | `CoachPlanView.swift`, `CoachPlanStore.swift` | Progress tab / sheet | plan store | open/schedule/skip/complete | plan cards | P0 Protected | Critical |
| 50 | Pending plan proposal, Modify/Accept/Decline/Swap | `PlanTodayCard.swift`, `CoachPlanView.swift` | Today / Plan | `AICoachEngine`, plan store | proposal lifecycle | stacked proposal card | P0 Protected | Critical |
| 51 | Journey milestones, adherence, skip reasons | `JourneyView.swift`, `JourneyMilestones.swift` | Progress tab | goal/plan/journey stores | inspect/edit goal/open plan | compact progress timeline | P0 Protected | Critical |
| 52 | Updates inbox and detail | `UpdatesInboxView.swift`, `UpdateStore.swift` | Today/Progress | update store | open/mark read | grouped cards | P1 Protected | High |
| 53 | More hub | `StrandiOS/App/RootTabView.swift` | More tab | root shell + section prefs | open/collapse routes | **00**, grouped cards | P0 | High |
| 54 | Devices, connection states and probe sheets | `DevicesView.swift` | More | `LiveState`, device registry | scan/connect/disconnect/pair/probe | grouped status cards | P1 Protected | Critical |
| 55 | Apple Health setup/import/denied state | `AppleHealthView.swift` | More/Data Sources | Health import/store | authorize/import/export | explicit permission state | P1 Protected | Critical |
| 56 | Apple Watch setup/about | `AppleWatchSetupView.swift`, `AppleWatchAboutView.swift` | Settings sheets | watch bridge | configure/dismiss | grouped cards | P2 Protected | High |
| 57 | Xiaomi/Mi Band source | `XiaomiBandView.swift` | More/Data Sources | importer | import/configure | grouped source cards | P2 Protected | High |
| 58 | Data Sources and provenance | `DataSourcesView.swift` | More / Today route | repository/source catalog | inspect/open source | metric rows | P0 Protected | Critical |
| 59 | Import/export document flows | `DataSourcesView.swift`, `DataBackup.swift`, `DocumentPicker.swift`, `FileExport.swift` | sheets/system pickers | existing import/export services | choose/share/import/confirm | explicit state sheets | P0 Protected | Critical |
| 60 | Backup & Sync | `BackupSyncView.swift`, `BackupSync.swift` | More | backup coordinator | choose folder/back up/restore | grouped status cards | P0 Protected | Critical |
| 61 | Unified Backup V2 preview, migration warning, rollback/error | `UnifiedBackupV2.swift`, backup UI | Backup sheets | backup staging/coordinator | validate/preview/restore/cancel | explicit confirmation cards | P0 Protected | Critical |
| 62 | Privacy presets and master consent | `CoachSettingsView.swift`, `ToolConsent.swift` | Settings/Coach | consent store | select preset/toggle master | explicit status rows | P0 Protected | Critical |
| 63 | Individual, Strength and pain-sensitive consent | `CoachSettingsView.swift`, `CoachStrengthTools.swift` | privacy detail | consent store | toggle/confirm | explicit status rows | P0 Protected | Critical |
| 64 | Settings root and appearance | `SettingsView.swift` | More | `@AppStorage` + environment | toggle/open subpages | grouped cards | P0 Protected | High |
| 65 | Notifications | `NotificationSettingsView.swift` | Settings | notification store | permission/toggles | grouped status rows | P2 Protected | High |
| 66 | Alarms | `SmartAlarmView.swift` | More | alarm state + BLE command layer | set/arm/disarm | focused form | P2 Protected | Critical |
| 67 | Automations | `AutomationsView.swift` | More | automation settings | enable/configure | grouped rows | P2 Protected | High |
| 68 | Storage | `StorageView.swift` | Settings | repository/store paths | inspect/prune | grouped status cards | P2 Protected | Critical |
| 69 | Profile/avatar and units | `ProfileAvatarView.swift`, `Profile.swift`, Settings | Today/Settings | profile store | edit profile/units | compact form | P1 Protected | High |
| 70 | Test Centre, report review and diagnostics | `TestCentreView.swift`, `TestReportFlow.swift`, `SettingsView.swift` | More/Settings sheet | diagnostics/test stores | capture/export/review | explicit warning cards | P2 Protected | Critical |
| 71 | Lab Book, marker detail/editor, image/PDF review and disclaimer | `LabBookView.swift`, `MarkerEditorView.swift`, `LabReportReviewView.swift` | More | repository/lab import | import/edit/delete/confirm disclaimer | metric cards | P1 Protected | Critical |
| 72 | Fused record | `FusedRecordView.swift`, `V5PillarHosts.swift` | More/pillar route | repository | inspect timeline | 18 | P2 Protected | High |
| 73 | Rhythm | `RhythmView.swift`, `V5PillarHosts.swift` | More/pillar route | repository | select range/inspect | 18 | P2 Protected | High |
| 74 | Scoring guide and How NOOP Works | `ScoringGuideView.swift`, `HowNoopWorksView.swift` | Today/Settings sheets | static localized content | navigate/dismiss | original NOOP explanatory cards | P2 | Low |
| 75 | About, Terms, Privacy, license/attribution links | `SettingsView.swift`, `Terms.swift`, resource documents | Settings | app metadata | open links/docs | grouped legal rows | P1 Protected | Critical |
| 76 | Empty, loading, permission-denied, provider/network error and destructive confirmations | shared across all views; `ScreenScaffold.swift`, system alerts | inline/sheets/alerts | owning view | retry/settings/cancel/confirm | shared semantic state cards | P0 | Critical |

## Count and completion rule

- Inventoried screen families: **76**
- P0 families requiring direct redesign/screenshot or state coverage: **34**
- P1 families requiring direct redesign: **26**
- P2/supporting families covered by shared components: **16**

The branch may only claim a complete redesign when every row above is marked complete
in `UI_ACCEPTANCE_CHECKLIST.md`, no existing route becomes unreachable, and no static
mock replaces a real state-owning view.

## Implementation status

- **76/76 families audited.**
- **76/76 inherit the shared performance palette, flat card surface, typography,
  page background, spacing and state components** through `StrandDesign`,
  `NoopCard`/`StrandCard`, and `ScreenScaffold`.
- **Directly adapted in this branch:** root dock and Coach action, Today root
  selection, Health hub, Progress hub, More routing, Coach chat background,
  Strength picker, Strength cards, and anatomical Body Map.
- **Existing state-owning views retained:** all 76 families. No screenshot,
  duplicate Today, duplicate Coach, mock repository, or alternate calculation
  owner replaces a production view.
- **Pending evidence:** simulator compile/tests, Thai seeded screenshots, full
  macOS/iOS/Android CI, and unsigned device IPA. These remain unchecked in the
  acceptance checklist until the corresponding GitHub runs finish.
- **Known source limitation:** the stable integration base stores soreness and
  pain separately and exposes them to consent-aware Coach tools, but does not
  contain a standalone user-facing soreness/pain editor view. This UI-only branch
  does not invent a second persistence owner to manufacture one.
