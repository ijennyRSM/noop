import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

@MainActor
private final class MuscleBodyMapModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case residual, today, week
        var id: String { rawValue }
        var title: String {
            switch self {
            case .residual: String(localized: "Residual")
            case .today: String(localized: "Today")
            case .week: String(localized: "7 days")
            }
        }
    }

    struct MuscleSummary: Identifiable {
        var id: String { muscle.rawValue }
        let muscle: NOOPMuscle
        var today: Double = 0
        var week: Double = 0
        var residual: Double = 0
        var workingSets: Int = 0
        var lastTrainedAt: Date?
        var confidence: StrengthConfidence = .low
        var exercises: [String] = []

        func value(for mode: Mode) -> Double {
            switch mode { case .today: today; case .week: week; case .residual: residual }
        }
    }

    @Published var mode: Mode = .residual
    @Published var summaries: [String: MuscleSummary] = [:]
    @Published var selected: MuscleSummary?
    @Published var loading = false

    func load(repository: Repository) async {
        loading = true
        defer { loading = false }
        guard let store = await repository.storeHandle() else { return }
        let now = Date()
        let todayKey = Repository.localDayKey(now)
        let daily = (try? await store.dailyMuscleLoads(
            deviceId: repository.deviceId, from: todayKey, to: todayKey)) ?? []
        let historyStart = Calendar.current.date(
            byAdding: .day, value: -35,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(-35 * 86_400)
        let history = (try? await store.historicalMuscleLoads(
            deviceId: repository.deviceId,
            from: Int(historyStart.timeIntervalSince1970)
        )) ?? []
        let weekly = WeeklyMuscleLoadEngine.aggregate(rows: history, now: now)
        let residual = await CurrentMuscleResidualService.shared.currentLoads(
            store: store,
            deviceId: repository.deviceId,
            now: now,
            refreshToken: repository.refreshSeq,
            recovery: .init(
                sleepHours: repository.today?.totalSleepMin.map { $0 / 60 },
                charge: repository.today?.recovery
            )
        )
        let sessions = (try? await store.strengthSessions(deviceId: repository.deviceId, limit: 30)) ?? []

        var output = Dictionary(uniqueKeysWithValues: NOOPMuscle.allCases.map {
            ($0.rawValue, MuscleSummary(muscle: $0))
        })
        for row in daily {
            guard var summary = output[row.muscleId] else { continue }
            summary.today = max(summary.today, row.normalizedLoad)
            summary.workingSets += row.workingSets
            summary.confidence = confidence(row.confidence)
            output[row.muscleId] = summary
        }
        for row in weekly {
            guard var summary = output[row.muscleId] else { continue }
            summary.week = max(summary.week, row.normalizedLoad)
            summary.confidence = row.confidence
            output[row.muscleId] = summary
        }
        for row in residual {
            guard var summary = output[row.muscleId] else { continue }
            summary.residual = max(summary.residual, row.residualLoad)
            summary.lastTrainedAt = row.lastTrainedAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            summary.confidence = confidence(row.confidence)
            output[row.muscleId] = summary
        }
        for session in sessions {
            for item in session.exercises {
                guard let definition = try? await store.exerciseDefinition(id: item.exerciseId) else {
                    continue
                }
                for mapping in definition.muscles {
                    guard var summary = output[mapping.muscleId] else { continue }
                    if !summary.exercises.contains(item.snapshotName) {
                        summary.exercises.append(item.snapshotName)
                        summary.exercises = Array(summary.exercises.prefix(3))
                    }
                    if summary.lastTrainedAt == nil {
                        summary.lastTrainedAt = Date(
                            timeIntervalSince1970: TimeInterval(session.startedAt))
                    }
                    output[mapping.muscleId] = summary
                }
            }
        }
        summaries = output
        if let selected { self.selected = output[selected.id] }
    }

    private func confidence(_ raw: String) -> StrengthConfidence {
        StrengthConfidence(rawValue: raw) ?? .low
    }
}

struct MuscleBodyMapCard: View {
    @EnvironmentObject private var repository: Repository
    @StateObject private var model = MuscleBodyMapModel()
    @State private var bodySide: AnatomicalMuscleMap.Side
    @State private var showingCheckIn = false

    init(initialSide: AnatomicalMuscleMap.Side = .front) {
        _bodySide = State(initialValue: initialSide)
    }

