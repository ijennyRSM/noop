import Foundation
import StrandAnalytics
import WhoopStore

actor CurrentMuscleResidualService {
    static let shared = CurrentMuscleResidualService()

    private struct CacheEntry {
        var rows: [MuscleResidualRecord]
        var computedAt: Date
        var refreshToken: Int
        var checkInTimestamp: Date?
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheLifetime: TimeInterval = 15 * 60

    func currentLoads(store: WhoopStore,
                      deviceId: String,
                      now: Date = Date(),
                      refreshToken: Int,
                      recovery: MuscularLoadEngine.RecoveryModifiers = .init(),
                      checkIn suppliedCheckIn: SorenessCheckInRecord? = nil) async -> [MuscleResidualRecord] {
        let checkIn: SorenessCheckInRecord?
        if let suppliedCheckIn {
            checkIn = suppliedCheckIn
        } else {
            checkIn = try? await store.latestSorenessCheckIn(deviceId: deviceId)
        }
        let checkInDate = checkIn.map { Date(timeIntervalSince1970: TimeInterval($0.recordedAt)) }
        if let cached = cache[deviceId],
           cached.refreshToken == refreshToken,
           cached.checkInTimestamp == checkInDate,
           now.timeIntervalSince(cached.computedAt) >= 0,
           now.timeIntervalSince(cached.computedAt) < cacheLifetime {
            return cached.rows
        }

        do {
            let calendar = CanonicalDay.calendar()
            let today = calendar.startOfDay(for: now)
            let historyStart = calendar.date(
                byAdding: .day,
                value: -30,
                to: today
            ) ?? today
            let from = Int(historyStart.timeIntervalSince1970)
            let historyRows = try await store.historicalMuscleLoads(
                deviceId: deviceId, from: from)
            let history = historyRows.map {
                MuscularLoadEngine.HistoricalMuscleLoad(
                    muscleId: $0.muscleId,
                    side: $0.side,
                    load: $0.normalizedLoad,
                    trainedAt: Date(timeIntervalSince1970: TimeInterval($0.trainedAt)),
                    confidence: StrengthConfidence(rawValue: $0.confidence) ?? .low
                )
            }
            let base = MuscularLoadEngine.residualLoads(
                history: history, at: now, recovery: recovery)
            let capturedAt = Int(now.timeIntervalSince1970)
            let rows = base.map { value in
                let soreness = SorenessAdjustment.multiplier(
                    checkIn: checkIn, muscleId: value.muscleId, now: now)
                return MuscleResidualRecord(
                    capturedAt: capturedAt,
                    muscleId: value.muscleId,
                    side: value.side,
                    residualLoad: min(100, max(0, value.residualLoad * soreness)),
                    confidence: value.confidence.rawValue,
                    lastTrainedAt: value.lastTrainedAt.map {
                        Int($0.timeIntervalSince1970)
                    }
                )
            }
            try await store.replaceResidualSnapshot(
                rows, deviceId: deviceId, capturedAt: capturedAt)
            cache[deviceId] = CacheEntry(
                rows: rows,
                computedAt: now,
                refreshToken: refreshToken,
                checkInTimestamp: checkInDate
            )
            return rows
        } catch {
            let fallback = (try? await store.latestResidualLoads(deviceId: deviceId)) ?? []
            cache[deviceId] = CacheEntry(
                rows: fallback,
                computedAt: now,
                refreshToken: refreshToken,
                checkInTimestamp: checkInDate
            )
            return fallback
        }
    }

    func invalidate(deviceId: String) {
        cache.removeValue(forKey: deviceId)
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
