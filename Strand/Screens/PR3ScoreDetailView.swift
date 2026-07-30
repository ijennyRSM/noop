import SwiftUI
import StrandDesign
import StrandAnalytics
import WhoopStore

/// Screen-specific detail presentation for Milestone 1 of the PR #3 visual port.
/// Repository values remain the sole source of truth; this type performs no scoring or persistence.
enum PR3ScoreMetric: String, Identifiable {
    case charge
    case rest
    case effort

    var id: String { rawValue }
}

struct PR3ScoreDetailView: View {
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.effortScaleKey) private var effortScaleRaw = EffortScale.hundred.rawValue

    let metric: PR3ScoreMetric

    private var effortScale: EffortScale { UnitPrefs.resolveEffortScale(effortScaleRaw) }
    private var day: DailyMetric? { repo.today }

    private var score: Double? {
        switch metric {
        case .charge:
            return day?.recovery
        case .rest:
            guard let day else { return nil }
            return repo.importedSleep[day.day]?.performancePct ?? AnalyticsEngine.Rest.composite(daily: day)
        case .effort:
            return day?.strain.map { UnitFormatter.effortValue($0, scale: effortScale) }
        }
    }

    private var maximum: Double {
        metric == .effort && effortScale == .whoop ? 21 : 100
    }

    private var title: LocalizedStringKey {
        switch metric {
        case .charge: return "Charge"
        case .rest: return "Rest"
        case .effort: return "Effort"
        }
    }

    private var overline: LocalizedStringKey {
        switch metric {
        case .charge: return "RECOVERY"
        case .rest: return "SLEEP PERFORMANCE"
        case .effort: return "DAY STRAIN"
        }
    }

    private var tint: Color {
        switch metric {
        case .charge: return PR3ScorePalette.charge(score)
        case .rest: return PR3ScorePalette.rest
        case .effort: return PR3ScorePalette.effort
        }
    }

    private var state: String {
        guard let score else { return String(localized: "Calibrating") }
        switch metric {
        case .charge:
            if score <= 33 { return String(localized: "Rest") }
            if score <= 66 { return String(localized: "Maintain") }
            return String(localized: "Push")
        case .rest:
            if score < 50 { return String(localized: "Poor") }
            if score < 70 { return String(localized: "Fair") }
            if score < 85 { return String(localized: "Good") }
            return String(localized: "Optimal")
        case .effort:
            let normalized = score / maximum
            if normalized < 0.3 { return String(localized: "Light") }
            if normalized < 0.65 { return String(localized: "Moderate") }
            return String(localized: "High")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text(overline)
                        .font(StrandFont.overline)
                        .tracking(1.6)
                        .foregroundStyle(StrandPalette.textSecondary)
                    Text(title)
                        .font(StrandFont.title1)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                .padding(.top, 12)

                detailRing

                HStack(spacing: 12) {
                    detailTile("STATUS", state, tint: tint)
                    detailTile("SOURCE", sourceLabel, tint: StrandPalette.textPrimary)
                }

                supportingCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailRing: some View {
        ZStack {
            Circle()
                .stroke(PR3ScorePalette.track, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0, min(1, (score ?? 0) / maximum)))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(scoreText)
                        .font(StrandFont.display(metric == .effort ? 68 : 76))
                        .tracking(StrandFont.displayTracking(metric == .effort ? 68 : 76))
                    if metric != .effort, score != nil {
                        Text("%")
                            .font(StrandFont.rounded(32))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .foregroundStyle(.white)
                Text(state.uppercased())
                    .font(StrandFont.overline)
                    .tracking(1.4)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 244, height: 244)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(scoreText))
    }

    private var scoreText: String {
        guard let score else { return "–" }
        if metric == .effort, effortScale == .whoop { return String(format: "%.1f", score) }
        return String(Int(score.rounded()))
    }

    private var sourceLabel: String {
        switch metric {
        case .charge, .effort: return String(localized: "On-device")
        case .rest:
            guard let key = day?.day else { return String(localized: "On-device") }
            return repo.importedSleep[key]?.performancePct != nil ? "WHOOP" : String(localized: "On-device")
        }
    }

    private func detailTile(_ label: LocalizedStringKey, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(StrandFont.overline)
                .tracking(1.2)
                .foregroundStyle(StrandPalette.textTertiary)
            Text(value)
                .font(StrandFont.rounded(22))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(hex: "#2B3136")))
    }

    private var supportingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(StrandFont.overline)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(StrandPalette.textSecondary)
            Text(supportingSummary)
                .font(StrandFont.body)
                .foregroundStyle(StrandPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let values = trendValues, values.count > 1 {
                Sparkline(values: values,
                          gradient: Gradient(colors: [tint.opacity(0.4), tint]))
                    .frame(height: 72)
                    .accessibilityHidden(true)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(hex: "#292E33")))
    }

    private var supportingSummary: String {
        guard score != nil else {
            return String(localized: "Wear your device to build this score.")
        }
        switch metric {
        case .charge:
            return String(localized: "Charge combines your current recovery signals with your personal baseline.")
        case .rest:
            return String(localized: "Rest reflects your sleep performance for the latest main sleep.")
        case .effort:
            return String(localized: "Effort is today's cardiovascular load. It is separate from Muscular Load.")
        }
    }

    private var trendValues: [Double]? {
        let values: [Double]
        switch metric {
        case .charge:
            values = repo.days.suffix(7).compactMap(\.recovery)
        case .rest:
            values = repo.days.suffix(7).compactMap { AnalyticsEngine.Rest.composite(daily: $0) }
        case .effort:
            values = repo.days.suffix(7).compactMap(\.strain).map {
                UnitFormatter.effortValue($0, scale: effortScale)
            }
        }
        return values
    }
}

#if DEBUG
struct PR3ScoreDetailDemoHost: View {
    let metric: PR3ScoreMetric
    var body: some View {
        NavigationStack { PR3ScoreDetailView(metric: metric) }
    }
}
#endif
