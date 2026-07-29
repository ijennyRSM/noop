import Foundation
import WhoopStore

/// Builds a seven-calendar-day muscle view by summing raw session stimulus
/// before normalization. This avoids saturating at 100 by adding already
/// normalized daily scores.
public enum WeeklyMuscleLoadEngine {
    public struct Output: Equatable, Sendable {
        public var muscleId: String
        public var side: String
        public var rawStimulus: Double
        public var normalizedLoad: Double
        public var sessionCount: Int
        public var confidence: StrengthConfidence

        public init(muscleId: String, side: String, rawStimulus: Double,
                    normalizedLoad: Double, sessionCount: Int,
                    confidence: StrengthConfidence) {
            self.muscleId = muscleId
            self.side = side
            self.rawStimulus = rawStimulus
            self.normalizedLoad = normalizedLoad
            self.sessionCount = sessionCount
            self.confidence = confidence
        }
    }

    public static func aggregate(rows: [MuscleTrainingLoadRecord],
                                 now: Date,
                                 calendar: Calendar = CanonicalDay.calendar(),
                                 coldStartReference: Double = 1_800) -> [Output] {
        let today = calendar.startOfDay(for: now)
        guard let currentStart = calendar.date(byAdding: .day, value: -6, to: today),
              let baselineStart = calendar.date(byAdding: .day, value: -28, to: currentStart)
        else { return [] }
        let currentRows = rows.filter {
            let date = Date(timeIntervalSince1970: TimeInterval($0.trainedAt))
            return date >= currentStart && date < now.addingTimeInterval(1)
        }
        let keys = Set(currentRows.map { "\($0.muscleId)|\($0.side)" })
        return keys.compactMap { key in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard let muscle = parts.first else { return nil }
            let side = parts.count > 1 ? parts[1] : StrengthSide.both.rawValue
            let current = currentRows.filter {
                $0.muscleId == muscle && $0.side == side
            }
            let raw = current.map(\.rawStimulus).filter(\.isFinite).reduce(0, +)
            let sessions = Set(current.map(\.trainedAt)).count

            var historicalWeeks: [Double] = []
            for offset in stride(from: 0, through: 21, by: 7) {
                guard let start = calendar.date(byAdding: .day, value: offset,
                                                to: baselineStart),
                      let end = calendar.date(byAdding: .day, value: 7, to: start)
                else { continue }
                let total = rows.filter {
                    guard $0.muscleId == muscle, $0.side == side else { return false }
                    let date = Date(timeIntervalSince1970: TimeInterval($0.trainedAt))
                    return date >= start && date < end
                }.map(\.rawStimulus).filter(\.isFinite).reduce(0, +)
                if total > 0 { historicalWeeks.append(total) }
            }
            let reference: Double
            let confidence: StrengthConfidence
            if historicalWeeks.count >= 3 {
                reference = median(historicalWeeks)
                confidence = historicalWeeks.count == 4 ? .high : .medium
            } else {
                reference = coldStartReference
                confidence = .low
            }
            return Output(
                muscleId: muscle,
                side: side,
                rawStimulus: raw,
                normalizedLoad: MuscularLoadEngine.normalizedLoad(
                    raw: raw, reference: reference),
                sessionCount: sessions,
                confidence: confidence
            )
        }.sorted {
            if $0.normalizedLoad == $1.normalizedLoad { return $0.muscleId < $1.muscleId }
            return $0.normalizedLoad > $1.normalizedLoad
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
