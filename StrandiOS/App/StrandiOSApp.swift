#if os(iOS)
import SwiftUI
import StrandDesign
import UserNotifications
import UIKit
import WhoopStore

/// iOS entry point. Unlike the macOS app (which adds a `MenuBarExtra` scene), iOS uses a single
/// `WindowGroup`; the glanceable menu-bar role is filled by the Home/Lock-Screen widget instead.
///
/// The iOS shell is `RootTabView` (a `TabView`), NOT the macOS `ContentView`. `ContentView` embeds
/// `RootView()` — the `NavigationSplitView` sidebar shell — and `RootView.swift` is excluded from the
/// iOS target in `project.yml` (the sidebar has no iPhone analogue), so `ContentView` cannot compile
/// on iOS. The first-run onboarding/pairing wizard, the Terms acknowledgment gate, and the post-update
/// "What's New" sheet that `ContentView` layers on are reproduced here as `iOSRootView`, wrapped around
/// `RootTabView` so the iOS app keeps the same gating without depending on the macOS-only shell.
@main
struct StrandiOSApp: App {
    @StateObject private var model: AppModel
    @StateObject private var health: HealthKitBridge
    /// The phone→watch link. Built + activated here so the watch app actually receives snapshots on a
    /// real device; without an owner that pushes it, the watch only ever shows placeholder data.
    @StateObject private var watch = WatchSessionBridge()
    /// Shared cross-screen navigation hook (e.g. Live → Devices). The iOS shell (`RootTabView`)
    /// observes it and presents the Devices manager.
    @StateObject private var router = NavRouter()
    @State private var liveActivity = LiveActivityController()
    @Environment(\.scenePhase) private var scenePhase
    /// Appearance preference (System/Light/Dark). Default follows the OS; the Settings picker writes it.
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    /// Chart data-colour style (Titanium / Classic throwback). Re-colours gauges + charts.
    @AppStorage(ChartStyle.storageKey) private var chartStyleRaw = ChartStyle.health.rawValue

