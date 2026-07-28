import Foundation

/// A cardiovascular-effort value whose numeric scale is explicit.
///
/// NOOP persists effort on its native 0...100 axis. WHOOP CSV import/export is the
/// only supported 0...21 boundary. Keeping the scale beside the value prevents a
/// legitimate low NOOP value (for example 10.5/100) from being mistaken for 10.5/21.
public struct CardiovascularEffortValue: Codable, Equatable, Sendable {
    public enum Scale: String, Codable, Sendable {
        case noop100
        case whoop21

        public var maximum: Double {
            switch self {
            case .noop100: 100
            case .whoop21: 21
            }
        }
    }

    public enum Source: String, Codable, Sendable {
        case stored
        case liveAnalytics
        case whoopCSVImport
        case manual
        case appleHealth
        case unknown
    }

    public let rawValue: Double
    public let scale: Scale
    public let source: Source

    public init(rawValue: Double, scale: Scale, source: Source) {
        self.rawValue = rawValue
        self.scale = scale
        self.source = source
    }

    /// The value normalized to NOOP's canonical 0...100 axis.
    public var normalized100: Double {
        guard rawValue.isFinite else { return 0 }
        return min(100, max(0, rawValue / scale.maximum * 100))
    }

    public var isHardWorkout: Bool { normalized100 >= 70 }

    public func value(on targetScale: Scale) -> Double {
        normalized100 / 100 * targetScale.maximum
    }

    public static func stored(_ value: Double?) -> CardiovascularEffortValue? {
        value.map { .init(rawValue: $0, scale: .noop100, source: .stored) }
    }
}
