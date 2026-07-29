import SwiftUI
import Foundation

/// Fixed presentation colors for the three primary performance scores.
///
/// These tokens intentionally do not read `StrandPalette.chartStyle`: chart themes may
/// restyle supporting charts, sleep stages, and HR zones, but must never change the
/// identity of a primary Charge, Rest, or Effort score.
public enum PerformanceScoreMetric: Sendable, Equatable {
    case charge
    case rest
    case effort

    public var usesPercent: Bool {
        self != .effort
    }
}

public enum PerformanceScoreColorToken: String, Sendable, Equatable {
    /// Sampled from the supplied WHOOP recovery-range reference (dominant arc #FE0127).
    case chargePoor = "#FE0127"
    /// Sampled from the supplied WHOOP recovery-range reference (dominant arc #FDE000).
    case chargeModerate = "#FDE000"
    /// Sampled from the supplied WHOOP home/detail references (dominant arc #18EE05).
    case chargeGood = "#18EE05"
    /// Sampled from the supplied three-ring home reference (dominant arc #80A6C0).
    case rest = "#80A6C0"
    /// Sampled from the supplied three-ring home reference (dominant arc #0295EB).
    case effort = "#0295EB"
    case track = "#313A41"
    case coachChrome = "#3CA9D6"

    public var color: Color { Color(hex: rawValue) }
}

public enum PerformanceScorePalette {
    public static let poorRed = PerformanceScoreColorToken.chargePoor.color
    public static let moderateYellow = PerformanceScoreColorToken.chargeModerate.color
    public static let goodGreen = PerformanceScoreColorToken.chargeGood.color
    public static let restBlue = PerformanceScoreColorToken.rest.color
    public static let effortBlue = PerformanceScoreColorToken.effort.color
    public static let ringTrack = PerformanceScoreColorToken.track.color
    public static let coachChrome = PerformanceScoreColorToken.coachChrome.color

    public static func chargeToken(score: Double?) -> PerformanceScoreColorToken {
        guard let score, score.isFinite else { return .track }
        switch min(100, max(0, score)) {
        case ...33: return .chargePoor
        case ...66: return .chargeModerate
        default: return .chargeGood
        }
    }

    public static func token(for metric: PerformanceScoreMetric,
                             score: Double?) -> PerformanceScoreColorToken {
        switch metric {
        case .charge: chargeToken(score: score)
        case .rest: .rest
        case .effort: .effort
        }
    }

    /// Ring geometry never participates in color selection. This overload exists so
    /// deterministic tests can pin compact/detail consistency at the presentation boundary.
    public static func token(for metric: PerformanceScoreMetric,
                             score: Double?,
                             style _: MetricRingStyle) -> PerformanceScoreColorToken {
        token(for: metric, score: score)
    }

    public static func color(for metric: PerformanceScoreMetric, score: Double?) -> Color {
        token(for: metric, score: score).color
    }
}

/// Explicit ring proportions. Fixed values prevent a ring from expanding to fill a
/// card and keep the value-to-ring relationship identical across Today and details.
public enum MetricRingStyle: Sendable, Equatable {
    case compact
    case hero

    public var diameter: CGFloat {
        switch self {
        case .compact: 92
        case .hero: 248
        }
    }

    public var strokeWidth: CGFloat {
        switch self {
        case .compact: 6
        case .hero: 9.5
        }
    }

    public var integerValueFontSize: CGFloat {
        switch self {
        case .compact: 34
        case .hero: 76
        }
    }

    public var decimalValueFontSize: CGFloat {
        switch self {
        case .compact: 32
        case .hero: 68
        }
    }

    public var unitFontSize: CGFloat {
        switch self {
        case .compact: 18
        case .hero: 34
        }
    }

    public var stateFontSize: CGFloat {
        switch self {
        case .compact: 10
        case .hero: 14
        }
    }

    public var labelFontSize: CGFloat {
        switch self {
        case .compact: 10
        case .hero: 12
        }
    }

    public var valueFontToRingRatio: CGFloat {
        integerValueFontSize / diameter
    }
}

public struct PerformanceScoreText: Sendable, Equatable {
    public let number: String
    public let unit: String?

    public var combined: String {
        number + (unit ?? "")
    }
}

public enum PerformanceScoreFormatter {
    public static func text(metric: PerformanceScoreMetric,
                            score: Double?,
                            decimals: Int = 0) -> PerformanceScoreText {
        guard let score, score.isFinite else {
            return PerformanceScoreText(number: "–", unit: nil)
        }
        let precision = max(0, decimals)
        let number = precision == 0
            ? String(Int(score.rounded()))
            : String(format: "%.\(precision)f", score)
        return PerformanceScoreText(number: number, unit: metric.usesPercent ? "%" : nil)
    }
}
