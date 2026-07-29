#if os(iOS)
import SwiftUI
import StrandDesign

/// Presentation-only Health root. Every row opens an existing authoritative screen;
/// it owns no health state and performs no calculations.
struct PerformanceHealthHubView: View {
    @EnvironmentObject private var repo: Repository

    var body: some View {
        ScreenScaffold(
            title: "Health",
            subtitle: "Your recovery, rest, effort and vital signs",
            onRefresh: { await repo.refresh() }
        ) {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.lg) {
                PerformanceMetricGrid {
                    scoreLink(
                        title: "Charge",
                        subtitle: "Readiness and recovery drivers",
                        symbol: "bolt.heart.fill",
                        tone: .charge,
                        route: .coupled
                    )
                    scoreLink(
                        title: "Rest",
                        subtitle: "Sleep, need and consistency",
                        symbol: "bed.double.fill",
                        tone: .rest,
                        route: .sleep
                    )
                    scoreLink(
                        title: "Effort",
                        subtitle: "Cardiovascular load and zones",
                        symbol: "figure.run",
                        tone: .effort,
                        route: .effortDetail
                    )
                    scoreLink(
                        title: "Health Monitor",
                        subtitle: "Vitals, ranges and sources",
                        symbol: "heart.text.square.fill",
                        tone: .charge,
                        route: .health
                    )
                }

                PerformanceSectionHeader("Monitor")
                PerformanceCard(padding: 0) {
                    VStack(spacing: 0) {
                        destinationRow(
                            "Stress Monitor",
                            subtitle: "Current state and daily pattern",
                            icon: "waveform.path.ecg",
                            tone: .warning,
                            route: .stress
                        )
                        divider
                        destinationRow(
                            "Trends",
                            subtitle: "Compare seven-day and longer ranges",
                            icon: "chart.xyaxis.line",
                            tone: .effort,
                            route: .trends
                        )
                        divider
                        destinationRow(
                            "Workouts",
                            subtitle: "Activities, Effort and heart-rate zones",
                            icon: "figure.run.circle",
                            tone: .effort,
                            route: .workouts
                        )
                    }
                }
            }
        }
    }

    private func scoreLink(title: LocalizedStringKey,
                           subtitle: LocalizedStringKey,
                           symbol: String,
                           tone: PerformanceMetricTone,
                           route: TabRoute) -> some View {
        NavigationLink(value: route) {
            PerformanceCard {
                VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
                    Image(systemName: symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tone.color)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PerformanceTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PerformanceTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 104, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens details"))
    }

    private func destinationRow(_ title: LocalizedStringKey,
                                subtitle: LocalizedStringKey,
                                icon: String,
                                tone: PerformanceMetricTone,
                                route: TabRoute) -> some View {
        NavigationLink(value: route) {
            PerformanceListRow(title, subtitle: subtitle, icon: icon, tint: tone.color) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PerformanceTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PerformanceTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(PerformanceTheme.subtleDivider)
            .frame(height: 0.75)
            .padding(.leading, 60)
    }
}

/// Truthful replacement for the reference's social tab: NOOP already owns Goals,
/// Plan Book, Journey and Updates, so the root position is named Progress.
struct PerformanceProgressHubView: View {
    @ObservedObject private var goalStore = CoachGoalStore.shared
    @ObservedObject private var planStore = CoachPlanStore.shared

    var body: some View {
        ScreenScaffold(title: "Progress", subtitle: "Goals, plans and your journey") {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.lg) {
                PerformanceCard {
                    VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
                        StatusPill(
                            progressStatus,
                            tone: goalStore.activeGoals.isEmpty ? .neutral : .charge,
                            symbol: goalStore.activeGoals.isEmpty ? "circle.dashed" : "checkmark.circle.fill"
                        )
                        Text(progressHeadline)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PerformanceTheme.primaryText)
                        Text(progressDetail)
                            .font(.subheadline)
                            .foregroundStyle(PerformanceTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PerformanceSectionHeader("Your progress")
                PerformanceCard(padding: 0) {
                    VStack(spacing: 0) {
                        progressRow(
                            "Goal & Journey",
                            subtitle: "Targets, milestones and evidence",
                            icon: "target",
                            tone: .charge,
                            route: .goalJourney
                        )
                        divider
                        progressRow(
                            "Plan Book",
                            subtitle: "Proposals, commitments and history",
                            icon: "calendar.badge.checkmark",
                            tone: .effort,
                            route: .planBook
                        )
                        divider
                        progressRow(
                            "Updates",
                            subtitle: "Changes and items that need attention",
                            icon: "tray.full.fill",
                            tone: .coach,
                            route: .updates
                        )
                    }
                }
            }
        }
    }

    private var progressStatus: LocalizedStringKey {
        goalStore.activeGoals.isEmpty ? "No active goal" : "Active"
    }

    private var progressHeadline: LocalizedStringKey {
        goalStore.activeGoals.isEmpty ? "Choose what you want to work toward" : "Your plan is in motion"
    }

    private var progressDetail: LocalizedStringKey {
        if goalStore.activeGoals.isEmpty {
            return "Set a goal when you are ready. Nothing is accepted or scheduled automatically."
        }
        if planStore.pending.isEmpty {
            return "Review your journey and open Plan Book when you want to adjust what comes next."
        }
        return "A plan proposal is waiting for your decision."
    }

    private func progressRow(_ title: LocalizedStringKey,
                             subtitle: LocalizedStringKey,
                             icon: String,
                             tone: PerformanceMetricTone,
                             route: MoreDestination) -> some View {
        NavigationLink(value: route) {
            PerformanceListRow(title, subtitle: subtitle, icon: icon, tint: tone.color) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PerformanceTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PerformanceTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(PerformanceTheme.subtleDivider)
            .frame(height: 0.75)
            .padding(.leading, 60)
    }
}
#endif
