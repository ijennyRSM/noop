import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

struct DetectedStrengthDetailsSheet: View {
    let workout: WorkoutRow
    @EnvironmentObject private var repository: Repository
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var region = "Full Body"
    @State private var intensity = "Moderate"
    @State private var rpe = 0
    @State private var saving = false
    @State private var detailedSessionId: String?

    private let regions = ["Upper Body", "Lower Body", "Full Body", "Core"]
    private let intensities = ["Light", "Moderate", "Hard", "Very Hard"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Add strength details")
                        .font(StrandFont.title1)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text("Keep the detected heart-rate workout and add either a complete exercise log or a faster estimated muscle summary.")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)

                    NoopButton("Add complete exercise details",
                               systemImage: "list.bullet.clipboard",
                               kind: .primary, fullWidth: true) {
                        Task { await createDetailedSession() }
                    }

                    NoopCard(tint: StrandPalette.metricCyan) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick muscle and intensity summary")
                                .font(StrandFont.headline)
                            Picker("Body region", selection: $region) {
                                ForEach(regions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Picker("Intensity", selection: $intensity) {
                                ForEach(intensities, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Picker("Session RPE", selection: $rpe) {
                                Text("RPE optional").tag(0)
                                ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                            }
                            NoopButton(saving ? "Saving…" : "Save quick summary",
                                       systemImage: "checkmark.circle",
                                       kind: .secondary, fullWidth: true) {
                                Task { await saveQuickSummary() }
                            }
                            .disabled(saving)
                        }
                    }
                    Text("Quick summaries have medium confidence. They do not invent exercises, sets, side-to-side asymmetry, or measured muscle activation.")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary)
                    Button("Skip strength details") { dismiss() }
                        .frame(maxWidth: .infinity)
                }
                .screenPadding()
                .padding(.vertical)
            }
            .background(StrandPalette.surfaceBase.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: Binding(
                get: { detailedSessionId != nil },
                set: { if !$0 { detailedSessionId = nil } })) {
                    if let sessionId = detailedSessionId {
                        StrengthCompletedEditor(sessionId: sessionId) {
                            detailedSessionId = nil
                            dismiss()
                        }
                        .environmentObject(repository)
                        .environmentObject(model)
                        .strengthSheetPresentation(largeFirst: true)
                    }
                }
        }
    }

    private func existingOrNew(source: String) async -> StrengthSessionRecord? {
        guard let store = await repository.storeHandle() else { return nil }
        if let existing = try? await store.strengthSession(
            deviceId: repository.deviceId, workoutStartTs: workout.startTs) {
            return existing
        }
        return StrengthSessionRecord(
            deviceId: repository.deviceId, workoutStartTs: workout.startTs,
            startedAt: workout.startTs, endedAt: workout.endTs,
            title: "Strength Training", status: StrengthSessionStatus.completed.rawValue,
            source: source, cardiovascularEffort: workout.strain)
    }

    private func createDetailedSession() async {
        guard var session = await existingOrNew(source: "detected-details"),
              let store = await repository.storeHandle() else { return }
        session.source = "detected-details"
        session.status = StrengthSessionStatus.completed.rawValue
        do {
            try await store.saveStrengthSession(session)
            if WorkoutSource.classify(workout.source) == .detected {
                await repository.relabelDetected(workout, sport: "Strength Training")
            }
            detailedSessionId = session.id
        } catch { }
    }

    private func saveQuickSummary() async {
        saving = true
        defer { saving = false }
        guard var session = await existingOrNew(source: "detected-summary"),
              let store = await repository.storeHandle() else { return }
        let score: Double
        switch intensity {
        case "Light": score = 25
        case "Hard": score = 70
        case "Very Hard": score = 90
        default: score = 45
        }
        session.quickRegion = region
        session.quickIntensity = intensity
        session.sessionRPE = rpe > 0 ? Double(rpe) : nil
        session.confidence = StrengthConfidence.medium.rawValue
        session.muscularLoad = score
        session.totalTrainingLoad = MuscularLoadEngine.totalTrainingLoad(
            cardiovascularEffort: workout.strain, muscularLoad: score)
        session.source = "detected-summary"
        do {
            try await store.saveStrengthSession(session)
            let day = Repository.localDayKey(
                Date(timeIntervalSince1970: TimeInterval(workout.startTs)))
            let muscles = muscleIds(for: region)
            let rows = muscles.map {
                DailyMuscleLoadRecord(
                    day: day, muscleId: $0, rawStimulus: score,
                    normalizedLoad: score, workingSets: 0,
                    confidence: StrengthConfidence.medium.rawValue)
            }
            try await store.replaceSessionMuscleLoads(
                sessionId: session.id, deviceId: session.deviceId, day: day,
                trainedAt: session.startedAt, rows: rows)
            if WorkoutSource.classify(workout.source) == .detected {
                await repository.relabelDetected(workout, sport: "Strength Training")
            }
            dismiss()
        } catch { }
    }

    private func muscleIds(for region: String) -> [String] {
        switch region {
        case "Upper Body":
            ["chest", "lats", "upper_back", "front_delts", "biceps", "triceps"]
        case "Lower Body":
            ["glutes", "quadriceps", "hamstrings", "calves"]
        case "Core":
            ["abdominals", "obliques", "erector_spinae"]
        default:
            ["chest", "lats", "glutes", "quadriceps", "hamstrings", "abdominals"]
        }
    }
}
