import Foundation
import WhoopStore

enum SorenessAdjustment {
    /// Soreness is unavailable when absent. When present, it has full influence for 24 hours,
    /// then tapers linearly to zero at 72 hours. Pain is stored separately and never reaches here.
    static func multiplier(checkIn: SorenessCheckInRecord?,
                           muscleId: String,
                           now: Date) -> Double {
        guard let checkIn else { return 1 }
        let recordedAt = Date(timeIntervalSince1970: TimeInterval(checkIn.recordedAt))
        let ageHours = now.timeIntervalSince(recordedAt) / 3_600
        guard ageHours >= 0, ageHours < 72 else { return 1 }
        let freshness = ageHours <= 24 ? 1 : (72 - ageHours) / 48
        guard let soreness = checkIn.perMuscleSoreness[muscleId]
                ?? checkIn.overallSoreness else { return 1 }
        let bounded = Double(min(10, max(0, soreness))) / 10
        return 1 + min(0.15, 0.15 * bounded * freshness)
    }
}