    init() {
        // One-time migration off the retired card/button/both Coach-entry picker onto the three
        // independent entry toggles (banner/header-icon/floating-button). No-op after the first launch
        // that has them. Must run before any Today/RootTabView reads its @AppStorage default.
        CoachEntryPrefs.migrateIfNeeded()
        #if DEBUG
        // DEBUG-only promo-screenshot harness: when launched with `--demo-hour <Int>`, pin Today to that
        // hour's day-cycle scene + a per-hour stat frame. No-op (active stays nil) when the arg is absent.
        // MUST live here, not in StrandApp.swift — that is the macOS @main and is excluded from the iOS
        // target, so the hook there never runs on iOS.
        DemoDayHarness.applyLaunchArgsIfNeeded()
        #endif
        // Debug-only canary: trips if the App Group entitlement is missing on this target before any
        // silent no-op (PendingIntents, WidgetSnapshot.publish, Live Activity) can mask the issue as
        // "the widget doesn't show anything yet." No-op in Release.
        WidgetSnapshot.assertGroupProvisioned()
        // #510: register the scheduled debug auto-export's BGTask handler BEFORE launch finishes — iOS
        // only delivers a background task whose identifier was registered at launch AND listed in the
        // target's BGTaskSchedulerPermittedIdentifiers (project.yml). Without this the overnight drop
        // never fires; the macOS timer, foreground catch-up, and "Run now" already work without it.
        ScheduledDebugExport.register()
        SemanticMemoryBackgroundTask.register()
        // Foreground presentation: without a delegate, iOS suppresses a notification's banner while the app
        // is open, so a user testing the wind-down reminder with NOOP foregrounded sees nothing. Register
        // before the first scene so any early-fired notification is presented.
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        // Register the check-in's action buttons before any notification can arrive — a category a
        // notification names but nobody registered simply shows no buttons, silently.
        CoachCheckIn.registerCategory()
        let model = AppModel()
        SemanticMemoryBackgroundTask.attach(coach: model.coach)
        _model = StateObject(wrappedValue: model)
        _health = StateObject(wrappedValue: HealthKitBridge(
            repo: model.repo,
            appleDeviceId: model.appleDeviceId,
            noopDeviceId: model.deviceId
        ))
    }

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(model)
                .environmentObject(model.ble)   // #334: Today pull-to-sync reads BLEManager (no HR churn)
                .environmentObject(model.live)
                .environmentObject(model.repo)
                .environmentObject(model.profile)
                .environmentObject(model.behavior)
                .environmentObject(model.intelligence)
                .environmentObject(model.coach)
                .environmentObject(health)
                .environmentObject(router)
                .environmentObject(UpdateStore.shared)
                // v5 L3: the shared stress check-in nudge surface, so the Breathe screen's passive
                // card observes the SAME instance the central detector (AppModel.evaluateStress) posts to.
                .environment(\.stressNudgeCenter, model.stressNudgeCenter)
                .preferredColorScheme(AppearanceMode.resolve(appearanceRaw).colorScheme)
                .chartStyle(chartStyleRaw)
                // Dynamic Type now scales the prose/label roles (StrandFont). Cap the upper end so the
                // fixed-geometry tiles/gauges stay legible at the largest accessibility sizes rather than
                // clipping; the common Larger-Text range still scales fully.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                // "Health always wins" (user decision): every successful sync overwrites the profile
                // weight with the freshest Health reading, not just once when unset.
                .onReceive(health.$latestImportedWeightKg) { kg in
                    if let kg { model.profile.applyHealthWeight(kg: kg) }
                }
                // The reverse direction: a genuine user edit to the profile weight writes back to Health.
                // Ping-pong guard — skip when the new value is (near-)identical to what Health itself last
                // reported, since that means this change is the "Health always wins" overwrite above
                // echoing back through this same publisher, not a fresh user edit (a real edit almost
                // never lands within 0.05 kg of the last Health-imported value by coincidence).
                .onReceive(model.profile.$weightKg.dropFirst()) { kg in
                    guard abs(kg - (health.latestImportedWeightKg ?? -.greatestFiniteMagnitude)) > 0.05 else { return }
                    Task { try? await health.writeWeight(kg: kg) }
                }
                .onReceive(model.live.$heartRate) { _ in
                    // #911: anchor the Live Activity on the SAME shared `Repository.widgetAnchor` the
                    // Home/Lock widget and the watch snapshot use, so this fourth surface can't drift to a
                    // different day at the rollover (it previously read `days.last(where: recovery != nil)`,
                    // which kept pointing at yesterday's scored row after Today had moved on).
                    let day = Repository.widgetAnchor(days: model.repo.days)
                    liveActivity.update(
                        bpm: model.live.connected ? (model.bpm ?? model.live.heartRate) : nil,
                        recovery: day?.recovery.map { Int($0.rounded()) },
                        connected: model.live.connected,
                        effort: day?.strain.map { Int($0.rounded()) }
                    )
                }
                // End the Live Activity the moment the link drops, even if no further HR tick arrives.
                .onReceive(model.live.$connected) { isConnected in
                    // #911: same shared anchor as the heartRate site above, so the Live Activity, the
                    // widget, the watch and Today never disagree about which day they describe.
                    let day = Repository.widgetAnchor(days: model.repo.days)
                    liveActivity.update(
                        bpm: isConnected ? (model.bpm ?? model.live.heartRate) : nil,
                        recovery: day?.recovery.map { Int($0.rounded()) },
                        connected: isConnected,
                        effort: day?.strain.map { Int($0.rounded()) }
                    )
                }
                // #911/#759: republish the Home/Lock-Screen widget whenever the dashboard caches actually
                // change mid-session. The only other publish site is the scenePhase .active handler, so
                // during a long foreground session the widget froze at the last-foreground snapshot while
                // Today and the Live Activity kept updating. `refreshSeq` is diff-guarded (Repository.refresh
                // skips the bump when the merged caches are byte-identical) and refresh() assigns every cache
                // BEFORE bumping the seq, so this publish always reads fresh data. `dropFirst()` skips the
                // publisher's attach-time replay of the current value; the .active publish already covers
                // launch. BUDGET: this app runs with bluetooth-central, so the process is NOT suspended in
                // the background, and the 15-minute analyze tick + backfill-completion refreshes bump the
                // seq back there too, where WidgetKit reloads DO count against the daily budget. Hence the
                // foreground gate: publish only while .active (foreground-initiated reloads are budget
                // exempt); a background bump is covered by the widget's own 15-minute timeline policy and
                // by the .active republish on return.
                .onReceive(model.repo.$refreshSeq.dropFirst()) { _ in
                    guard scenePhase == .active else { return }
                    Task { await WidgetSnapshot.publish(from: model) }
                    // The watch rides the same active-only hook because the bridge now SELF-THROTTLES
                    // (30-minute spacing + headline-change dedup, both must pass, see WatchSessionBridge),
                    // so a refresh storm can't burn the ~50/day complication transfer budget.
                    Task { await watch.pushLatest(from: model) }
                }
                // #114: strap battery % and connection are LIVE (model.live), not repo-cache, so they never
                // bump refreshSeq — the widget's battery would otherwise never move while the app is open
                // (the "battery not updating" report). Republish on those too, foreground-gated. Both are
                // low-frequency (battery ~every 8 min; connection flips are rare), so no throttle is needed
                // and foreground-initiated reloads are budget-exempt. dropFirst() skips the attach replay.
                .onReceive(model.live.$batteryPct.dropFirst()) { _ in
                    guard scenePhase == .active else { return }
                    Task { await WidgetSnapshot.publish(from: model) }
                }
                .onReceive(model.live.$connected.dropFirst()) { _ in
                    guard scenePhase == .active else { return }
                    Task { await WidgetSnapshot.publish(from: model) }
                }
                // #114 (follow-up): `WidgetSnapshot.bpm` reads `model.bpm` (WidgetPublish.swift), the
                // smoothed live HR — same LIVE-not-repo-cache category as battery/connected above, so it
                // has the same gap: nothing bumped `refreshSeq` while a heart-rate stream was live, so the
                // widget's HR froze at the last foreground snapshot for the rest of the session. UNLIKE
                // battery/connection, HR is HIGH-frequency (the smoothed median moves every few seconds
                // under activity), so — unlike the ungated hooks above — this one is throttled through
                // `HRPublishThrottle` (60 s, mirroring Android's PushGate HR cadence) so it can't re-run
                // publish's `exploreSeries` read + `reloadAllTimelines()` on every tick.
                .onReceive(model.$bpm.dropFirst()) { _ in
                    guard scenePhase == .active else { return }
                    guard WidgetSnapshot.HRPublishThrottle.admit() else { return }
                    Task { await WidgetSnapshot.publish(from: model) }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didReceiveMemoryWarningNotification
                )) { _ in
                    Task { await model.coach.unloadSemanticMemory() }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: ProcessInfo.thermalStateDidChangeNotification
                )) { _ in
                    let state = ProcessInfo.processInfo.thermalState
                    if state == .serious || state == .critical {
                        Task { await model.coach.unloadSemanticMemory() }
                    }
                }
                // #581: the `noop://import-health` deep link the iOS Shortcut opens after building the
                // HealthKit-free payload. Filter on the host so other future schemes don't trip the
                // importer; macOS never registers the scheme so this stays iOS-only.
                .onOpenURL { url in
                    if url.host == "import-health" {
                        model.handleHealthImportURL(url)
                    }
                }
                .alert("Import Apple Health data?", isPresented: Binding(
                    get: { model.pendingShortcutHealthImport != nil },
                    set: { showing in
                        if !showing { model.cancelPendingHealthImport() }
                    }
                )) {
                    Button("Import") { model.confirmPendingHealthImport() }
                    Button("Cancel", role: .cancel) { model.cancelPendingHealthImport() }
                } message: {
                    if let pending = model.pendingShortcutHealthImport {
                        Text("A Shortcut wants to add \(pending.daysCount) days and \(pending.workoutsCount) workouts to the Apple Health import source.")
                    } else {
                        Text("A Shortcut wants to add data to the Apple Health import source.")
                    }
                }
                // Bring the watch link up once at launch (WCSession ignores a redundant activate), then
                // push the first snapshot so a watch that's already on-wrist gets current scores without
                // waiting for the next foreground. activate() is idempotent + a no-op where WC isn't
                // supported, so this is safe on every device/simulator combination.
                .task {
                    watch.activate()
                    await watch.pushLatest(from: model)
                }
        }
        // HealthKit authorization is intentionally NOT requested on launch. The system permission
        // dialog without prior in-app rationale violates Apple HIG / App Review guidance — the user
        // sees the prompt before any context. It is requested from an explicit user action instead:
        // the "Enable Apple Health" affordance in AppleHealthView (More → Data → Apple Health).
        // Below, `refreshAuthIfPreviouslyGranted` re-primes `auth` for users who already granted
        // access (it only reads write/share status, never prompts) so background syncs resume; and
        // HealthKitBridge.sync guards on `auth == .authorized`, so the scenePhase trigger stays a
        // safe no-op until the user opts in.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.drainPendingIntents()
                // Re-arm the strap's smart alarm on foreground: the firmware alarm is a single instant
                // and iOS can't re-arm it while suspended, so it would otherwise fire once and stop.
                model.applySmartAlarm()
                Task {
                    await CurrentMuscleResidualService.shared.invalidateAll()
                }
                // #267: pull a reasonably fresh sync on open rather than waiting for the 900s periodic
                // timer or an incidental reconnect. Floored at 90s and never clock/empty-streak-suppressed
                // (BackfillPolicy.shouldRun's .foreground case), so this is a safe no-op on rapid re-opens.
                model.ble.requestSync(.foreground)
                // Re-learn the wake-time-tracking check-in from fresh sleep on foreground. No-op unless
                // the check-in is on and set to .afterWake; keeps the repeating trigger in step with the
                // user's actual wake time rather than a clock time that drifts out of sync.
                Task { await CoachCheckIn.refreshDynamicScheduleIfNeeded(repo: model.repo) }
                if CoachSemanticMemory.shared.foregroundCatchUpIsDue() {
                    CoachSemanticMemory.shared.markForegroundCatchUp()
                    Task { await model.coach.performSemanticMemoryMaintenance(limit: 64) }
                }
                Task {
                    health.refreshAuthIfPreviouslyGranted()
                    await health.sync()
                    await WidgetSnapshot.publish(from: model)
                    // Push the wrist on the SAME refresh as the Home-screen widget so the watch, the
                    // widget and Today never disagree about which day they describe. Without this the
                    // watch only ever holds placeholder data on a real device.
                    await watch.pushLatest(from: model)
                }
            } else if phase == .background {
                SemanticMemoryBackgroundTask.schedule()
                Task { await model.coach.unloadSemanticMemory() }
                // #114: capture the LAST in-app live state on the way out so the Home widget matches what
                // the user just saw — its battery/HR/score otherwise lag to the last FOREGROUND refreshSeq
                // bump. One reload per app-exit is low-frequency and well within WidgetKit's daily budget.
                Task { await WidgetSnapshot.publish(from: model) }
                // #155: refresh the Documents/noop_sync.txt drop file the user's Siri Shortcut logs
                // into Apple Health. Gated inside writeIfEnabled on the opt-in default (OFF) — a
                // no-op until the user turns on Shortcuts Export.
                Task { await ShortcutHealthExport.writeIfEnabled(repo: model.repo) }
            }
        }
    }
}

