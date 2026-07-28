import Foundation
import StrandAnalytics
import WhoopStore

/// Safety net for ending a manual strength workout outside the expanded strength logger.
/// The logger normally finalizes first; this path only completes a matching draft that remains.
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
            cardiovascularEffort: cardiovascularEffort,
            muscularLoad: output.muscularLoad)
        session.confidence = output.confidence.rawValue
        try await store.saveStrengthSession(session)

        let day = Repository.localDayKey(
            Date(timeIntervalSince1970: TimeInterval(session.startedAt)))
        let rows = output.muscles.map {
            DailyMuscleLoadRecord(
                day: day, muscleId: $0.muscleId, side: $0.side,
                rawStimulus: $0.rawStimulus, normalizedLoad: $0.normalizedLoad,
                workingSets: $0.workingSets, confidence: output.confidence.rawValue)
        }
        try await store.replaceSessionMuscleLoads(
            sessionId: session.id, deviceId: deviceId, day: day,
            trainedAt: session.startedAt, rows: rows)

        let residualRows = try await store.historicalMuscleLoads(
            deviceId: deviceId,
            from: endedAt - 30 * 86_400)
        let residualHistory = residualRows.map {
            MuscularLoadEngine.HistoricalMuscleLoad(
                muscleId: $0.muscleId, side: $0.side,
                load: $0.normalizedLoad,
                trainedAt: Date(timeIntervalSince1970: TimeInterval($0.trainedAt)),
                confidence: StrengthConfidence(rawValue: $0.confidence) ?? .low)
        }
        let capturedAt = Int(Date().timeIntervalSince1970)
        let residual = MuscularLoadEngine.residualLoads(
            history: residualHistory,
            at: Date(timeIntervalSince1970: TimeInterval(capturedAt)),
            recovery: .init(sleepHours: sleepHours, charge: charge))
        try await store.replaceResidualSnapshot(
            residual.map {
                MuscleResidualRecord(
                    capturedAt: capturedAt, muscleId: $0.muscleId, side: $0.side,
                    residualLoad: $0.residualLoad,
                    confidence: $0.confidence.rawValue,
                    lastTrainedAt: $0.lastTrainedAt.map {
                        Int($0.timeIntervalSince1970)
                    })
            },
            deviceId: deviceId,
            capturedAt: capturedAt)
    }
}
