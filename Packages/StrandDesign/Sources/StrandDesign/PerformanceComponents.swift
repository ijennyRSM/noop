import SwiftUI

// MARK: - Containers

public struct PerformanceCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = PerformanceTheme.Spacing.md,
                @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PerformanceTheme.Radius.card, style: .continuous)
                    .fill(PerformanceTheme.primarySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PerformanceTheme.Radius.card, style: .continuous)
                    .strokeBorder(PerformanceTheme.subtleDivider.opacity(0.72), lineWidth: 0.75)
            )
    }
}

public struct ChartContainer<Content: View>: View {
    private let title: LocalizedStringKey?
    private let summary: LocalizedStringKey?
    private let content: Content

    public init(title: LocalizedStringKey? = nil,
                summary: LocalizedStringKey? = nil,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.summary = summary
        self.content = content()
    }

    public var body: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
                if let title {
                    Text(title)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                }
                content
                if let summary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(summary)
                }
            }
        }
    }
}

public struct PerformanceMetricGrid<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: PerformanceTheme.Spacing.sm),
                GridItem(.flexible(), spacing: PerformanceTheme.Spacing.sm),
            ],
            spacing: PerformanceTheme.Spacing.sm
        ) {
            content
        }
    }
}

// MARK: - Headings and rows

public struct PerformanceSectionHeader<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let trailing: Trailing

    public init(_ title: LocalizedStringKey,
                subtitle: LocalizedStringKey? = nil,
                @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PerformanceTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PerformanceTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: PerformanceTheme.Spacing.xs)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public extension PerformanceSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

public struct PerformanceListRow<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let icon: String?
    private let tint: Color
    private let trailing: Trailing

    public init(_ title: LocalizedStringKey,
                subtitle: LocalizedStringKey? = nil,
                icon: String? = nil,
                tint: Color = PerformanceTheme.effort,
                @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: PerformanceTheme.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PerformanceTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: PerformanceTheme.Spacing.xs)
            trailing
        }
        .frame(minHeight: PerformanceTheme.Metrics.compactRowHeight)
        .contentShape(Rectangle())
    }
}

public extension PerformanceListRow where Trailing == EmptyView {
    init(_ title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         icon: String? = nil,
         tint: Color = PerformanceTheme.effort) {
        self.init(title, subtitle: subtitle, icon: icon, tint: tint) { EmptyView() }
    }
}

public struct MetricRow: View {
    private let title: LocalizedStringKey
    private let value: String
    private let detail: String?
    private let symbol: String?
    private let tone: PerformanceMetricTone

    public init(_ title: LocalizedStringKey,
                value: String,
                detail: String? = nil,
                symbol: String? = nil,
                tone: PerformanceMetricTone = .neutral) {
        self.title = title
        self.value = value
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: PerformanceTheme.Spacing.sm) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(tone.color)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PerformanceTheme.primaryText)
            Spacer(minLength: PerformanceTheme.Spacing.xs)
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(PerformanceTheme.primaryText)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                }
            }
        }
        .frame(minHeight: PerformanceTheme.Metrics.compactRowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text([value, detail].compactMap { $0 }.joined(separator: ", ")))
    }
}

// MARK: - Metric hierarchy

public struct MetricRing: View {
    private let value: Double?
    private let valueText: String
    private let label: LocalizedStringKey
    private let stateText: LocalizedStringKey?
    private let tone: PerformanceMetricTone
    private let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawnFraction: Double = 0

    public init(value: Double?,
                valueText: String,
                label: LocalizedStringKey,
                stateText: LocalizedStringKey? = nil,
                tone: PerformanceMetricTone,
                lineWidth: CGFloat = PerformanceTheme.Metrics.ringLineWidth) {
        self.value = value
        self.valueText = valueText
        self.label = label
        self.stateText = stateText
        self.tone = tone
        self.lineWidth = lineWidth
    }