    var body: some View {
        NoopCard(padding: NoopMetrics.cardPadding, tint: StrandPalette.metricCyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MUSCLE MAP")
                            .font(StrandFont.overline)
                            .tracking(StrandFont.overlineTracking)
                            .foregroundStyle(StrandPalette.metricCyan)
                        Text("Estimated muscular load")
                            .font(StrandFont.title1)
                            .tracking(-0.35)
                            .foregroundStyle(StrandPalette.textPrimary)
                    }
                    Spacer()
                    if model.loading { ProgressView().controlSize(.small) }
                }
                Picker("Muscle map range", selection: $model.mode) {
                    ForEach(MuscleBodyMapModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    ForEach(AnatomicalMuscleMap.Side.allCases) { side in
                        Button {
                            withAnimation(.snappy(duration: 0.24)) { bodySide = side }
                        } label: {
                            Text(side.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    bodySide == side ? Color.black : StrandPalette.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            bodySide == side
                                                ? Color.white
                                                : Color.white.opacity(0.055)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.28)))

                VStack(spacing: 10) {
                    AnatomicalMuscleMap(
                        side: bodySide,
                        values: muscleValues,
                        onSelect: select
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 390)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.055), lineWidth: 1)
                        )
                )

                legend
                PR3SectionLabel("HIGHEST LOAD")
                if strongestMuscles.isEmpty {
                    Text("No training load yet")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 10) {
                        ForEach(strongestMuscles) { summary in
                            muscleLoadRow(summary)
                        }
                    }
                }
                Button {
                    showingCheckIn = true
                } label: {
                    Label("Soreness", systemImage: "figure.mind.and.body")
                }
                .buttonStyle(PR3PrimaryButtonStyle())
                Text("Estimated from logged training. Colors are not direct measurements of muscle activation, damage, inflammation, or injury risk.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: repository.refreshSeq) { await model.load(repository: repository) }
        .sheet(item: $model.selected) { summary in
            NavigationStack {
                MuscleLoadDetail(summary: summary)
            }
            .strengthSheetPresentation(largeFirst: false)
        }
        .sheet(isPresented: $showingCheckIn) {
            SorenessCheckInSheet()
                .environmentObject(repository)
                .strengthSheetPresentation(largeFirst: true)
        }
    }

    private var muscleValues: [NOOPMuscle: Double] {
        Dictionary(uniqueKeysWithValues: model.summaries.values.map {
            ($0.muscle, $0.value(for: model.mode))
        })
    }

    private var strongestMuscles: [MuscleBodyMapModel.MuscleSummary] {
        Array(
            model.summaries.values
                .filter { $0.value(for: model.mode) > 0 }
                .sorted { $0.value(for: model.mode) > $1.value(for: model.mode) }
                .prefix(5)
        )
    }

    private func select(_ muscle: NOOPMuscle) {
        model.selected = model.summaries[muscle.rawValue]
            ?? .init(muscle: muscle)
    }

    private func muscleLoadRow(
        _ summary: MuscleBodyMapModel.MuscleSummary
    ) -> some View {
        let value = summary.value(for: model.mode)
        return Button {
            model.selected = summary
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(summary.muscle.localizedName)
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 2)
                    Text("\(Int(value.rounded()))")
                        .font(StrandFont.number(17))
                        .foregroundStyle(MuscleLoadColorScale.color(value))
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(MuscleLoadColorScale.color(value))
                            .frame(width: geometry.size.width * min(1, value / 100))
                    }
                }
                .frame(height: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: summary.muscle.localizedName))
        .accessibilityValue(Text(verbatim: String(Int(value.rounded()))))
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(String(localized: "No data"), color: MuscleLoadColorScale.color(0))
            legendItem(String(localized: "Low"), color: MuscleLoadColorScale.color(10))
            legendItem(String(localized: "Moderate"), color: MuscleLoadColorScale.color(35))
            legendItem(String(localized: "High"), color: MuscleLoadColorScale.color(60))
            legendItem(String(localized: "Very high"), color: MuscleLoadColorScale.color(85))
        }
        .font(StrandFont.footnote)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).foregroundStyle(StrandPalette.textSecondary)
        }
    }
}

private struct MuscleFigure: View {
    enum Side { case front, back }
    let side: Side
    let summaries: [String: MuscleBodyMapModel.MuscleSummary]
    let mode: MuscleBodyMapModel.Mode
    let select: (MuscleBodyMapModel.MuscleSummary) -> Void