/// iOS root — the `RootTabView` shell with the first-run onboarding/pairing wizard overlaid until
/// complete, the Terms acknowledgment gate over everything until the current version is accepted, and
/// a "What's New" changelog sheet shown automatically after an update.
///
/// This mirrors the macOS `ContentView` (same `@AppStorage` keys, same gate ordering) but swaps the
/// excluded `RootView()` sidebar for `RootTabView()`. The shared `OnboardingWizard`, `TermsGateView`,
/// `WhatsNewView`, `AppChangelog`, and `Terms` symbols all compile into the iOS target unchanged.
private struct iOSRootView: View {
    @AppStorage("noop.onboarded") private var onboarded = false
    @AppStorage("noop.lastSeenChangelogVersion") private var lastSeenChangelog = ""
    @AppStorage("noop.acceptedTermsVersion") private var acceptedTerms = ""
    @State private var showWhatsNew = false

    var body: some View {
        #if DEBUG
        // DEBUG-only: `--demo-screen <name>` renders one screen full-bleed (gates bypassed) so a
        // seeded simulator build can be screenshotted deterministically for verification + marketing.
        // No-op in Release (whole branch is #if DEBUG) and when the arg is absent.
        if let demo = DemoScreens.requested {
            // Inherit the app appearance (set via the Theme picker, or `-theme.appearance light|dark`
            // in the launch arguments) so demo/marketing shots can be taken in either scheme.
            return AnyView(
                NavigationStack {
                    demo
                        .background(StrandPalette.surfaceBase.ignoresSafeArea())
                        .navigationBarTitleDisplayMode(.inline)
                }
            )
        }
        #endif
        return AnyView(shell)
    }

