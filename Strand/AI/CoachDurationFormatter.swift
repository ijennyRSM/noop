import Foundation

/// Natural-language duration formatting for the text summary sent to AI Coach.
/// Model and database values remain in their original seconds/minutes units.
enum CoachDurationFormatter {
    static func format(minutes: Double?) -> String {
        guard let minutes, minutes.isFinite else { return "missing" }
        return components(minutes: max(0, minutes))
    }

    static func formatSigned(minutes: Double?) -> String {
        guard let minutes, minutes.isFinite else { return "missing" }
        let rounded = Int(minutes.rounded())
        guard rounded != 0 else { return "0 min" }
        let sign = rounded > 0 ? "+" : "-"
        return sign + components(minutes: Double(abs(rounded)))
    }

    private static func components(minutes: Double) -> String {
        let roundedMinutes = max(0, Int(minutes.rounded()))
        let hours = roundedMinutes / 60
        let remainingMinutes = roundedMinutes % 60
        if hours == 0 { return "\(remainingMinutes) min" }
        if remainingMinutes == 0 { return "\(hours) h" }
        return "\(hours) h \(remainingMinutes) min"
    }
}