    private struct Region: Identifiable {
        let id: String
        let muscle: NOOPMuscle
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Text(side == .front ? "FRONT" : "BACK")
                    .font(StrandFont.overline)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .position(x: geometry.size.width / 2, y: 10)
                ForEach(regions) { region in
                    let summary = summaries[region.muscle.rawValue]
                        ?? .init(muscle: region.muscle)
                    Button {
                        select(summary)
                    } label: {
                        Capsule(style: .continuous)
                            .fill(color(summary.value(for: mode)))
                            .overlay(Capsule().strokeBorder(StrandPalette.hairline, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .frame(width: region.width * geometry.size.width,
                           height: region.height * geometry.size.height)
                    .rotationEffect(.degrees(region.rotation))
                    .position(x: region.x * geometry.size.width,
                              y: region.y * geometry.size.height)
                    .accessibilityLabel(
                        "\(region.muscle.localizedName), \(level(summary.value(for: mode))) estimated load")
                    .accessibilityHint("Opens muscle load details")
                }
            }
        }
    }

    private var regions: [Region] {
        let sharedLegs: [Region] = [
            .init(id: "l_quad", muscle: side == .front ? .quadriceps : .hamstrings,
                  x: 0.40, y: 0.68, width: 0.15, height: 0.23, rotation: 3),
            .init(id: "r_quad", muscle: side == .front ? .quadriceps : .hamstrings,
                  x: 0.60, y: 0.68, width: 0.15, height: 0.23, rotation: -3),
            .init(id: "l_calf", muscle: .calves, x: 0.42, y: 0.87,
                  width: 0.12, height: 0.18, rotation: 3),
            .init(id: "r_calf", muscle: .calves, x: 0.58, y: 0.87,
                  width: 0.12, height: 0.18, rotation: -3),
        ]
        if side == .front {
            return [
                .init(id: "l_delt", muscle: .frontDelts, x: 0.29, y: 0.25,
                      width: 0.16, height: 0.10, rotation: -20),
                .init(id: "r_delt", muscle: .frontDelts, x: 0.71, y: 0.25,
                      width: 0.16, height: 0.10, rotation: 20),
                .init(id: "l_chest", muscle: .chest, x: 0.41, y: 0.30,
                      width: 0.18, height: 0.12, rotation: -6),
                .init(id: "r_chest", muscle: .chest, x: 0.59, y: 0.30,
                      width: 0.18, height: 0.12, rotation: 6),
                .init(id: "l_biceps", muscle: .biceps, x: 0.24, y: 0.39,
                      width: 0.10, height: 0.18, rotation: 12),
                .init(id: "r_biceps", muscle: .biceps, x: 0.76, y: 0.39,
                      width: 0.10, height: 0.18, rotation: -12),
                .init(id: "abs", muscle: .abdominals, x: 0.50, y: 0.43,
                      width: 0.20, height: 0.25, rotation: 0),
                .init(id: "l_oblique", muscle: .obliques, x: 0.36, y: 0.46,
                      width: 0.09, height: 0.20, rotation: 8),
                .init(id: "r_oblique", muscle: .obliques, x: 0.64, y: 0.46,
                      width: 0.09, height: 0.20, rotation: -8),
                .init(id: "l_adductor", muscle: .adductors, x: 0.47, y: 0.65,
                      width: 0.08, height: 0.19, rotation: -5),
                .init(id: "r_adductor", muscle: .adductors, x: 0.53, y: 0.65,
                      width: 0.08, height: 0.19, rotation: 5),
                .init(id: "l_tib", muscle: .tibialis, x: 0.37, y: 0.88,
                      width: 0.06, height: 0.16, rotation: 3),
                .init(id: "r_tib", muscle: .tibialis, x: 0.63, y: 0.88,
                      width: 0.06, height: 0.16, rotation: -3),
            ] + sharedLegs
        }
        return [
            .init(id: "traps", muscle: .traps, x: 0.50, y: 0.23,
                  width: 0.27, height: 0.12, rotation: 0),
            .init(id: "l_rear", muscle: .rearDelts, x: 0.28, y: 0.28,
                  width: 0.15, height: 0.10, rotation: -18),
            .init(id: "r_rear", muscle: .rearDelts, x: 0.72, y: 0.28,
                  width: 0.15, height: 0.10, rotation: 18),
            .init(id: "l_upper", muscle: .upperBack, x: 0.41, y: 0.34,
                  width: 0.17, height: 0.16, rotation: -4),
            .init(id: "r_upper", muscle: .upperBack, x: 0.59, y: 0.34,
                  width: 0.17, height: 0.16, rotation: 4),
            .init(id: "l_lats", muscle: .lats, x: 0.36, y: 0.43,
                  width: 0.14, height: 0.23, rotation: 8),
            .init(id: "r_lats", muscle: .lats, x: 0.64, y: 0.43,
                  width: 0.14, height: 0.23, rotation: -8),
            .init(id: "lower", muscle: .lowerBack, x: 0.50, y: 0.49,
                  width: 0.20, height: 0.18, rotation: 0),
            .init(id: "l_tri", muscle: .triceps, x: 0.23, y: 0.39,
                  width: 0.09, height: 0.18, rotation: 12),
            .init(id: "r_tri", muscle: .triceps, x: 0.77, y: 0.39,
                  width: 0.09, height: 0.18, rotation: -12),
            .init(id: "l_glute", muscle: .glutes, x: 0.42, y: 0.57,
                  width: 0.18, height: 0.15, rotation: -5),
            .init(id: "r_glute", muscle: .glutes, x: 0.58, y: 0.57,
                  width: 0.18, height: 0.15, rotation: 5),
        ] + sharedLegs
    }