    private var fraction: Double {
        guard let value, value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    public var body: some View {
        VStack(spacing: PerformanceTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(PerformanceTheme.subtleDivider, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: drawnFraction)
                    .stroke(tone.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(valueText)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                        .monospacedDigit()
                        .foregroundStyle(PerformanceTheme.primaryText)
                    if let stateText {
                        Text(stateText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PerformanceTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(lineWidth + 4)
            }
            .aspectRatio(1, contentMode: .fit)

            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(PerformanceTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(accessibilityValue)
        .onAppear {
            if reduceMotion {
                drawnFraction = fraction
            } else {
                withAnimation(PerformanceTheme.Motion.transition(reduceMotion: false)) {
                    drawnFraction = fraction
                }
            }
        }
        .onChange(of: fraction) { next in
            withAnimation(PerformanceTheme.Motion.transition(reduceMotion: reduceMotion)) {
                drawnFraction = next
            }
        }
    }

    private var accessibilityValue: Text {
        if let stateText {
            return Text(valueText) + Text(", ") + Text(stateText)
        } else {
            return Text(valueText)
        }
    }
}

public struct MetricHero<Supporting: View>: View {
    private let label: LocalizedStringKey
    private let value: String
    private let state: LocalizedStringKey?
    private let tone: PerformanceMetricTone
    private let fraction: Double?
    private let supporting: Supporting

    public init(label: LocalizedStringKey,
                value: String,
                state: LocalizedStringKey? = nil,
                tone: PerformanceMetricTone,
                fraction: Double? = nil,
                @ViewBuilder supporting: () -> Supporting) {
        self.label = label
        self.value = value
        self.state = state
        self.tone = tone
        self.fraction = fraction
        self.supporting = supporting()
    }

    public var body: some View {
        PerformanceCard {
            VStack(spacing: PerformanceTheme.Spacing.md) {
                MetricRing(
                    value: fraction,
                    valueText: value,
                    label: label,
                    stateText: state,
                    tone: tone,
                    lineWidth: 12
                )
                .frame(maxWidth: 230)
                supporting
            }
            .frame(maxWidth: .infinity)
        }
    }
}

public extension MetricHero where Supporting == EmptyView {
    init(label: LocalizedStringKey,
         value: String,
         state: LocalizedStringKey? = nil,
         tone: PerformanceMetricTone,
         fraction: Double? = nil) {
        self.init(label: label, value: value, state: state, tone: tone, fraction: fraction) {
            EmptyView()
        }
    }
}

// MARK: - Status and actions

public struct StatusPill: View {
    private let text: LocalizedStringKey
    private let tone: PerformanceMetricTone
    private let symbol: String?

    public init(_ text: LocalizedStringKey,
                tone: PerformanceMetricTone = .neutral,
                symbol: String? = nil) {
        self.text = text
        self.tone = tone
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(tone.color.opacity(0.12), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(tone.color.opacity(0.28), lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }
}

public struct PerformanceButtonStyle: ButtonStyle {
    public enum Role {
        case primary
        case secondary
        case destructive
    }

    private let role: Role

    public init(role: Role = .primary) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PerformanceTheme.Metrics.minimumTapTarget)
            .padding(.horizontal, PerformanceTheme.Spacing.md)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1),
                        in: RoundedRectangle(cornerRadius: PerformanceTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PerformanceTheme.Radius.medium, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.75)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }

    private var foreground: Color {
        switch role {
        case .primary: .white
        case .secondary: PerformanceTheme.primaryText
        case .destructive: PerformanceTheme.critical
        }
    }

    private var background: Color {
        switch role {
        case .primary: PerformanceTheme.effort
        case .secondary: PerformanceTheme.secondarySurface
        case .destructive: PerformanceTheme.critical.opacity(0.12)
        }
    }

    private var border: Color {
        switch role {
        case .primary: PerformanceTheme.effort.opacity(0.8)
        case .secondary: PerformanceTheme.subtleDivider
        case .destructive: PerformanceTheme.critical.opacity(0.35)
        }
    }
}

public extension ButtonStyle where Self == PerformanceButtonStyle {
    static var performancePrimary: PerformanceButtonStyle { .init(role: .primary) }
    static var performanceSecondary: PerformanceButtonStyle { .init(role: .secondary) }
    static var performanceDestructive: PerformanceButtonStyle { .init(role: .destructive) }
}

public struct EmptyStateCard: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let symbol: String

    public init(title: LocalizedStringKey,
                message: LocalizedStringKey,
                symbol: String = "chart.bar.xaxis") {
        self.title = title
        self.message = message
        self.symbol = symbol
    }

    public var body: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(PerformanceTheme.tertiaryText)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PerformanceTheme.primaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PerformanceTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct ErrorStateCard: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey

    public init(title: LocalizedStringKey, message: LocalizedStringKey) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        PerformanceCard {
            HStack(alignment: .top, spacing: PerformanceTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PerformanceTheme.critical)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PerformanceTheme.primaryText)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Root navigation

public struct PerformanceNavigationItem: Identifiable {
    public let tag: Int
    public let title: LocalizedStringKey
    public let icon: String
    public var id: Int { tag }

    public init(tag: Int, title: LocalizedStringKey, icon: String) {
        self.tag = tag
        self.title = title
        self.icon = icon
    }
}

/// Compact four-destination root dock. The app supplies the real selection and
/// routes; this component owns presentation only.
public struct PerformanceNavigationDock: View {
    @Binding private var selection: Int
    private let items: [PerformanceNavigationItem]
    private let onReselect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selection: Binding<Int>,
                items: [PerformanceNavigationItem],
                onReselect: @escaping (Int) -> Void = { _ in }) {
        precondition(items.count == 4, "The performance root dock requires exactly four destinations.")
        self._selection = selection
        self.items = items
        self.onReselect = onReselect
    }

    public var body: some View {
        HStack(spacing: 1) {
            ForEach(items) { item in
                button(item)
            }
        }
        .padding(4)
        .frame(height: 58)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(PerformanceTheme.primarySurface.opacity(0.94)))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(PerformanceTheme.subtleDivider.opacity(0.9), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.24), radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .contain)
    }

    private func button(_ item: PerformanceNavigationItem) -> some View {
        let active = selection == item.tag
        return Button {
            if active {
                onReselect(item.tag)
            } else {
                withAnimation(PerformanceTheme.Motion.transition(reduceMotion: reduceMotion)) {
                    selection = item.tag
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: active ? .semibold : .regular))
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.system(size: 9, weight: active ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .foregroundStyle(active ? PerformanceTheme.primaryText : PerformanceTheme.tertiaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PerformanceTheme.Radius.medium, style: .continuous)
                    .fill(active ? PerformanceTheme.raisedSurface : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: PerformanceTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 50)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

/// The separate circular action adjacent to the navigation dock. It intentionally
/// carries an original NOOP sparkle, not another product's logo.
public struct CoachFloatingAction: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(PerformanceTheme.primarySurface.opacity(0.96))
                Circle()
                    .strokeBorder(PerformanceTheme.coach.opacity(0.9), lineWidth: 1.5)
                    .padding(5)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PerformanceTheme.primaryText)
            }
            .frame(width: 58, height: 58)
            .shadow(color: .black.opacity(0.24), radius: 7, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .frame(minWidth: PerformanceTheme.Metrics.minimumTapTarget,
               minHeight: PerformanceTheme.Metrics.minimumTapTarget)
        .accessibilityLabel(Text("AI Coach"))
        .accessibilityHint(Text("Opens your coach"))
    }
}
