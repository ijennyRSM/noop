import SwiftUI
import StrandDesign
import WhoopStore

struct CoachProfileSheet: View {
    @ObservedObject var coach: AICoachEngine
    @Environment(\.dismiss) private var dismiss
    @State private var profile: LocalCoachProfile
    @State private var checkIn: CoachSorenessCheckIn
    @State private var hasCheckIn: Bool
    @State private var selectedMuscle: NOOPMuscle = .quadriceps
    @State private var selectedMuscleSoreness = 5

    init(coach: AICoachEngine) {
        self.coach = coach
        _profile = State(initialValue: coach.localProfile)
        _checkIn = State(initialValue: coach.sorenessCheckIn ?? .init())
        _hasCheckIn = State(initialValue: coach.sorenessCheckIn != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NoopMetrics.space4) {
                    profileCard
                    checkInCard
                    Text("Everything on this screen stays in this app. It is included in Coach context only when “Let the coach use my data” is on.")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
                .screenPadding()
                .padding(.vertical)
            }
            .background(StrandPalette.surfaceBase.ignoresSafeArea())
            .navigationTitle("Coach profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.availableMinutes = profile.availableMinutes.flatMap {
                            $0 > 0 ? $0 : nil
                        }
                        coach.localProfile = profile
                        if hasCheckIn {
                            checkIn.recordedAt = Date()
                            coach.sorenessCheckIn = checkIn
                        } else {
                            coach.sorenessCheckIn = nil
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private var profileCard: some View {
        NoopCard(tint: StrandPalette.chargeColor) {
            VStack(alignment: .leading, spacing: 14) {
                Text("LOCAL COACH PROFILE")
                    .font(StrandFont.overline)
                    .tracking(StrandFont.overlineTracking)
                    .foregroundStyle(StrandPalette.chargeColor)
                field("Primary goals", text: csvBinding(\.primaryGoals),
                      prompt: "Strength, endurance, sleep")
                field("Sports and activities", text: csvBinding(\.sportsAndActivities),
                      prompt: "Football, running, lifting")
                Picker("Experience", selection: $profile.experienceLevel) {
                    Text("Not set").tag("")
                    Text("Beginner").tag("beginner")
                    Text("Intermediate").tag("intermediate")
                    Text("Advanced").tag("advanced")
                }
                .pickerStyle(.segmented)
                field("Preferred training days", text: csvBinding(\.preferredTrainingDays),
                      prompt: "Monday, Wednesday, Saturday")
                Stepper(
                    value: Binding(
                        get: { profile.availableMinutes ?? 0 },
                        set: { profile.availableMinutes = $0 == 0 ? nil : $0 }
                    ),
                    in: 0...240,
                    step: 5
                ) {
                    HStack {
                        Text("Available time")
                        Spacer()
                        if let minutes = profile.availableMinutes {
                            Text("\(minutes) min")
                                .foregroundStyle(StrandPalette.textSecondary)
                        } else {
                            Text("Not set")
                                .foregroundStyle(StrandPalette.textSecondary)
                        }
                    }
                }
                field("Available equipment", text: csvBinding(\.availableEquipment),
                      prompt: "Barbell, dumbbells, bodyweight")
                field("Current training limitations",
                      text: $profile.trainingLimitations,
                      prompt: "Optional")
                field("Preferred coaching language",
                      text: $profile.preferredLanguage,
                      prompt: "Thai")
            }
        }
    }

    private var checkInCard: some View {
        NoopCard(tint: StrandPalette.metricCyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OPTIONAL CHECK-IN")
                            .font(StrandFont.overline)
                            .tracking(StrandFont.overlineTracking)
                            .foregroundStyle(StrandPalette.metricCyan)
                        Text("Soreness can modestly adjust estimated residual load.")
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $hasCheckIn)
                        .labelsHidden()
                        .tint(StrandPalette.accent)
                }
                if hasCheckIn {
                    Picker("Overall soreness", selection: Binding(
                        get: { checkIn.overallSoreness ?? -1 },
                        set: { checkIn.overallSoreness = $0 < 0 ? nil : $0 }
                    )) {
                        Text("Not set").tag(-1)
                        ForEach(0...10, id: \.self) { Text("\($0)/10").tag($0) }
                    }
                    HStack {
                        Picker("Muscle", selection: $selectedMuscle) {
                            ForEach(NOOPMuscle.allCases, id: \.self) {
                                Text($0.localizedName).tag($0)
                            }
                        }
                        Picker("Soreness", selection: $selectedMuscleSoreness) {
                            ForEach(0...10, id: \.self) { Text("\($0)").tag($0) }
                        }
                        Button("Add") {
                            checkIn.perMuscleSoreness[selectedMuscle.rawValue]
                                = selectedMuscleSoreness
                        }
                    }
                    ForEach(checkIn.perMuscleSoreness.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(NOOPMuscle(rawValue: key)?.localizedName ?? key)
                            Spacer()
                            Text("\(checkIn.perMuscleSoreness[key] ?? 0)/10")
                            Button(role: .destructive) {
                                checkIn.perMuscleSoreness.removeValue(forKey: key)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    field("Optional note", text: $checkIn.note, prompt: "How you feel")
                    Picker("Pain or discomfort", selection: Binding(
                        get: { checkIn.painPresent.map { $0 ? 1 : 0 } ?? -1 },
                        set: {
                            checkIn.painPresent = $0 < 0 ? nil : $0 == 1
                        }
                    )) {
                        Text("Not reported").tag(-1)
                        Text("No").tag(0)
                        Text("Yes").tag(1)
                    }
                    .pickerStyle(.segmented)
                    if checkIn.painPresent == true {
                        field("Pain/discomfort note", text: $checkIn.painNote,
                              prompt: "Coach will not diagnose this")
                    }
                    Button("Delete check-in", role: .destructive) {
                        hasCheckIn = false
                        checkIn = .init()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func csvBinding(_ keyPath: WritableKeyPath<LocalCoachProfile, [String]>)
        -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath].joined(separator: ", ") },
            set: {
                profile[keyPath: keyPath] = $0.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>,
                       prompt: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textSecondary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    StrandPalette.surfaceInset,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(StrandPalette.hairline, lineWidth: 1)
                )
        }
    }
}

struct DefaultCoachPromptReviewSheet: View {
    @ObservedObject var coach: AICoachEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(AICoachEngine.defaultSystemPrompt)
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(StrandPalette.surfaceBase.ignoresSafeArea())
            .navigationTitle("New default instructions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep custom") {
                        coach.keepCustomSystemPrompt()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use new default") {
                        coach.useLatestDefaultSystemPrompt()
                        dismiss()
                    }
                }
            }
        }
    }
}