    private var shell: some View {
        ZStack {
            RootTabView()
            if !onboarded && !demoBypass {
                OnboardingWizard(onFinished: {
                    onboarded = true
                    // A brand-new user just saw the expectations in onboarding — don't also pop the
                    // changelog at them; mark them current.
                    lastSeenChangelog = AppChangelog.currentVersion
                })
                .transition(.opacity)
                .zIndex(1)
            }
            // Terms acknowledgment gate — over EVERYTHING (before onboarding/pairing/Bluetooth) until
            // the current terms version is accepted; re-appears if the terms materially change.
            if acceptedTerms != Terms.currentVersion && !demoBypass {
                TermsGateView(onAccept: { acceptedTerms = Terms.currentVersion })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarded)
        .animation(.easeInOut(duration: 0.35), value: acceptedTerms)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(onClose: {
                lastSeenChangelog = AppChangelog.currentVersion
                showWhatsNew = false
            })
        }
        // The Terms gate must stay "over everything" — don't pop What's New on top of it after a
        // combined terms+version update. Gate on terms being current, and re-check when they're
        // accepted (onAppear already fired before acceptance), so What's New shows right after.
        .onAppear {
            showWhatsNewIfDue()
            // Seed the current What's New into the Updates inbox (idempotent per version) so the bell
            // collects it even if the user dismisses the auto sheet.
            UpdateStore.shared.seedWhatsNewIfNeeded()
        }
        .onChange(of: acceptedTerms) { _, _ in showWhatsNewIfDue() }
    }

