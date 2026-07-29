import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

struct DetectedStrengthDetailsSheet: View {
    let workout: WorkoutRow
    @EnvironmentObject private var repository: Repository
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var region: StrengthSummaryEstimator.Region = .fullBody
    @State private var intensity: StrengthSummaryEstimator.Intensity = .moderate
    @State private var rpe = 0
    @State private var saving = false
    @State private var detailedSessionId: String?
    @State private var errorMessage: String?

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
                                ForEach(StrengthSummaryEstimator.Region.allCases,
                                        id: \.self) {
                                    Text(regionTitle($0)).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            Picker("Intensity", selection: $intensity) {
                                ForEach(StrengthSummaryEstimator.Intensity.allCases,
                                        id: \.self) {
                                    Text(intensityTitle($0)).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            Picker("Session RPE", selection: $rpe) {
                                Text("RPE optional").tag(0)
                                ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                            }
                            Text("Duration: \(Int(workoutDurationMinutes.rounded())) min")
                                .font(StrandFont.footnote)
                                .foregroundStyle(StrandPalette.textTertiary)
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
            .alert("Could not save strength details", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
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
              let store = await repository.storeHandle() else {
            errorMessage = String(localized: "The local database could not be opened.")
            return
        }
        session.source = "detected-details"
        session.status = StrengthSessionStatus.completed.rawValue
        do {
            let output = MuscularLoadEngine.SessionOutput(
                muscularLoad: 0,
                muscles: [],
                confidence: .low,
                assumptions: ["Exercise details not entered yet"]
            )
            let commit = try await StrengthDerivedBuilder.makeCommit(
                session: session,
                output: output,
                store: store,
                recovery: recoveryModifiers,
                relabel: detectedRelabel
            )
            try await store.commitStrengthDerived(commit)
            await CurrentMuscleResidualService.shared.invalidate(
                deviceId: session.deviceId)
            detailedSessionId = session.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveQuickSummary() async {
        saving = true
        defer { saving = false }
        guard var session = await existingOrNew(
            source: StrengthSummaryEstimator.sourceVersion),
              let store = await repository.storeHandle() else {
            errorMessage = String(localized: "The local database could not be opened.")
            return
        }
        let estimate = StrengthSummaryEstimator.estimate(
            region: region,
            intensity: intensity,
            rpe: rpe > 0 ? Double(rpe) : nil,
            durationMinutes: workoutDurationMinutes
        )
        session.quickRegion = region.rawValue
        session.quickIntensity = intensity.rawValue
        session.sessionRPE = rpe > 0 ? Double(rpe) : nil
        session.confidence = StrengthConfidence.medium.rawValue
        session.muscularLoad = estimate.score
        session.totalTrainingLoad = MuscularLoadEngine.totalTrainingLoad(
            storedCardiovascularEffort: workout.strain,
            muscularLoad: estimate.score)
        session.source = estimate.source
        do {
            let output = MuscularLoadEngine.SessionOutput(
                muscularLoad: estimate.score,
                muscles: estimate.muscles,
                confidence: .medium,
                assumptions: estimate.assumptions
            )
            let commit = try await StrengthDerivedBuilder.makeCommit(
                session: session,
                output: output,
                store: store,
                recovery: recoveryModifiers,
                relabel: detectedRelabel
            )
            try await store.commitStrengthDerived(commit)
            await CurrentMuscleResidualService.shared.invalidate(
                deviceId: session.deviceId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var workoutDurationMinutes: Double {
        max(0, workout.durationS ?? Double(workout.endTs - workout.startTs)) / 60
    }

    private var recoveryModifiers: MuscularLoadEngine.RecoveryModifiers {
        .init(
            sleepHours: repository.today?.totalSleepMin.map { $0 / 60 },
            charge: repository.today?.recovery
        )
    }

    private var detectedRelabel: DetectedWorkoutRelabel? {
        WorkoutSource.classify(workout.source) == .detected
            ? repository.detectedWorkoutRelabel(
                workout, targetSport: "Strength Training")
            : nil
    }

    private func regionTitle(_ value: StrengthSummaryEstimator.Region) -> String {
        switch value {
        case .upperBody: String(localized: "Upper Body")
        case .lowerBody: String(localized: "Lower Body")
        case .fullBody: String(localized: "Full Body")
        case .core: String(localized: "Core")
        }
    }

    private func intensityTitle(_ value: StrengthSummaryEstimator.Intensity) -> String {
        switch value {
        case .light:
            String(localized: "strength.intensity.light", defaultValue: "Light")
        case .moderate:
            String(localized: "strength.intensity.moderate", defaultValue: "Moderate")
        case .hard:
            String(localized: "strength.intensity.hard", defaultValue: "Hard")
        case .veryHard:
            String(localized: "strength.intensity.veryHard", defaultValue: "Very Hard")
        }
    }
}
