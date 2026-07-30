import SwiftUI

/// Presentation-only score colours used by the accepted PR #3 composition.
///
/// This palette does not participate in score calculation and is intentionally independent of
/// ChartStyle. Detailed charts may still use the user's selected chart theme.
public enum PR3ScorePalette {
    public static let poorCharge = Color(hex: "#FF4D4D")
    public static let moderateCharge = Color(hex: "#FFC400")
    public static let goodCharge = Color(hex: "#00E65A")
    public static let rest = Color(hex: "#8EB8D0")
    public static let effort = Color(hex: "#00AEEF")
    public static let track = Color(hex: "#394247")

    public static func charge(_ score: Double?) -> Color {
        guard let score else { return Color(hex: "#667078") }
        if score <= 33 { return poorCharge }
        if score <= 66 { return moderateCharge }
        return goodCharge
    }
}
