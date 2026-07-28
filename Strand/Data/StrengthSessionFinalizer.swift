import Foundation
import StrandAnalytics
import WhoopStore

/// Safety net for ending a manual strength workout outside the expanded strength logger.
/// The logger normally finalizes first; this path only completes a matching draft that remains.
@MainActor
enum StrengthSessionFinalizer {
    static func finalizeMatchingDraft(
        store: WhoopStore,
        deviceId: String,
        workoutStartTs: Int,
        endedAt: Int,
        cardiovascularEffort: Double?,
        bodyweightKg: Double?,
        sleepHours: Double?,
        charge: Double?
    ) async throws {
        guard var session = try await store.activeStrengthSession(deviceId: deviceId),
              session.workoutStartTs == workoutStartTs else { return }

        var inputs: [MuscularLoadEngine.SetInput] = []
        for exercise in session.exercises {
            guard let definition = try await store.exerciseDefinition(id: exercise.exerciseId) else {
                continue
            }
            let e1RM = exercise.sets.compactMap { set -> Double? in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return MuscularLoadEngine.estimatedOneRepMax(weightKg: weight, reps: reps)
            }.max()
            inputs.append(contentsOf: exercise.sets.map {
                .init(set: $0, exercise: definition,
                      userBodyweightKg: bodyweightKg, estimatedOneRepMaxKg: e1RM)
            })
        }

        let historyStart = Int(Date(timeIntervalSince1970: TimeInterval(endedAt))
            .addingTimeInterval(-28 * 86_400).timeIntervalSince1970)
        let priorRows = try await store.historicalMuscleLoads(
            deviceId: deviceId, from: historyStart)
        let priorHistoryRows = priorRows.filter {
                $0.trainedAt != session.startedAt
            }
        let history = Dictionary(grouping: priorHistoryRows, by: \.muscleId).map {
            MuscularLoadEngine.MuscleHistory(
                muscleId: $0.key, rawStimuli: $0.value.map(\.rawStimulus))
        }
        let output = MuscularLoadEngine.calculate(inputs: inputs, history: history)
        session.status = StrengthSessionStatus.completed.rawValue
        session.endedAt = endedAt
        session.cardiovascularEffort = cardiovascularEffort
        session.muscularLoad = output.muscularLoad
        session.totalTrainingLoad = MuscularLoadEngine.totalTrainingLoad(
            storedCardiovascularEffort: cardiovascularEffort,
            muscularLoad: output.muscularLoad)
        session.confidence = output.confidence.rawValue
        let commit = try await StrengthDerivedBuilder.makeCommit(
            session: session,
            output: output,
            store: store,
            recovery: .init(sleepHours: sleepHours, charge: charge)
        )
        try await store.commitStrengthDerived(commit)
        await CurrentMuscleResidualService.shared.invalidate(deviceId: deviceId)
    }
}