    /// DEBUG: launched with --demo-seed, skip the first-run gates (onboarding / terms / What's New) so the
    /// FULL shell with the tab bar renders populated for verification + screenshots. No-op in Release.
    private var demoBypass: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-seed")
        #else
        return false
        #endif
    }

    private func showWhatsNewIfDue() {
        if demoBypass { return }
        // Existing users who updated: their last-seen version is behind the current one.
        if onboarded && acceptedTerms == Terms.currentVersion
            && lastSeenChangelog != AppChangelog.currentVersion {
            showWhatsNew = true
        }
    }
}

#if DEBUG
/// DEBUG-only screenshot harness. Maps `--demo-screen <name>` to a single screen so a seeded
/// simulator build can be captured deterministically (verification + marketing). Stripped from Release.
enum DemoScreens {
    /// The screen named by `--demo-screen <name>`, or nil if the arg is absent/unknown.
    static var requested: AnyView? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo-screen"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "root": return AnyView(RootTabView())
        case "today":    return AnyView(TodayView())
        // The DEFAULT iOS Today (`noop.liquidTodayEnabled` ships true), so it needs its own entry — plain
        // "today" renders the CLASSIC screen, which is exactly the screen whose behaviour Liquid was found
        // to have diverged from. Without this, the default Today was the one screen the harness could not
        // capture.
        case "liquidtoday": return AnyView(LiquidTodayView())
        case "pr3today": return AnyView(LiquidTodayView())
        case "pr3scrolled": return AnyView(LiquidTodayView())
        case "pr3charge": return AnyView(PR3ScoreDetailDemoHost(metric: .charge))
        case "pr3rest": return AnyView(PR3ScoreDetailDemoHost(metric: .rest))
        case "pr3effort": return AnyView(PR3ScoreDetailDemoHost(metric: .effort))
        case "trends":   return AnyView(TrendsView())
        case "sleep":    return AnyView(SleepView())
        case "live":     return AnyView(LiveView())
        case "stress":   return AnyView(StressView())
        case "workouts": return AnyView(WorkoutsView())
        case "health":   return AnyView(HealthView())
        case "insights": return AnyView(InsightsView())
        case "explore":  return AnyView(MetricExplorerView())
        case "compare":  return AnyView(CompareView())
        case "settings": return AnyView(SettingsView())
        case "strength": return AnyView(StrengthHistoryView())
        case "strengthlogger": return AnyView(StrengthLoggerDemoHost())
        case "strengthpicker": return AnyView(StrengthPickerDemoHost())
        case "strengthtemplates": return AnyView(StrengthTemplatesDemoHost())
        case "strengthdetail": return AnyView(StrengthCompletedDemoHost())
        case "bodymap": return AnyView(BodyMapDemoHost(side: .front))
        case "bodymapback": return AnyView(BodyMapDemoHost(side: .back))
        case "muscledetail": return AnyView(MuscleLoadDetailDemoHost())
        case "soreness": return AnyView(SorenessCheckInSheet())
        case "pain": return AnyView(SorenessCheckInSheet(initialPainPresent: true))
        case "coach": return AnyView(CoachSeededDemoHost(mode: .conversation))
        case "coachtool": return AnyView(CoachSeededDemoHost(mode: .tool))
        case "coachproposal": return AnyView(CoachSeededDemoHost(mode: .proposal))
        case "coachhistory": return AnyView(CoachSeededDemoHost(mode: .history))
        case "coachsettings": return AnyView(CoachSettingsView())
        case "semanticmemory":
            return AnyView(CoachSettingsView(initialPage: .memory))
        case "providersettings":
            return AnyView(CoachSettingsView(initialPage: .connection))
        case "privacy":
            return AnyView(CoachSettingsView(initialPage: .privacy))
        case "consent":
            return AnyView(CoachSettingsView(initialPage: .dataAccess))
        case "goalplan": return AnyView(CoachGoalJourneyScreen())
        case "goaleditor": return AnyView(CoachGoalEditorView(isOnboarding: false))
        case "planbook": return AnyView(PlanBookDemoHost())
        case "journey": return AnyView(JourneyDemoHost())
        case "updates": return AnyView(UpdatesDemoHost())
        case "workoutdetail": return AnyView(WorkoutDetailDemoHost())
        case "workoutzones": return AnyView(WorkoutDetailDemoHost())
        case "detectedstrength": return AnyView(DetectedStrengthDemoHost())
        case "datasources": return AnyView(DataSourcesView())
        case "backup": return AnyView(BackupSyncView())
        case "restorepreview": return AnyView(PR3ReviewStateDemoHost(kind: .restore))
        case "importvalidation": return AnyView(PR3ReviewStateDemoHost(kind: .importing))
        case "exportsuccess": return AnyView(PR3ReviewStateDemoHost(kind: .exported))
        case "loadingstate": return AnyView(PR3ReviewStateDemoHost(kind: .loading))
        case "emptystate": return AnyView(PR3ReviewStateDemoHost(kind: .empty))
        case "errorstate": return AnyView(PR3ReviewStateDemoHost(kind: .error))
        case "destructive": return AnyView(PR3DestructiveConfirmationDemoHost())
        case "chargebreakdown": return AnyView(ChargeBreakdownDemoHost())
        case "devices":  return AnyView(DevicesView())
        case "devicescatalog": return AnyView(DeviceCardCatalog())
        case "fitnessage": return AnyView(FitnessAgeDemoScreen())
        case "vitality": return AnyView(VitalityDemoScreen())
        case "addwizard": return AnyView(AddWizardDemoHost())
        // Oura onboarding: the Add-device wizard deep-linked straight to the Oura factory-reset-and-adopt
        // prep step (the Beta banner + get/lose card + the red irreversible-consent gate), screenshot-able
        // WITHOUT a ring.
        case "ouraonboarding": return AnyView(OuraOnboardingDemoHost())
        // Oura device card: the locally-adopted Oura ring card (Beta chip + per-gen honest capability copy
        // + battery + local-state note), rendered with mock data, no ring required.
        case "ouradevice": return AnyView(OuraDeviceDemoScreen())
        // #221: a WHOOP 5/MG whose encrypted bond was refused (#78) — the "Connected · not paired" pill
        // + self-service pairing guidance, screenshot-able WITHOUT reproducing the bond refusal on real
        // hardware.
        case "bondrefused": return AnyView(BondRefusedDemoScreen())
        default:         return nil
        }
    }
}
#endif
#endif