    private func color(_ value: Double) -> Color {
        switch value {
        case 75...: StrandPalette.metricRose
        case 50..<75: StrandPalette.statusWarning
        case 25..<50: StrandPalette.sleepLight
        case 0.01..<25: StrandPalette.accent
        default: StrandPalette.textTertiary.opacity(0.22)
        }
    }

    private func level(_ value: Double) -> String {
        switch value {
        case 75...: String(localized: "Very high")
        case 50..<75: String(localized: "High")
        case 25..<50: String(localized: "Moderate")
        case 0.01..<25: String(localized: "Low")
        default: String(localized: "No data")
        }
    }
}

private struct MuscleLoadDetail: View {
    @Environment(\.dismiss) private var dismiss
    let summary: MuscleBodyMapModel.MuscleSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(summary.muscle.localizedName)
                    .font(StrandFont.title1)
                    .foregroundStyle(StrandPalette.textPrimary)
                metric("Today's estimated load", summary.today)
                metric("7-day estimated load", summary.week)
                metric("Estimated residual load", summary.residual)
                detailRow("Last trained", lastTrained)
                detailRow("Working sets today", "\(summary.workingSets)")
                detailRow("Confidence", summary.confidence.rawValue.capitalized)
                if !summary.exercises.isEmpty {
                    Text("Main contributing exercises")
                        .font(StrandFont.headline)
                    ForEach(summary.exercises, id: \.self) { Text("• \($0)") }
                }
                Text("This is a conservative estimate based on logged training and recovery data. It is not a direct measurement and is not medical advice.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .screenPadding()
        }
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
        .navigationTitle("Muscle details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    private func metric(_ title: String, _ value: Double) -> some View {
        let displayValue = value > 0 ? "\(Int(value.rounded()))/100" : "—"
        return NoopCard {
            HStack {
                Text(title).foregroundStyle(StrandPalette.textSecondary)
                Spacer()
                Text(verbatim: displayValue)
                    .font(StrandFont.number(24))
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(StrandPalette.textSecondary)
            Spacer()
            Text(value).foregroundStyle(StrandPalette.textPrimary)
        }
    }

    private var lastTrained: String {
        guard let date = summary.lastTrainedAt else { return String(localized: "No data") }
        return date.formatted(.relative(presentation: .named))
    }
}

#if DEBUG
struct MuscleLoadDetailDemoHost: View {
    var body: some View {
        MuscleLoadDetail(summary: summary)
    }

    private var summary: MuscleBodyMapModel.MuscleSummary {
        var value = MuscleBodyMapModel.MuscleSummary(muscle: .quadriceps)
        value.today = 67
        value.week = 82
        value.residual = 43
        value.workingSets = 8
        value.lastTrainedAt = Date().addingTimeInterval(-19 * 3_600)
        value.confidence = .high
        value.exercises = ["Back Squat", "Bulgarian Split Squat"]
        return value
    }
}
#endif

/// Optional local-only soreness and pain check-in. This is deliberately a
/// presentation over `LocalCoachPreferences`; it does not create another
/// profile/check-in store. Pain remains a separate field and never becomes
/// muscular load.
struct SorenessCheckInSheet: View {
    @EnvironmentObject private var repository: Repository
    @Environment(\.dismiss) private var dismiss
    @State private var overall = 0
    @State private var perMuscle: [String: Int] = [:]
    @State private var note = ""
    @State private var painPresent = false
    @State private var painNote = ""
    @State private var hasExisting = false

