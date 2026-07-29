import SwiftUI

/// Semantic presentation tokens for the unified performance interface.
///
/// These names describe NOOP concepts rather than another product's brand. Existing
/// palette tokens remain source compatible; the performance layer centralises the
/// tighter spacing, surfaces and restrained motion used by the iPhone redesign.
public enum PerformanceTheme {
    public static let appBackground = Color(light: "#F2F4F7", dark: "#0C1014")
    public static let primarySurface = Color(light: "#FFFFFF", dark: "#171C21")
    public static let secondarySurface = Color(light: "#F3F5F7", dark: "#20262C")
    public static let raisedSurface = Color(light: "#FFFFFF", dark: "#292F35")
    public static let subtleDivider = Color(light: "#DDE2E7", dark: "#303840")

    public static let primaryText = Color(light: "#111820", dark: "#F6F8FA")
    public static let secondaryText = Color(light: "#4F5B67", dark: "#B9C1C9")
    public static let tertiaryText = Color(light: "#788490", dark: "#7F8A95")

    public static let charge = Color(light: "#178A55", dark: "#22D37F")
    public static let rest = Color(light: "#3979A5", dark: "#7FB5D8")
    public static let effort = Color(light: "#0077B8", dark: "#00AEEF")
    public static let warning = Color(light: "#A86700", dark: "#F2B134")
    public static let critical = Color(light: "#B52B3A", dark: "#FF5364")
    public static let coach = Color(light: "#5856C9", dark: "#7A7CFF")
    public static let muscle = Color(light: "#8D4DCC", dark: "#B77BFF")

    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 16
        public static let card: CGFloat = 20
        public static let navigation: CGFloat = 24
    }

    public enum Metrics {
        public static let compactRowHeight: CGFloat = 48
        public static let minimumTapTarget: CGFloat = 44
        public static let navigationHeight: CGFloat = 66
        public static let chartLineWidth: CGFloat = 2
        public static let ringLineWidth: CGFloat = 9
    }

    public enum Motion {
        public static let fast: Double = 0.16
        public static let standard: Double = 0.24
        public static let slow: Double = 0.38

        public static func transition(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: standard)
        }
    }
}

public enum PerformanceMetricTone: Sendable, Equatable {
    case charge
    case rest
    case effort
    case muscle
    case coach
    case warning
    case critical
    case neutral

    public var color: Color {
        switch self {
        case .charge: PerformanceTheme.charge
        case .rest: PerformanceTheme.rest
        case .effort: PerformanceTheme.effort
        case .muscle: PerformanceTheme.muscle
        case .coach: PerformanceTheme.coach
        case .warning: PerformanceTheme.warning
        case .critical: PerformanceTheme.critical
        case .neutral: PerformanceTheme.secondaryText
        }
    }
}

