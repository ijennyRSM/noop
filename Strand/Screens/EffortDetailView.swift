import SwiftUI
import StrandDesign
import StrandAnalytics
import WhoopStore

/// Presentation-only detail for NOOP Cardiovascular Effort. It reads the same
/// daily rows and workout cache as Today and never recalculates stored scores.
struct EffortDetailView: View {
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.effortScaleKey) private var effortScaleRaw = EffortScale.hundred.rawValue
    @State private var recentWorkouts: [WorkoutRow] = []

    private var scale: EffortScale { UnitPrefs.resolveEffortScale(effortScaleRaw) }
    private var today: DailyMetric? { repo.today }
    private var effort100: Double? { today?.strain }
    private var displayedEffort: String {
        effort100.map { UnitFormatter.effortDisplay($0, scale: scale) } ?? "–"
    }
    private var scaleMaximum: Double { scale == .whoop ? 21 : 100 }

    var body: some View {
        ScreenScaffold(title: "Effort", subtitle: "Cardiovascular load accumulated today",
                       onRefresh: { await repo.refresh() }) {
            MetricHero(label: "Effort",
                       value: displayedEffort,
                       state: effortBand,
                       tone: .effort,
                       fraction: effort100.map { min(max($0 / 100, 0), 1) }) {
                Text(scale == .whoop ? "0–21 display scale" : "0–100 NOOP scale")
                    .font(.footnote)
                    .foregroundStyle(PerformanceTheme.secondaryText)
            }

            sevenDayCard
            contributingWorkouts
            zoneCard
        }
        .task(id: repo.refreshSeq) {
            recentWorkouts = await repo.workoutRows(days: 7)
        }
    }

    private var effortBand: LocalizedStringKey? {
        guard let value = effort100 else { return nil }
        switch value {
        case ..<30: return "Light"
        case ..<55: return "Moderate"
        case ..<75: return "Strenuous"
        default: return "High"
        }
    }

    private var sevenDayCard: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: 14) {
                PerformanceSectionHeader("Past 7 days", subtitle: "Daily Cardiovascular Effort")
                let days = Array(repo.days.suffix(7))
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(days, id: \.day) { day in
                        VStack(spacing: 5) {
                            GeometryReader { proxy in
                                let fraction = min(max((day.strain ?? 0) / 100, 0), 1)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PerformanceTheme.effort.opacity(day.strain == nil ? 0.12 : 0.85))
                                    .frame(height: max(3, proxy.size.height * fraction))
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            Text(shortDay(day.day))
                                .font(.caption2)
                                .foregroundStyle(PerformanceTheme.tertiaryText)
                        }
                    }
                }
                .frame(height: 92)
                Text(days.isEmpty ? String(localized: "Not enough data yet")
                                  : String(localized: "Each bar is one stored daily Effort score."))
                    .font(.footnote)
                    .foregroundStyle(PerformanceTheme.secondaryText)
            }
        }
    }

    private var contributingWorkouts: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: 0) {
                PerformanceSectionHeader("Contributing workouts",
                                         subtitle: "Sessions already included in daily Effort")
                    .padding(.bottom, 8)
                if recentWorkouts.isEmpty {
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .padding(.vertical, 18)
                } else {
                    ForEach(Array(recentWorkouts.prefix(4)), id: \.startTs) { workout in
                        NavigationLink(value: TabRoute.workoutDetail(startTs: workout.startTs,
                                                                     sport: workout.sport)) {
                            PerformanceListRow(
                                LocalizedStringKey(WorkoutSource.displaySport(workout.sport)),
                                subtitle: LocalizedStringKey(workoutDuration(workout)),
                                icon: "figure.run",
                                tint: PerformanceTheme.effort
                            ) {
                                Text(workout.strain.map { UnitFormatter.effortDisplay($0, scale: scale) } ?? "–")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(PerformanceTheme.primaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(PerformanceTheme.subtleDivider)
                    }
                }
            }
        }
    }

    private var zoneCard: some View {
        let summary = WorkoutZones.summary(from: recentWorkouts)
        return PerformanceCard {
            VStack(alignment: .leading, spacing: 12) {
                PerformanceSectionHeader("Heart-rate zones",
                                         subtitle: "Duration from workouts with zone data")
                if let summary {
                    ForEach(0..<5, id: \.self) { index in
                        HStack(spacing: 9) {
                            Text("Z\(index + 1)")
                                .font(.caption.weight(.bold))
                                .frame(width: 24, alignment: .leading)
                            GeometryReader { proxy in
                                let fraction = summary.totalMinutes > 0
                                    ? summary.minutes[index] / summary.totalMinutes : 0
                                Capsule()
                                    .fill(StrandPalette.hrZoneColor(index + 1))
                                    .frame(width: max(2, proxy.size.width * fraction))
                            }
                            .frame(height: 7)
                            Text(duration(summary.minutes[index]))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(PerformanceTheme.secondaryText)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                } else {
                    Text("Heart-rate zone data is unavailable for these workouts.")
                        .font(.subheadline)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                }
            }
        }
    }

    private func shortDay(_ key: String) -> String {
        String(key.suffix(2))
    }

    private func workoutDuration(_ row: WorkoutRow) -> String {
        duration((row.durationS ?? Double(max(0, row.endTs - row.startTs))) / 60)
    }

    private func duration(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        let h = rounded / 60
        let m = rounded % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }
}