#if DEBUG
/// DEBUG-only host so `--demo-screen addwizard` can render the multi-step Add-a-device wizard.
/// A SwiftUI View body is main-actor, so it can pull the injected LiveState and hand it to the
/// wizard's `init(live:)` (the nonisolated DemoScreens switch can't construct a LiveState itself).
private struct AddWizardDemoHost: View {
    @EnvironmentObject var live: LiveState
    var body: some View { AddDeviceWizard(live: live, onClose: {}) }
}

private struct StrengthLoggerDemoHost: View {
    @EnvironmentObject private var repository: Repository
    @StateObject private var viewModel = StrengthTrainingViewModel()

    var body: some View {
        ScrollView {
            StrengthWorkoutLogger(viewModel: viewModel)
                .padding()
        }
        .task {
            await viewModel.load(
                repository: repository,
                deviceId: repository.deviceId,
                startedAt: Date().addingTimeInterval(-38 * 60),
                bodyweightKg: ProfileStore().weightKg)
            populateStrengthReview(viewModel)
        }
    }
}

private struct BodyMapDemoHost: View {
    let side: AnatomicalMuscleMap.Side

    var body: some View {
        ScrollView {
            MuscleBodyMapCard(initialSide: side)
                .padding()
        }
    }
}

private struct StrengthPickerDemoHost: View {
    @EnvironmentObject private var repository: Repository
    @StateObject private var viewModel = StrengthTrainingViewModel()

    var body: some View {
        ExercisePicker(viewModel: viewModel)
            .task {
                await loadStrengthReview(viewModel, repository: repository)
            }
    }
}

private struct StrengthTemplatesDemoHost: View {
    @EnvironmentObject private var repository: Repository
    @StateObject private var viewModel = StrengthTrainingViewModel()

    var body: some View {
        StrengthTemplateSheet(viewModel: viewModel)
            .task {
                await loadStrengthReview(viewModel, repository: repository)
                viewModel.templateName = String(localized: "Full body")
            }
    }
}

private struct StrengthCompletedDemoHost: View {
    @EnvironmentObject private var repository: Repository
    @StateObject private var viewModel = StrengthTrainingViewModel()
    @State private var completedSessionID: String?

    var body: some View {
        Group {
            if let completedSessionID {
                StrengthCompletedEditor(sessionId: completedSessionID, onDone: {})
            } else {
                PR3TruthfulState(
                    .loading,
                    title: "Loading strength workout…",
                    message: "Loading offline exercise library…"
                )
                .padding()
            }
        }
        .task {
            await loadStrengthReview(viewModel, repository: repository)
            guard let id = viewModel.session?.id else { return }
            _ = await viewModel.finish(cardiovascularEffort: 58)
            completedSessionID = id
        }
    }
}

