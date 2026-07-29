import Foundation
import StrandAnalytics
import WhoopStore

enum StrengthDerivedBuilder {
    static func makeCommit(
        session: StrengthSessionRecord,
        output: MuscularLoadEngine.SessionOutput,
        store: WhoopStore,
        recovery: MuscularLoadEngine.RecoveryModifiers,
        checkIn suppliedCheckIn: SorenessCheckInRecord? = nil,
        relabel: DetectedWorkoutRelabel? = nil,
        now: Date = Date()
    ) async throws -> StrengthDerivedCommit {
        let checkIn: SorenessCheckInRecord?
        if let suppliedCheckIn {
            checkIn = suppliedCheckIn
        } else {
            checkIn = try? await store.latestSorenessCheckIn(deviceId: session.deviceId)
        }
        let day = await Repository.localDayKey(
            Date(timeIntervalSince1970: TimeInterval(session.startedAt)))
        let muscleRows = output.muscles.map {
            DailyMuscleLoadRecord(
                day: day,
                muscleId: $0.muscleId,
                side: $0.side,
                rawStimulus: $0.rawStimulus,
                normalizedLoad: $0.normalizedLoad,
                workingSets: $0.workingSets,
                confidence: output.confidence.rawValue
            )
        }

        let calendar = CanonicalDay.calendar()
        let today = calendar.startOfDay(for: now)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -30,
            to: today
        ) ?? today
        let prior = try await store.historicalMuscleLoads(
            deviceId: session.deviceId,
            from: Int(historyStart.timeIntervalSince1970)
        ).filter { $0.trainedAt != session.startedAt }
        var history = prior.map {
            MuscularLoadEngine.HistoricalMuscleLoad(
                muscleId: $0.muscleId,
                side: $0.side,
                load: $0.normalizedLoad,
                trainedAt: Date(timeIntervalSince1970: TimeInterval($0.trainedAt)),
                confidence: StrengthConfidence(rawValue: $0.confidence) ?? .low
            )
        }
        history += output.muscles.map {
            MuscularLoadEngine.HistoricalMuscleLoad(
                muscleId: $0.muscleId,
                side: $0.side,
                load: $0.normalizedLoad,
                trainedAt: Date(timeIntervalSince1970: TimeInterval(session.startedAt)),
                confidence: output.confidence
            )
        }
        let residual = MuscularLoadEngine.residualLoads(
            history: history, at: now, recovery: recovery)
        let capturedAt = Int(now.timeIntervalSince1970)
        let residualRows = residual.map { value in
            let soreness = SorenessAdjustment.multiplier(
                checkIn: checkIn, muscleId: value.muscleId, now: now)
            return MuscleResidualRecord(
                capturedAt: capturedAt,
                muscleId: value.muscleId,
                side: value.side,
                residualLoad: min(100, value.residualLoad * soreness),
                confidence: value.confidence.rawValue,
                lastTrainedAt: value.lastTrainedAt.map {
                    Int($0.timeIntervalSince1970)
                }
            )
        }
        return StrengthDerivedCommit(
            session: session,
            day: day,
            muscleLoads: muscleRows,
            residualSnapshot: residualRows,
            residualCapturedAt: capturedAt,
            detectedWorkoutRelabel: relabel
        )
    }
}
