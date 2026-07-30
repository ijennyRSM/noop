import SwiftUI

/// Low-level presentation primitives for the PR #9 full-app visual port.
///
/// These intentionally do not choose a screen hierarchy. Strength, Coach,
/// planning, workouts, privacy, and backup each keep screen-specific
/// compositions while sharing the approved graphite surface and typography.
public enum PR3SecondaryPalette {
    public static let canvas = StrandPalette.surfaceBase
    public static let surface = StrandPalette.surfaceRaised
    public static let inset = StrandPalette.surfaceInset
    public static let border = StrandPalette.hairline
    public static let action = Color(hex: "#00AEEF")
    public static let warning = Color(hex: "#FFC400")
    public static let danger = Color(hex: "#FF4D4D")
    public static let success = Color(hex: "#00E65A")
}

/// Compact geometry used only by secondary screens in the full-app port.
/// The approved root/Today/score-detail geometry continues to use
/// `NoopMetrics`, so extending the design cannot silently move that baseline.
public enum PR3SecondaryMetrics {
    public static let cardRadius: CGFloat = 16
    public static let cardPadding: CGFloat = 14
    public static let sectionGap: CGFloat = 18
    public static let screenPadding: CGFloat = 16
    public static let innerSpacing: CGFloat = 10
}

public struct PR3PageHeading: View {
    private let overline: LocalizedStringKey?
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?

    public init(
        _ title: LocalizedStringKey,
        overline: LocalizedStringKey? = nil,
        detail: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.overline = overline
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let overline {
                Text(overline).strandOverline()
            }
            Text(title)
                .font(StrandFont.title1)
                .tracking(-0.35)
                .foregroundStyle(StrandPalette.textPrimary)
            if let detail {
                Text(detail)
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct PR3SectionLabel: View {
    private let title: LocalizedStringKey
    private let trailing: String?

    public init(_ title: LocalizedStringKey, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).strandOverline()
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(StrandFont.captionNumber)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
    }
}

public struct PR3StatusTag: View {
    public enum Tone {
        case neutral, action, good, warning, danger
    }

    private let title: LocalizedStringKey
    private let tone: Tone

    public init(_ title: LocalizedStringKey, tone: Tone = .neutral) {
        self.title = title
        self.tone = tone
    }

    private var color: Color {
        switch tone {
        case .neutral: StrandPalette.textSecondary
        case .action: PR3SecondaryPalette.action
        case .good: PR3SecondaryPalette.success
        case .warning: PR3SecondaryPalette.warning
        case .danger: PR3SecondaryPalette.danger
        }
    }

    public var body: some View {
        Text(title)
            .font(StrandFont.overlineScaled(9))
            .tracking(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(color.opacity(0.10), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(color.opacity(0.28), lineWidth: 1))
    }
}

public struct PR3CompactRow<Leading: View, Trailing: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    @ViewBuilder private let leading: () -> Leading
    @ViewBuilder private let trailing: () -> Trailing

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            leading()
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StrandFont.headline)
                    .foregroundStyle(StrandPalette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

public struct PR3InlineMetric: View {
    private let label: LocalizedStringKey
    private let value: String
    private let unit: String?
    private let color: Color

    public init(
        _ label: LocalizedStringKey,
        value: String,
        unit: String? = nil,
        color: Color = StrandPalette.textPrimary
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).strandOverline()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(StrandFont.number(25))
                    .tracking(-0.4)
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct PR3TruthfulState: View {
    public enum Kind {
        case loading, empty, warning, error
    }

    private let kind: Kind
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey

    public init(_ kind: Kind, title: LocalizedStringKey, message: LocalizedStringKey) {
        self.kind = kind
        self.title = title
        self.message = message
    }

    private var icon: String {
        switch kind {
        case .loading: "arrow.triangle.2.circlepath"
        case .empty: "minus.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private var color: Color {
        switch kind {
        case .loading: PR3SecondaryPalette.action
        case .empty: StrandPalette.textTertiary
        case .warning: PR3SecondaryPalette.warning
        case .error: PR3SecondaryPalette.danger
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(StrandFont.headline)
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(message)
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PR3SecondaryPalette.surface, in: RoundedRectangle(
            cornerRadius: PR3SecondaryMetrics.cardRadius, style: .continuous
        ))
        .overlay(RoundedRectangle(cornerRadius: PR3SecondaryMetrics.cardRadius, style: .continuous)
            .strokeBorder(PR3SecondaryPalette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

public struct PR3PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.headline)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(PR3SecondaryPalette.action, in: RoundedRectangle(
                cornerRadius: 12, style: .continuous
            ))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