    init(initialPainPresent: Bool = false) {
        _painPresent = State(initialValue: initialPainPresent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NoopMetrics.sectionGap) {
                    PR3PageHeading(
                        "Coach profile & check-in",
                        overline: "OPTIONAL CHECK-IN"
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Overall soreness")
                                .font(StrandFont.headline)
                            Spacer()
                            Text(verbatim: "\(overall)/10")
                                .font(StrandFont.number(28))
                                .foregroundStyle(sorenessColor(overall))
                        }
                        Slider(
                            value: Binding(
                                get: { Double(overall) },
                                set: { overall = Int($0.rounded()) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(sorenessColor(overall))
                    }
                    .padding(14)
                    .background(
                        StrandPalette.surfaceRaised,
                        in: RoundedRectangle(
                            cornerRadius: NoopMetrics.cardRadius,
                            style: .continuous
                        )
                    )

                    DisclosureGroup {
                        VStack(spacing: 0) {
                            ForEach(NOOPMuscle.allCases, id: \.rawValue) { muscle in
                                muscleRow(muscle)
                                if muscle.rawValue != NOOPMuscle.allCases.last?.rawValue {
                                    Divider().overlay(StrandPalette.hairline)
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Muscles")
                            .font(StrandFont.headline)
                            .foregroundStyle(StrandPalette.textPrimary)
                    }
                    .tint(PR3SecondaryPalette.action)
                    .padding(14)
                    .background(
                        StrandPalette.surfaceRaised,
                        in: RoundedRectangle(
                            cornerRadius: NoopMetrics.cardRadius,
                            style: .continuous
                        )
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Pain or discomfort", isOn: $painPresent)
                            .font(StrandFont.headline)
                            .tint(PR3SecondaryPalette.danger)
                        Text("Pain-sensitive check-ins")
                            .font(StrandFont.footnote)
                            .foregroundStyle(PR3SecondaryPalette.danger)
                        if painPresent {
                            TextField("Notes", text: $painNote, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    StrandPalette.surfaceInset,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                    }
                    .padding(14)
                    .background(
                        PR3SecondaryPalette.danger.opacity(0.055),
                        in: RoundedRectangle(
                            cornerRadius: NoopMetrics.cardRadius,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: NoopMetrics.cardRadius,
                            style: .continuous
                        )
                        .strokeBorder(PR3SecondaryPalette.danger.opacity(0.32), lineWidth: 1)
                    )

                    TextField("Notes", text: $note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            StrandPalette.surfaceRaised,
                            in: RoundedRectangle(
                                cornerRadius: NoopMetrics.cardRadius,
                                style: .continuous
                            )
                        )

                    Button("Save") { save() }
                        .buttonStyle(PR3PrimaryButtonStyle())

                    if hasExisting {
                        Button("Delete check-in", role: .destructive) {
                            LocalCoachPreferences.saveCheckIn(nil)
                            invalidateResidual()
                            dismiss()
                        }
                        .font(StrandFont.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .screenPadding()
                .padding(.vertical, 16)
            }
            .background(StrandPalette.surfaceBase.ignoresSafeArea())
            .navigationTitle("Soreness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func muscleRow(_ muscle: NOOPMuscle) -> some View {
        HStack(spacing: 10) {
            Text(muscle.localizedName)
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textPrimary)
            Spacer()
            Button {
                perMuscle[muscle.rawValue] = max(
                    0, (perMuscle[muscle.rawValue] ?? overall) - 1
                )
            } label: {
                Image(systemName: "minus")
                    .frame(width: 36, height: 36)
                    .background(StrandPalette.surfaceInset, in: Circle())
            }
            .buttonStyle(.plain)
            Text(verbatim: "\(perMuscle[muscle.rawValue] ?? overall)")
                .font(StrandFont.number(20))
                .frame(width: 30)
            Button {
                perMuscle[muscle.rawValue] = min(
                    10, (perMuscle[muscle.rawValue] ?? overall) + 1
                )
            } label: {
                Image(systemName: "plus")
                    .frame(width: 36, height: 36)
                    .background(StrandPalette.surfaceInset, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    private func load() {
        guard let value = LocalCoachPreferences.loadCheckIn() else { return }
        hasExisting = true
        overall = value.overallSoreness ?? 0
        perMuscle = value.perMuscleSoreness
        note = value.note
        painPresent = value.painPresent ?? false
        painNote = value.painNote
    }

    private func save() {
        LocalCoachPreferences.saveCheckIn(.init(
            overallSoreness: overall,
            perMuscleSoreness: perMuscle,
            recordedAt: Date(),
            note: note,
            painPresent: painPresent,
            painNote: painPresent ? painNote : ""
        ))
        invalidateResidual()
        dismiss()
    }

    private func invalidateResidual() {
        Task {
            await CurrentMuscleResidualService.shared.invalidate(
                deviceId: repository.deviceId
            )
        }
    }

    private func sorenessColor(_ value: Int) -> Color {
        switch value {
        case 8...: PR3SecondaryPalette.danger
        case 5...: PR3SecondaryPalette.warning
        default: PR3SecondaryPalette.action
        }
    }
}