@MainActor
private func loadStrengthReview(
    _ viewModel: StrengthTrainingViewModel,
    repository: Repository
) async {
    await viewModel.load(
        repository: repository,
        deviceId: repository.deviceId,
        startedAt: Date().addingTimeInterval(-38 * 60),
        bodyweightKg: ProfileStore().weightKg
    )
    populateStrengthReview(viewModel)
}

@MainActor
private func populateStrengthReview(_ viewModel: StrengthTrainingViewModel) {
    guard viewModel.session?.exercises.isEmpty == true else { return }
    for exercise in viewModel.orderedSearchResults.prefix(2) {
        viewModel.addExercise(exercise)
    }
    guard let session = viewModel.session else { return }
    for exercise in session.exercises {
        guard let first = exercise.sets.first else { continue }
        viewModel.updateSet(exerciseId: exercise.id, setId: first.id) {
            $0.weightKg = exercise.orderIndex == 0 ? 60 : 22.5
            $0.reps = exercise.orderIndex == 0 ? 8 : 10
            $0.rpe = 7.5
            $0.rir = 2
            $0.completed = true
        }
        viewModel.addSet(to: exercise.id)
    }
    viewModel.setSessionRPE(7.5)
}

private struct CoachSeededDemoHost: View {
    enum Mode: Equatable { case conversation, tool, proposal, history }
    @EnvironmentObject private var coach: AICoachEngine
    let mode: Mode

    var body: some View {
        Group {
            if mode == .history {
                CoachHistoryView()
            } else {
                CoachView()
            }
        }
        .task {
            coach.setKey("noop-visual-review-only")
            if coach.messages.isEmpty {
                coach.messages = [
                    ChatMessage(
                        role: .user,
                        text: "วันนี้ควรฝึกแบบไหน เมื่อคืนนี้ฉันนอนน้อยกว่าปกติ"
                    ),
                    ChatMessage(
                        role: .assistant,
                        text: "วันนี้เน้นการฝึกเบาถึงปานกลางประมาณ 45 นาทีได้ครับ "
                            + "ค่า Charge และการนอนบอกว่าร่างกายยังต้องการเวลาฟื้นตัว "
                            + "จึงควรหลีกเลี่ยงเซตหนักจนหมดแรง",
                        toolsUsed: mode == .tool
                            ? [CoachTool.readiness.rawValue, CoachTool.sleepDetail.rawValue]
                            : []
                    ),
                ]
            }
            if mode == .proposal {
                seedPlanProposal()
            }
        }
    }
}

private struct PlanBookDemoHost: View {
    var body: some View {
        CoachPlanView()
            .task { seedPlanProposal() }
    }
}

@MainActor
private func seedPlanProposal() {
    guard CoachPlanStore.shared.pending.isEmpty else { return }
    _ = CoachPlanStore.shared.propose(PlanProposal(
        day: Repository.localDayKey(Date()),
        time: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
        sport: "Strength Training",
        intent: .moderate,
        targetEffort: 55,
        rationale: "รักษาความสม่ำเสมอโดยไม่เพิ่มภาระมากเกินไปในวันที่พักผ่อนน้อย",
        strength: StrengthPlanMetadata(
            trainingIntent: .full,
            targetRPE: 6.5,
            musclesToAvoid: ["quadriceps"]
        )
    ))
}

private struct JourneyDemoHost: View {
    @EnvironmentObject private var coach: AICoachEngine
    @State private var goalID: UUID?

    var body: some View {
        Group {
            if let goalID {
                JourneyView(goalId: goalID)
                    .environmentObject(coach)
            } else {
                ProgressView()
            }
        }
        .task {
            if let existing = CoachGoalStore.shared.activeGoals.first {
                goalID = existing.id
                return
            }
            let goal = CoachGoal(
                kind: .consistency,
                title: "ออกกำลังกายให้สม่ำเสมอ",
                baseline: 2,
                target: 4,
                targetDate: Calendar.current.date(byAdding: .day, value: 60, to: Date()),
                motivationTags: [.buildRoutine, .moreEnergy]
            )
            CoachGoalStore.shared.commit(goal)
            goalID = goal.id
        }
    }
}

private struct UpdatesDemoHost: View {
    @EnvironmentObject private var updateStore: UpdateStore
    @EnvironmentObject private var router: NavRouter

    var body: some View {
        UpdatesInboxView(onClose: {})
            .environmentObject(updateStore)
            .environmentObject(router)
            .task {
                if updateStore.items.isEmpty {
                    updateStore.post(UpdateItem(
                        kind: .reading,
                        title: "ข้อมูลใหม่พร้อมแล้ว",
                        message: "ซิงค์ข้อมูลการนอนและการฟื้นตัวของวันนี้เรียบร้อยแล้ว",
                        deepLink: "trends"
                    ))
                    updateStore.post(UpdateItem(
                        kind: .strapAlert,
                        title: "ซิงค์ประวัติสำเร็จ",
                        message: "ดึงข้อมูลย้อนหลังจากสายรัดเสร็จแล้ว"
                    ))
                }
            }
    }
}

