import SwiftUI
import StrandDesign
import WhoopStore

/// Optional local check-in backed by the existing Strength integration tables.
/// Pain remains a separate record and is never converted into muscular load.
struct SorenessCheckInView: View {
    @EnvironmentObject private var repository: Repository
    @Environment(\.dismiss) private var dismiss

    @State private var overallSoreness: Int
    @State private var perMuscleSoreness: [String: Int]
    @State private var sorenessNote: String
    @State private var painPresent: Bool
    @State private var painNote: String
    @State private var sorenessRecordID: String?
    @State private var painRecordID: String?
    @State private var saving = false
    @State private var saved = false
    @State private var errorMessage: String?

    private let previewMode: Bool

    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        _overallSoreness = State(initialValue: previewMode ? 4 : -1)
        _perMuscleSoreness = State(initialValue: previewMode ? [
            NOOPMuscle.quadriceps.rawValue: 6,
            NOOPMuscle.hamstrings.rawValue: 4,
            NOOPMuscle.calves.rawValue: 3,
        ] : [:])
        _sorenessNote = State(
            initialValue: previewMode ? String(localized: "Mild tightness after leg training") : ""
        )
        _painPresent = State(initialValue: false)
        _painNote = State(initialValue: "")
    }

    var body: some View {
        ScreenScaffold(
            title: "Soreness",
            subtitle: "Soreness can modestly adjust estimated residual load."
        ) {
            overallCard
            muscleCard
            painCard
            actionCard
        }
        .task {
            guard !previewMode else { return }
            await loadLatest()
        }
    }

    private var overallCard: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.md) {
                PerformanceSectionHeader("Overall soreness")
                Picker("Overall soreness", selection: $overallSoreness) {
                    Text("Not set").tag(-1)
                    ForEach(0...10, id: \.self) { value in
                        Text(verbatim: scoreLabel(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(PerformanceTheme.charge)
                .accessibilityValue(
                    overallSoreness < 0
                        ? Text("Not set")
                        : Text(verbatim: scoreLabel(overallSoreness))
                )

                TextField("Notes", text: $sorenessNote, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        PerformanceTheme.secondarySurface,
                        in: RoundedRectangle(cornerRadius: PerformanceTheme.Radius.small)
                    )
            }
        }
    }

    private var muscleCard: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
                PerformanceSectionHeader("Muscles")
                ForEach(Array(NOOPMuscle.allCases.enumerated()), id: \.offset) { _, muscle in
                    muscleRow(muscle)
                    if muscle != NOOPMuscle.allCases.last {
                        Divider().overlay(PerformanceTheme.subtleDivider)
                    }
                }
            }
        }
    }

    private func muscleRow(_ muscle: NOOPMuscle) -> some View {
        let value = perMuscleSoreness[muscle.rawValue]
        return HStack(spacing: PerformanceTheme.Spacing.md) {
            Button {
                if value == nil {
                    perMuscleSoreness[muscle.rawValue] = max(0, overallSoreness)
                } else {
                    perMuscleSoreness.removeValue(forKey: muscle.rawValue)
                }
            } label: {
                Image(systemName: value == nil ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(value == nil
                                     ? PerformanceTheme.tertiaryText
                                     : PerformanceTheme.rest)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(muscle.localizedName))
            .accessibilityValue(
                value == nil ? Text("Not set") : Text(verbatim: scoreLabel(value ?? 0))
            )

            Text(muscle.localizedName)
                .font(StrandFont.body)
                .foregroundStyle(PerformanceTheme.primaryText)
            Spacer(minLength: 8)

            if let value {
                Stepper(
                    "\(value) / 10",
                    value: Binding(
                        get: { perMuscleSoreness[muscle.rawValue] ?? 0 },
                        set: { perMuscleSoreness[muscle.rawValue] = $0 }
                    ),
                    in: 0...10
                )
                .labelsHidden()
                Text(verbatim: "\(value)")
                    .font(StrandFont.captionNumber)
                    .foregroundStyle(PerformanceTheme.primaryText)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .frame(minHeight: 48)
    }

    private var painCard: some View {
        PerformanceCard {
            VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.md) {
                Toggle("Pain or discomfort", isOn: $painPresent)
                    .font(StrandFont.headline)
                    .tint(PerformanceTheme.critical)
                Text("Pain is kept separate from soreness and never becomes training load.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(PerformanceTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if painPresent {
                    TextField("Pain/discomfort note", text: $painNote, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            PerformanceTheme.secondarySurface,
                            in: RoundedRectangle(cornerRadius: PerformanceTheme.Radius.small)
                        )
                }
            }
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: PerformanceTheme.Spacing.sm) {
            if let errorMessage {
                ErrorStateCard(title: "Data unavailable", message: LocalizedStringKey(errorMessage))
            } else if saved {
                StatusPill("Saved", tone: .charge, symbol: "checkmark.circle.fill")
            }
            Button {
                Task { await save() }
            } label: {
                Label(saving ? "Saving…" : "Save", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PerformanceButtonStyle(role: .primary))
            .disabled(saving || previewMode)

            if sorenessRecordID != nil || painRecordID != nil {
                Button("Delete check-in", role: .destructive) {
                    Task { await deleteLatest() }
                }
                .buttonStyle(PerformanceButtonStyle(role: .destructive))
                .disabled(saving || previewMode)
            }
        }
    }

    private func loadLatest() async {
        guard let store = await repository.storeHandle() else { return }
        if let value = try? await store.latestSorenessCheckIn(deviceId: repository.deviceId) {
            sorenessRecordID = value.id
            overallSoreness = value.overallSoreness ?? -1
            perMuscleSoreness = value.perMuscleSoreness
            sorenessNote = value.note ?? ""
        }
        if let value = try? await store.latestPainCheckIn(deviceId: repository.deviceId) {
            painRecordID = value.id
            painPresent = value.painPresent
            painNote = value.note ?? ""
        }
    }

    private func save() async {
        saving = true
        saved = false
        errorMessage = nil
        defer { saving = false }
        guard let store = await repository.storeHandle() else {
            errorMessage = String(localized: "The local database could not be opened.")
            return
        }
        let now = Int(Date().timeIntervalSince1970)
        do {
            let soreness = SorenessCheckInRecord(
                id: sorenessRecordID ?? UUID().uuidString,
                deviceId: repository.deviceId,
                recordedAt: now,
                overallSoreness: overallSoreness < 0 ? nil : overallSoreness,
                perMuscleSoreness: perMuscleSoreness,
                note: sorenessNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            try await store.saveSorenessCheckIn(soreness)
            sorenessRecordID = soreness.id

            let pain = PainCheckInRecord(
                id: painRecordID ?? UUID().uuidString,
                deviceId: repository.deviceId,
                recordedAt: now,
                painPresent: painPresent,
                note: painNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            try await store.savePainCheckIn(pain)
            painRecordID = pain.id
            await CurrentMuscleResidualService.shared.invalidate(deviceId: repository.deviceId)
            await repository.refresh()
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteLatest() async {
        saving = true
        saved = false
        errorMessage = nil
        defer { saving = false }
        guard let store = await repository.storeHandle() else { return }
        do {
            if let sorenessRecordID {
                try await store.deleteSorenessCheckIn(id: sorenessRecordID)
            }
            if let painRecordID {
                try await store.deletePainCheckIn(id: painRecordID)
            }
            self.sorenessRecordID = nil
            self.painRecordID = nil
            overallSoreness = -1
            perMuscleSoreness = [:]
            sorenessNote = ""
            painPresent = false
            painNote = ""
            await CurrentMuscleResidualService.shared.invalidate(deviceId: repository.deviceId)
            await repository.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scoreLabel(_ value: Int) -> String {
        String(value) + " / 10"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