private struct WorkoutDetailDemoHost: View {
    var body: some View {
        WorkoutDetailView(row: reviewWorkout)
    }
}

private struct DetectedStrengthDemoHost: View {
    var body: some View {
        DetectedStrengthDetailsSheet(workout: reviewWorkout)
    }
}

private var reviewWorkout: WorkoutRow {
    let end = Int(Date().timeIntervalSince1970)
    return WorkoutRow(
        startTs: end - 64 * 60,
        endTs: end,
        sport: "Strength Training",
        source: "whoop",
        durationS: 64 * 60,
        energyKcal: 418,
        avgHr: 132,
        maxHr: 171,
        strain: 59.8,
        distanceM: nil,
        zonesJSON: #"{"z1":15.0,"z2":31.0,"z3":28.0,"z4":18.0,"z5":8.0}"#,
        notes: nil
    )
}

private struct PR3ReviewStateDemoHost: View {
    enum Kind: Equatable { case restore, importing, exported, loading, empty, error }
    let kind: Kind

    var body: some View {
        VStack(alignment: .leading, spacing: NoopMetrics.sectionGap) {
            PR3PageHeading(title, overline: "NOOP AI FULL BETA", detail: detail)
            PR3TruthfulState(stateKind, title: stateTitle, message: stateMessage)
            if kind == .restore {
                VStack(alignment: .leading, spacing: 10) {
                    PR3SectionLabel("Restore preview")
                    row("Source", "NOOP AI Full Beta 9.2.1")
                    row("Workouts", "42")
                    row("Strength sessions", "8")
                    row("Goals and plans", "Available")
                    row("Rollback", "Available")
                }
                .padding(14)
                .background(
                    StrandPalette.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: NoopMetrics.cardRadius)
                )
            }
        }
        .screenPadding()
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
    }

    private var title: LocalizedStringKey {
        switch kind {
        case .restore: "Restore"
        case .importing: "Import"
        case .exported: "Export"
        case .loading: "Loading"
        case .empty: "No data"
        case .error: "Something went wrong"
        }
    }

    private var detail: LocalizedStringKey {
        switch kind {
        case .restore: "Review what will be replaced before continuing."
        case .importing: "The backup is checked before any data is changed."
        case .exported: "Your backup is ready to share."
        case .loading: "Reading on-device data."
        case .empty: "There is nothing to show yet."
        case .error: "Your existing data has not been changed."
        }
    }

    private var stateKind: PR3TruthfulState.Kind {
        switch kind {
        case .loading, .importing: .loading
        case .empty: .empty
        case .error: .error
        case .restore, .exported: .warning
        }
    }

    private var stateTitle: LocalizedStringKey {
        switch kind {
        case .restore: "Ready to review"
        case .importing: "Validating backup…"
        case .exported: "Export complete"
        case .loading: "Loading your data…"
        case .empty: "No records yet"
        case .error: "Import failed"
        }
    }

    private var stateMessage: LocalizedStringKey {
        switch kind {
        case .restore: "Nothing is restored until you confirm."
        case .importing: "Checking the manifest, checksums, and database integrity."
        case .exported: "Secrets and derived caches were not included."
        case .loading: "NOOP is opening your local database."
        case .empty: "Connect a data source or import a backup to begin."
        case .error: "The file could not be validated. No data was imported."
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textSecondary)
            Spacer()
            Text(verbatim: value)
                .font(StrandFont.captionNumber)
                .foregroundStyle(StrandPalette.textPrimary)
        }
    }
}

private struct PR3DestructiveConfirmationDemoHost: View {
    @State private var showing = true

    var body: some View {
        PR3ReviewStateDemoHost(kind: .restore)
            .confirmationDialog(
                "Restore this backup?",
                isPresented: $showing,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {}
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Replace this device's data with one of the backups in your folder. This overwrites current data, so back up first if you're unsure.")
            }
            .onAppear { showing = true }
    }
}

/// DEBUG-only host so `--demo-screen ouraonboarding` renders the Add-device wizard deep-linked to the
/// Oura factory-reset-and-adopt prep step (the Beta banner + what-you-get/what-you-lose card + the red
/// irreversible-consent gate). A SwiftUI View body is main-actor, so it can pull the injected LiveState
/// and seed the wizard's `startAt` into the Oura prep step without a ring present.
private struct OuraOnboardingDemoHost: View {
    @EnvironmentObject var live: LiveState
    var body: some View {
        AddDeviceWizard(live: live, onClose: {}, startAt: (.oura, .prep))
    }
}
#endif
