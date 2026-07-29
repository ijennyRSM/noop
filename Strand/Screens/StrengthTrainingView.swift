import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

private extension ExerciseDefinition {
    var strengthDisplayName: String {
        guard Locale.current.language.languageCode?.identifier == "th" else {
            return canonicalName
        }
        return aliases.first(where: { alias in
            alias.unicodeScalars.contains { scalar in
                (0x0E00...0x0E7F).contains(scalar.value)
            }
        }) ?? canonicalName
    }
}

@MainActor
final class StrengthTrainingViewModel: ObservableObject {
    @Published var session: StrengthSessionRecord?
    @Published var searchResults: [ExerciseDefinition] = []
    @Published var favorites = Set<String>()
    @Published var recentIds: [String] = []
    @Published var query = ""
    @Published var muscleFilter: String?
    @Published var equipmentFilter: String?
    @Published var showingPicker = false
    @Published var showingCustomExercise = false
    @Published var showingTemplates = false
    @Published var templates: [WorkoutTemplateRecord] = []
    @Published var templateNames: [String: String] = [:]
    @Published var templateName = ""
    @Published var restEndsAt: Date?
    @Published var loadOutput: MuscularLoadEngine.SessionOutput?
    @Published var errorMessage: String?
    @Published private(set) var loading = false

    private weak var repository: Repository?
    private var store: WhoopStore?
    private var bodyweightKg: Double?
    private var saveTask: Task<Void, Never>?
    private var exerciseCache: [String: ExerciseDefinition] = [:]
    private var previousSetCache: [String: [StrengthSetRecord]] = [:]

    var isStrengthSession: Bool { session != nil }
    var orderedSearchResults: [ExerciseDefinition] {
        let recentRank = Dictionary(uniqueKeysWithValues:
            recentIds.enumerated().map { ($0.element, $0.offset) })
        return searchResults.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.id)
            let rhsFavorite = favorites.contains(rhs.id)
            if lhsFavorite != rhsFavorite { return lhsFavorite }
            let lhsRecent = recentRank[lhs.id] ?? Int.max
            let rhsRecent = recentRank[rhs.id] ?? Int.max
            if lhsRecent != rhsRecent { return lhsRecent < rhsRecent }
            return lhs.strengthDisplayName.localizedCaseInsensitiveCompare(
                rhs.strengthDisplayName) == .orderedAscending
        }
    }

    func load(repository: Repository, deviceId: String, startedAt: Date,
              bodyweightKg: Double?) async {
        guard !loading, session == nil else { return }
        loading = true
        self.repository = repository
        self.bodyweightKg = bodyweightKg
        guard let store = await repository.storeHandle() else {
            errorMessage = String(localized: "The local database could not be opened.")
            loading = false
            return
        }
        self.store = store
        do {
            try await store.ensureExerciseLibrarySeeded()
            if let draft = try await store.activeStrengthSession(deviceId: deviceId),
               abs(draft.startedAt - Int(startedAt.timeIntervalSince1970)) < 12 * 3_600 {
                session = draft
            } else {
                let draft = StrengthSessionRecord(
                    deviceId: deviceId,
                    workoutStartTs: Int(startedAt.timeIntervalSince1970),
                    startedAt: Int(startedAt.timeIntervalSince1970))
                session = draft
                try await store.saveStrengthSession(draft)
            }
            if let session { try await cacheDefinitions(for: session) }
            favorites = try await store.favoriteExerciseIds()
            recentIds = try await store.recentExerciseIds()
            templates = try await store.workoutTemplates()
            templateNames = Dictionary(uniqueKeysWithValues:
                templates.map { ($0.id, $0.name) })
            try await loadPreviousSetCache(deviceId: deviceId)
            await search()
            await recalculate()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    func loadCompleted(repository: Repository, sessionId: String,
                       bodyweightKg: Double?) async {
        guard !loading, session == nil else { return }
        loading = true
        self.repository = repository
        self.bodyweightKg = bodyweightKg
        guard let store = await repository.storeHandle() else {
            errorMessage = String(localized: "The local database could not be opened.")
            loading = false
            return
        }
        self.store = store
        do {
            try await store.ensureExerciseLibrarySeeded()
            session = try await store.strengthSession(id: sessionId)
            if let session { try await cacheDefinitions(for: session) }
            favorites = try await store.favoriteExerciseIds()
            templates = try await store.workoutTemplates()
            templateNames = Dictionary(uniqueKeysWithValues:
                templates.map { ($0.id, $0.name) })
            try await loadPreviousSetCache(deviceId: session?.deviceId ?? repository.deviceId)
            await search()
            await recalculate()
        } catch { errorMessage = error.localizedDescription }
        loading = false
    }

    func displayName(for exercise: StrengthSessionExerciseRecord) -> String {
        exerciseCache[exercise.exerciseId]?.strengthDisplayName ?? exercise.snapshotName
    }

    func search() async {
        guard let store else { return }
        do {
            searchResults = try await store.searchExercises(
                query: query, muscleId: muscleFilter, equipment: equipmentFilter, limit: 100)
            for exercise in searchResults { exerciseCache[exercise.id] = exercise }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addExercise(_ definition: ExerciseDefinition) {
        guard var session else { return }
        exerciseCache[definition.id] = definition
        let previous = previousSets(for: definition.id)
        let firstSet = previous.first.map {
            StrengthSetRecord(setIndex: 0, setType: $0.setType,
                              weightKg: $0.weightKg, reps: $0.reps,
                              rpe: nil, rir: nil, side: $0.side)
        } ?? StrengthSetRecord(setIndex: 0)
        session.exercises.append(.init(
            exerciseId: definition.id, snapshotName: definition.canonicalName,
            orderIndex: session.exercises.count, sets: [firstSet]))
        self.session = session
        showingPicker = false
        Task {
            try? await store?.noteExerciseUsed(definition.id,
                                               at: Int(Date().timeIntervalSince1970))
            await persistAndRecalculate()
        }
    }

    func addSet(to exerciseId: String, copyingPrevious: Bool = true) {
        mutate { session in
            guard let index = session.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
            let next = session.exercises[index].sets.count
            var set = copyingPrevious
                ? (session.exercises[index].sets.last ?? StrengthSetRecord(setIndex: next))
                : StrengthSetRecord(setIndex: next)
            set.id = UUID().uuidString
            set.setIndex = next
            set.completed = false
            session.exercises[index].sets.append(set)
        }
    }

    func updateSet(exerciseId: String, setId: String,
                   _ change: (inout StrengthSetRecord) -> Void) {
        mutate { session in
            guard let e = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                  let s = session.exercises[e].sets.firstIndex(where: { $0.id == setId })
            else { return }
            change(&session.exercises[e].sets[s])
        }
    }

    func deleteSet(exerciseId: String, setId: String) {
        mutate { session in
            guard let e = session.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
            session.exercises[e].sets.removeAll { $0.id == setId }
            for i in session.exercises[e].sets.indices {
                session.exercises[e].sets[i].setIndex = i
            }
        }
    }

    func deleteExercise(_ id: String) {
        mutate { session in
            session.exercises.removeAll { $0.id == id }
            for i in session.exercises.indices { session.exercises[i].orderIndex = i }
        }
    }

    func adjustLastSet(exerciseId: String, weightDelta: Double = 0,
                       repsDelta: Int = 0) {
        mutate { session in
            guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                  let setIndex = session.exercises[exerciseIndex].sets.indices.last else { return }
            if weightDelta != 0 {
                let current = session.exercises[exerciseIndex].sets[setIndex].weightKg ?? 0
                session.exercises[exerciseIndex].sets[setIndex].weightKg =
                    max(0, current + weightDelta)
            }
            if repsDelta != 0 {
                let current = session.exercises[exerciseIndex].sets[setIndex].reps ?? 0
                session.exercises[exerciseIndex].sets[setIndex].reps =
                    max(0, current + repsDelta)
            }
        }
    }

    func createCustomExercise(name: String, aliases: String, equipment: String,
                              movement: String, primaryMuscle: String,
                              secondaryMuscle: String?, unilateral: Bool,
                              bodyweight: Bool) async -> Bool {
        guard let store else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "Exercise name is required.")
            return false
        }
        var muscles = [
            ExerciseMuscleContribution(
                muscleId: primaryMuscle,
                role: ExerciseMuscleRole.primary.rawValue,
                weight: secondaryMuscle == nil ? 1 : 0.7),
        ]
        if let secondaryMuscle, secondaryMuscle != primaryMuscle {
            muscles.append(.init(
                muscleId: secondaryMuscle,
                role: ExerciseMuscleRole.secondary.rawValue,
                weight: 0.3))
        } else {
            muscles[0].weight = 1
        }
        let definition = ExerciseDefinition(
            id: "custom-\(UUID().uuidString.lowercased())",
            canonicalName: trimmedName,
            aliases: aliases.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty },
            equipment: [equipment],
            movementPattern: movement.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased().replacingOccurrences(of: " ", with: "_"),
            laterality: unilateral
                ? StrengthLaterality.unilateral.rawValue
                : StrengthLaterality.bilateral.rawValue,
            loadType: bodyweight
                ? StrengthLoadType.bodyweight.rawValue
                : StrengthLoadType.external.rawValue,
            muscles: muscles,
            effectiveBodyweightCoefficient: bodyweight ? 0.65 : nil,
            source: "NOOP user", sourceURL: "", license: "User-created",
            licenseURL: "", libraryVersion: 0, builtIn: false)
        do {
            try await store.saveCustomExercise(definition)
            exerciseCache[definition.id] = definition
            await search()
            addExercise(definition)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func duplicateExercise(_ id: String) {
        mutate { session in
            guard let item = session.exercises.first(where: { $0.id == id }) else { return }
            var copy = item
            copy.id = UUID().uuidString
            copy.orderIndex = session.exercises.count
            copy.sets = item.sets.enumerated().map { index, old in
                var set = old
                set.id = UUID().uuidString
                set.setIndex = index
                set.completed = false
                return set
            }
            session.exercises.append(copy)
        }
    }

    func moveExercise(_ id: String, offset: Int) {
        mutate { session in
            guard let old = session.exercises.firstIndex(where: { $0.id == id }) else { return }
            let new = min(max(0, old + offset), session.exercises.count - 1)
            guard old != new else { return }
            let value = session.exercises.remove(at: old)
            session.exercises.insert(value, at: new)
            for i in session.exercises.indices { session.exercises[i].orderIndex = i }
        }
    }

    func toggleFavorite(_ definition: ExerciseDefinition) {
        let shouldFavorite = !favorites.contains(definition.id)
        if shouldFavorite { favorites.insert(definition.id) } else { favorites.remove(definition.id) }
        Task { try? await store?.setExerciseFavorite(definition.id, favorite: shouldFavorite) }
    }

    func startRest(seconds: Int = 90) { restEndsAt = Date().addingTimeInterval(Double(seconds)) }
    func cancelRest() { restEndsAt = nil }

    func setSessionRPE(_ value: Double?) {
        mutate { $0.sessionRPE = value }
    }

    func setNotes(_ value: String) {
        mutate { $0.notes = value.isEmpty ? nil : value }
    }

    func saveTemplate() async {
        guard let store, let session else { return }
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try await store.saveWorkoutTemplate(
                WorkoutTemplateRecord(name: name, notes: session.notes,
                                      exercises: session.exercises))
            templates = try await store.workoutTemplates()
            templateName = ""
        } catch { errorMessage = error.localizedDescription }
    }

    func applyTemplate(_ template: WorkoutTemplateRecord) {
        mutate { session in
            session.title = template.name
            session.exercises = template.exercises.enumerated().map { index, item in
                var copy = item
                copy.id = UUID().uuidString
                copy.orderIndex = index
                copy.sets = item.sets.enumerated().map { setIndex, item in
                    var set = item
                    set.id = UUID().uuidString
                    set.setIndex = setIndex
                    set.completed = false
                    return set
                }
                return copy
            }
        }
        showingTemplates = false
    }

    func updateTemplate(_ template: WorkoutTemplateRecord) async {
        guard let store, let session else { return }
        var updated = template
        let proposedName = templateNames[template.id]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let proposedName, !proposedName.isEmpty { updated.name = proposedName }
        updated.exercises = session.exercises
        updated.notes = session.notes
        do {
            try await store.saveWorkoutTemplate(updated)
            templates = try await store.workoutTemplates()
            templateNames = Dictionary(uniqueKeysWithValues:
                templates.map { ($0.id, $0.name) })
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteTemplate(_ template: WorkoutTemplateRecord) async {
        guard let store else { return }
        do {
            try await store.deleteWorkoutTemplate(id: template.id)
            templates = try await store.workoutTemplates()
        } catch { errorMessage = error.localizedDescription }
    }

    @discardableResult
    func finish(cardiovascularEffort: Double?) async -> Bool {
        saveTask?.cancel()
        guard var session, let store else { return false }
        await recalculate()
        session = self.session ?? session
        session.status = StrengthSessionStatus.completed.rawValue
        session.endedAt = Int(Date().timeIntervalSince1970)
        session.cardiovascularEffort = cardiovascularEffort
        session.muscularLoad = loadOutput?.muscularLoad
        session.totalTrainingLoad = MuscularLoadEngine.totalTrainingLoad(
            storedCardiovascularEffort: cardiovascularEffort,
            muscularLoad: loadOutput?.muscularLoad)
        session.confidence = loadOutput?.confidence.rawValue ?? StrengthConfidence.low.rawValue
        self.session = session
        do {
            try await writeDerivedCommit(for: session)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveCompletedEdits() async -> Bool {
        saveTask?.cancel()
        guard var session, store != nil else { return false }
        await recalculate()
        session = self.session ?? session
        session.muscularLoad = loadOutput?.muscularLoad
        session.totalTrainingLoad = MuscularLoadEngine.totalTrainingLoad(
            storedCardiovascularEffort: session.cardiovascularEffort,
            muscularLoad: loadOutput?.muscularLoad)
        session.confidence = loadOutput?.confidence.rawValue ?? StrengthConfidence.low.rawValue
        self.session = session
        do {
            try await writeDerivedCommit(for: session)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func previousSets(for exerciseId: String) -> [StrengthSetRecord] {
        session?.exercises.last(where: { $0.exerciseId == exerciseId })?.sets
            ?? previousSetCache[exerciseId]
            ?? []
    }

    private func loadPreviousSetCache(deviceId: String) async throws {
        guard let store else { return }
        let sessions = try await store.strengthSessions(deviceId: deviceId, limit: 100)
        let history = sessions.filter {
            $0.status == StrengthSessionStatus.completed.rawValue
        }
        var cache: [String: [StrengthSetRecord]] = [:]
        for past in history {
            for exercise in past.exercises where cache[exercise.exerciseId] == nil {
                cache[exercise.exerciseId] = exercise.sets
            }
        }
        previousSetCache = cache
    }

    private func mutate(_ change: (inout StrengthSessionRecord) -> Void) {
        guard var session else { return }
        change(&session)
        self.session = session
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistAndRecalculate()
        }
    }

    private func persistAndRecalculate() async {
        guard let session, let store else { return }
        do {
            try await store.saveStrengthSession(session)
            await recalculate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recalculate() async {
        guard let session, let store else { return }
        var inputs: [MuscularLoadEngine.SetInput] = []
        for item in session.exercises {
            let definition: ExerciseDefinition?
            if let cached = exerciseCache[item.exerciseId] {
                definition = cached
            } else {
                definition = try? await store.exerciseDefinition(id: item.exerciseId)
                if let definition { exerciseCache[item.exerciseId] = definition }
            }
            guard let definition else { continue }
            for set in item.sets {
                inputs.append(.init(
                    set: set, exercise: definition, userBodyweightKg: bodyweightKg,
                    estimatedOneRepMaxKg: bestE1RM(for: item.sets)))
            }
        }
        let earliest = Int(Date().addingTimeInterval(-28 * 86_400).timeIntervalSince1970)
        let historyRows = (try? await store.historicalMuscleLoads(
            deviceId: session.deviceId, from: earliest)) ?? []
        let history = Dictionary(grouping: historyRows.filter {
            $0.trainedAt != session.startedAt
        }, by: \.muscleId).map {
            MuscularLoadEngine.MuscleHistory(
                muscleId: $0.key, rawStimuli: $0.value.map(\.rawStimulus))
        }
        loadOutput = MuscularLoadEngine.calculate(inputs: inputs, history: history)
    }

    private func bestE1RM(for sets: [StrengthSetRecord]) -> Double? {
        sets.compactMap { set in
            guard let weight = set.weightKg, let reps = set.reps else { return nil }
            return MuscularLoadEngine.estimatedOneRepMax(weightKg: weight, reps: reps)
        }.max()
    }

    private func writeDerivedCommit(for session: StrengthSessionRecord) async throws {
        guard let store, let output = loadOutput else { return }
        let latestDay = repository?.today
        let recovery = MuscularLoadEngine.RecoveryModifiers(
            sleepHours: latestDay?.totalSleepMin.map { $0 / 60 },
            charge: latestDay?.recovery)
        let commit = try await StrengthDerivedBuilder.makeCommit(
            session: session,
            output: output,
            store: store,
            recovery: recovery
        )
        try await store.commitStrengthDerived(commit)
        try await completeLinkedPlanIfNeeded(session: session, store: store)
        await CurrentMuscleResidualService.shared.invalidate(deviceId: session.deviceId)
    }

    private func cacheDefinitions(for session: StrengthSessionRecord) async throws {
        guard let store else { return }
        for exercise in session.exercises where exerciseCache[exercise.exerciseId] == nil {
            if let definition = try await store.exerciseDefinition(id: exercise.exerciseId) {
                exerciseCache[exercise.exerciseId] = definition
            }
        }
    }

    private func completeLinkedPlanIfNeeded(
        session: StrengthSessionRecord,
        store: WhoopStore
    ) async throws {
        guard session.status == StrengthSessionStatus.completed.rawValue,
              var link = try await store.pendingStrengthPlanLink(
                forSessionStartedAt: session.startedAt)
        else { return }
        link.sessionId = session.id
        link.completedAt = session.endedAt ?? Int(Date().timeIntervalSince1970)
        try await store.upsertStrengthPlanLink(link)
        if let proposalId = UUID(uuidString: link.proposalId) {
            CoachPlanStore.shared.completeStrength(
                proposalId, finalizedSessionId: session.id)
        }
    }
}

struct StrengthWorkoutLogger: View {
    @ObservedObject var viewModel: StrengthTrainingViewModel
    @EnvironmentObject private var repository: Repository
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: NoopMetrics.space4) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("STRENGTH TRAINING")
                        .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                        .foregroundStyle(StrandPalette.metricCyan)
                    Text("Exercise and set log")
                        .font(StrandFont.title2)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                Spacer()
                Button {
                    viewModel.showingTemplates = true
                } label: {
                    Image(systemName: "square.stack.3d.up")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(StrandPalette.metricCyan)
                .accessibilityLabel("Workout templates")
                loadBadge
            }

            if let error = viewModel.errorMessage {
                Text(error).font(StrandFont.footnote).foregroundStyle(StrandPalette.metricRose)
            }

            if viewModel.loading {
                ProgressView("Loading offline exercise library…")
            } else if let session = viewModel.session {
                ForEach(session.exercises) { exercise in
                    exerciseCard(exercise)
                }
                NoopButton("Add exercise", systemImage: "plus.circle.fill",
                           kind: .primary, fullWidth: true) {
                    viewModel.showingPicker = true
                }
                restTimer
                sessionFields(session)
            }
        }
        .task(id: model.activeWorkout?.start) {
            guard let workout = model.activeWorkout else { return }
            await viewModel.load(
                repository: repository, deviceId: repository.deviceId,
                startedAt: workout.start, bodyweightKg: model.profile.weightKg)
        }
        .sheet(isPresented: $viewModel.showingPicker) {
            ExercisePicker(viewModel: viewModel)
                .strengthSheetPresentation(largeFirst: true)
        }
        .sheet(isPresented: $viewModel.showingTemplates) {
            StrengthTemplateSheet(viewModel: viewModel)
                .strengthSheetPresentation(largeFirst: true)
        }
    }

    private var loadBadge: some View {
        let load = viewModel.loadOutput?.muscularLoad ?? 0
        return VStack(alignment: .trailing, spacing: 2) {
            Text("\(Int(load.rounded()))")
                .font(StrandFont.number(28))
                .foregroundStyle(loadColor(load))
            Text("Estimated load")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated Muscular Load \(Int(load.rounded())) out of 100")
    }

    private func exerciseCard(_ exercise: StrengthSessionExerciseRecord) -> some View {
        NoopCard(padding: 14, tint: StrandPalette.metricCyan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(viewModel.displayName(for: exercise))
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Spacer()
                    Menu {
                        Button("Move up") { viewModel.moveExercise(exercise.id, offset: -1) }
                        Button("Move down") { viewModel.moveExercise(exercise.id, offset: 1) }
                        Button("Duplicate exercise") { viewModel.duplicateExercise(exercise.id) }
                        Button("Remove exercise", role: .destructive) {
                            viewModel.deleteExercise(exercise.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(
                        "Exercise actions for \(viewModel.displayName(for: exercise))"
                    )
                }
                setHeader
                ForEach(exercise.sets) { set in
                    StrengthSetRow(
                        set: set,
                        onChange: { change in
                            viewModel.updateSet(exerciseId: exercise.id, setId: set.id, change)
                        },
                        onDelete: { viewModel.deleteSet(exerciseId: exercise.id, setId: set.id) },
                        onComplete: {
                            viewModel.updateSet(exerciseId: exercise.id, setId: set.id) {
                                $0.completed.toggle()
                            }
                            viewModel.startRest()
                        })
                }
                HStack {
                    Button("Copy previous set") { viewModel.addSet(to: exercise.id) }
                    Spacer()
                    Button("Add set") { viewModel.addSet(to: exercise.id, copyingPrevious: false) }
                }
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.metricCyan)
                HStack(spacing: 8) {
                    quickAdjust("−2.5 kg") {
                        viewModel.adjustLastSet(exerciseId: exercise.id, weightDelta: -2.5)
                    }
                    quickAdjust("+2.5 kg") {
                        viewModel.adjustLastSet(exerciseId: exercise.id, weightDelta: 2.5)
                    }
                    quickAdjust("−1 rep") {
                        viewModel.adjustLastSet(exerciseId: exercise.id, repsDelta: -1)
                    }
                    quickAdjust("+1 rep") {
                        viewModel.adjustLastSet(exerciseId: exercise.id, repsDelta: 1)
                    }
                }
            }
        }
    }

    private func quickAdjust(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(StrandFont.footnote)
            .foregroundStyle(StrandPalette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 8))
    }

    private var setHeader: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34)
            Text("kg").frame(maxWidth: .infinity)
            Text("REPS").frame(maxWidth: .infinity)
            Text("RPE").frame(maxWidth: .infinity)
            Text("RIR").frame(maxWidth: .infinity)
            Color.clear.frame(width: 44)
        }
        .font(StrandFont.overline)
        .foregroundStyle(StrandPalette.textTertiary)
    }

    @ViewBuilder private var restTimer: some View {
        if let end = viewModel.restEndsAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                let timerValue = String(
                    format: "%d:%02d",
                    remaining / 60,
                    remaining % 60
                )
                HStack {
                    Image(systemName: "timer")
                    Text(remaining > 0
                         ? String(localized: "Rest") + " "
                            + timerValue
                         : String(localized: "Rest complete"))
                        .monospacedDigit()
                    Spacer()
                    Button("Stop") { viewModel.cancelRest() }
                }
                .font(StrandFont.subhead)
                .foregroundStyle(remaining > 0 ? StrandPalette.metricCyan : StrandPalette.accent)
                .padding(12)
                .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sessionFields(_ session: StrengthSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session RPE (optional)")
                .font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
            Picker("Session RPE", selection: Binding(
                get: { Int(session.sessionRPE ?? 0) },
                set: { viewModel.setSessionRPE($0 == 0 ? nil : Double($0)) })) {
                Text("Not set").tag(0)
                ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
            }
            // Eleven segmented choices truncate localized labels on an iPhone.
            // A menu keeps the optional state readable at every Dynamic Type size.
            .pickerStyle(.menu)
            .tint(StrandPalette.metricCyan)
            TextField("Session notes (optional)", text: Binding(
                get: { session.notes ?? "" },
                set: viewModel.setNotes))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func loadColor(_ value: Double) -> Color {
        switch value {
        case 75...: StrandPalette.metricRose
        case 50..<75: StrandPalette.statusWarning
        case 25..<50: StrandPalette.sleepLight
        default: StrandPalette.accent
        }
    }
}

private struct StrengthTemplateSheet: View {
    @ObservedObject var viewModel: StrengthTrainingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Create from current workout") {
                    TextField("Template name", text: $viewModel.templateName)
                    Button("Save template") {
                        Task { await viewModel.saveTemplate() }
                    }
                    .disabled(viewModel.templateName
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Saved templates") {
                    if viewModel.templates.isEmpty {
                        Text("No templates yet.")
                            .foregroundStyle(StrandPalette.textSecondary)
                    }
                    ForEach(viewModel.templates) { template in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Template name", text: Binding(
                                get: { viewModel.templateNames[template.id] ?? template.name },
                                set: { viewModel.templateNames[template.id] = $0 }))
                                .font(StrandFont.headline)
                            Text("\(template.exercises.count) exercises")
                                .font(StrandFont.footnote)
                                .foregroundStyle(StrandPalette.textSecondary)
                            HStack {
                                Button("Use") {
                                    viewModel.applyTemplate(template)
                                    dismiss()
                                }
                                Button("Update") {
                                    Task { await viewModel.updateTemplate(template) }
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteTemplate(template) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Workout templates")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct StrengthSetRow: View {
    let set: StrengthSetRecord
    let onChange: ((inout StrengthSetRecord) -> Void) -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(StrengthSetType.allCases, id: \.self) { type in
                    Button(type.rawValue.capitalized) { onChange { $0.setType = type.rawValue } }
                }
                Divider()
                ForEach(StrengthSide.allCases, id: \.self) { side in
                    Button(sideButtonTitle(side)) {
                        onChange { $0.side = side.rawValue }
                    }
                }
                Button(set.reachedFailure ? "Not to failure" : "Reached failure") {
                    onChange {
                        $0.reachedFailure.toggle()
                        if $0.reachedFailure { $0.setType = StrengthSetType.failure.rawValue }
                    }
                }
                Button("Delete set", role: .destructive, action: onDelete)
            } label: {
                Text(set.setType == StrengthSetType.warmup.rawValue ? "W" : "\(set.setIndex + 1)")
                    .font(StrandFont.captionNumber)
                    .frame(width: 34, height: 36)
                    .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 8))
            }
            numberField(set.weightKg.map { String(format: "%.1f", $0) } ?? "",
                        keyboard: .decimalPad) { value in
                onChange { $0.weightKg = Double(value.replacingOccurrences(of: ",", with: ".")) }
            }
            numberField(set.reps.map(String.init) ?? "", keyboard: .numberPad) { value in
                onChange { $0.reps = Int(value) }
            }
            numberField(set.rpe.map { String(format: "%.1f", $0) } ?? "",
                        keyboard: .decimalPad) { value in onChange { $0.rpe = Double(value) } }
            numberField(set.rir.map { String(format: "%.1f", $0) } ?? "",
                        keyboard: .decimalPad) { value in onChange { $0.rir = Double(value) } }
            Button(action: onComplete) {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(set.completed ? StrandPalette.accent : StrandPalette.textTertiary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(set.completed ? "Mark set incomplete" : "Complete set")
        }
        .accessibilityElement(children: .contain)
    }

    private func sideButtonTitle(_ side: StrengthSide) -> String {
        let value: String
        switch side {
        case .both: value = String(localized: "Both")
        case .left: value = String(localized: "Left")
        case .right: value = String(localized: "Right")
        }
        return "\(String(localized: "Side")): \(value)"
    }

    private func numberField(_ value: String, keyboard: UIKeyboardTypeCompat,
                             onCommit: @escaping (String) -> Void) -> some View {
        let binding = Binding(
            get: { value },
            set: onCommit)
        return TextField("—", text: binding)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .keyboardTypeCompat(keyboard)
            .font(StrandFont.captionNumber)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExercisePicker: View {
    @ObservedObject var viewModel: StrengthTrainingViewModel
    @Environment(\.dismiss) private var dismiss

    private let equipment = [
        "barbell", "dumbbell", "kettlebell", "cable", "machine",
        "bodyweight", "bands", "smith_machine",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Search exercises or aliases", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .onChangeCompat(of: viewModel.query) { _ in Task { await viewModel.search() } }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterButton("All muscles", selected: viewModel.muscleFilter == nil) {
                            viewModel.muscleFilter = nil
                        }
                        ForEach(NOOPMuscle.allCases, id: \.rawValue) { muscle in
                            filterButton(muscle.localizedName,
                                         selected: viewModel.muscleFilter == muscle.rawValue) {
                                viewModel.muscleFilter = muscle.rawValue
                            }
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterButton("All equipment", selected: viewModel.equipmentFilter == nil) {
                            viewModel.equipmentFilter = nil
                        }
                        ForEach(equipment, id: \.self) { item in
                            filterButton(item.replacingOccurrences(of: "_", with: " ").capitalized,
                                         selected: viewModel.equipmentFilter == item) {
                                viewModel.equipmentFilter = item
                            }
                        }
                    }
                }
                Button {
                    viewModel.showingCustomExercise = true
                } label: {
                    Label("Create custom exercise", systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(StrandPalette.metricCyan)
                List(viewModel.orderedSearchResults) { exercise in
                    Button {
                        viewModel.addExercise(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.strengthDisplayName)
                                    .foregroundStyle(StrandPalette.textPrimary)
                                Text(exercise.equipment.joined(separator: " · ")
                                     + " · "
                                     + (exercise.muscles.first?.muscleId
                                        .replacingOccurrences(of: "_", with: " ") ?? ""))
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textSecondary)
                            }
                            Spacer()
                            Button {
                                viewModel.toggleFavorite(exercise)
                            } label: {
                                Image(systemName: viewModel.favorites.contains(exercise.id)
                                      ? "star.fill" : "star")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Favorite \(exercise.strengthDisplayName)")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChangeCompat(of: viewModel.muscleFilter) { _ in Task { await viewModel.search() } }
            .onChangeCompat(of: viewModel.equipmentFilter) { _ in Task { await viewModel.search() } }
            .sheet(isPresented: $viewModel.showingCustomExercise) {
                CustomExerciseSheet(viewModel: viewModel)
                    .strengthSheetPresentation(largeFirst: true)
            }
        }
    }

    private func filterButton(_ title: String, selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(StrandFont.footnote)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? StrandPalette.metricCyan.opacity(0.22)
                        : StrandPalette.surfaceInset, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? StrandPalette.metricCyan
                                           : StrandPalette.hairline, lineWidth: 1))
    }
}

private struct CustomExerciseSheet: View {
    @ObservedObject var viewModel: StrengthTrainingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var aliases = ""
    @State private var equipment = "other"
    @State private var movement = "other"
    @State private var primaryMuscle = NOOPMuscle.chest.rawValue
    @State private var secondaryMuscle = ""
    @State private var unilateral = false
    @State private var bodyweight = false
    @State private var saving = false

    private let equipmentOptions = [
        "barbell", "dumbbell", "kettlebell", "cable", "machine",
        "bodyweight", "bands", "smith_machine", "other",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise identity") {
                    TextField("Exercise name", text: $name)
                    TextField("Aliases separated by commas", text: $aliases)
                    TextField("Movement pattern", text: $movement)
                }
                Section("Equipment and load") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipmentOptions, id: \.self) {
                            Text($0.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag($0)
                        }
                    }
                    Toggle("Bodyweight exercise", isOn: $bodyweight)
                    Toggle("Unilateral exercise", isOn: $unilateral)
                }
                Section("Muscles") {
                    Picker("Primary muscle", selection: $primaryMuscle) {
                        ForEach(NOOPMuscle.allCases, id: \.rawValue) {
                            Text($0.localizedName).tag($0.rawValue)
                        }
                    }
                    Picker("Secondary muscle", selection: $secondaryMuscle) {
                        Text("None").tag("")
                        ForEach(NOOPMuscle.allCases, id: \.rawValue) {
                            Text($0.localizedName).tag($0.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Create custom exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        saving = true
                        Task {
                            let saved = await viewModel.createCustomExercise(
                                name: name, aliases: aliases, equipment: equipment,
                                movement: movement, primaryMuscle: primaryMuscle,
                                secondaryMuscle: secondaryMuscle.isEmpty ? nil : secondaryMuscle,
                                unilateral: unilateral, bodyweight: bodyweight)
                            saving = false
                            if saved { dismiss() }
                        }
                    }
                    .disabled(saving || name.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct StrengthHistoryView: View {
    @EnvironmentObject private var repository: Repository
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [StrengthSessionRecord] = []
    @State private var selected: StrengthSessionRecord?
    @State private var muscleLoads: [String: [DailyMuscleLoadRecord]] = [:]
    @State private var exerciseNames: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 34))
                            .foregroundStyle(StrandPalette.metricCyan)
                        Text("No strength workouts yet").font(StrandFont.title2)
                        Text("Start Strength Training to log exercises, sets, reps, and load.")
                            .font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(sessions) { session in
                        Button {
                            selected = session
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(session.title).font(StrandFont.headline)
                                    Spacer()
                                    Text(date(session.startedAt))
                                        .font(StrandFont.footnote)
                                        .foregroundStyle(StrandPalette.textSecondary)
                                }
                                Text(session.exercises.map(displayName)
                                    .prefix(3).joined(separator: " · "))
                                    .font(StrandFont.subhead)
                                    .foregroundStyle(StrandPalette.textSecondary)
                                    .lineLimit(2)
                                HStack {
                                    historyStat(String(localized: "Sets"), "\(workingSets(session))")
                                    historyStat(String(localized: "Volume"), volume(session))
                                    historyStat(String(localized: "Effort"), score(session.cardiovascularEffort))
                                    historyStat(String(localized: "Muscular"), score(session.muscularLoad))
                                    historyStat(String(localized: "Total"), score(session.totalTrainingLoad))
                                }
                                Text(historyDetails(session))
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textSecondary)
                                    .lineLimit(2)
                                Text(
                                    String(
                                        format: String(localized: "Confidence: %@"),
                                        localizedConfidence(session.confidence)
                                    )
                                )
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textTertiary)
                            }
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(StrandPalette.surfaceBase)
            .navigationTitle("Strength history")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await reload() }
            .sheet(item: $selected) { session in
                StrengthCompletedEditor(sessionId: session.id) {
                    selected = nil
                    Task { await reload() }
                }
                .environmentObject(repository)
                .environmentObject(model)
                .strengthSheetPresentation(largeFirst: true)
            }
        }
    }

    private func reload() async {
        guard let store = await repository.storeHandle() else { return }
        sessions = ((try? await store.strengthSessions(
            deviceId: repository.deviceId, limit: 200)) ?? [])
            .filter { $0.status == StrengthSessionStatus.completed.rawValue }
        var loads: [String: [DailyMuscleLoadRecord]] = [:]
        for session in sessions {
            loads[session.id] = (try? await store.strengthSessionMuscleLoads(
                sessionId: session.id)) ?? []
        }
        muscleLoads = loads
        let exerciseIds = Set(sessions.flatMap(\.exercises).map(\.exerciseId))
        var names: [String: String] = [:]
        for id in exerciseIds {
            guard let definition = try? await store.exerciseDefinition(id: id) else { continue }
            names[id] = definition.strengthDisplayName
        }
        exerciseNames = names
    }

    private func displayName(_ exercise: StrengthSessionExerciseRecord) -> String {
        exerciseNames[exercise.exerciseId] ?? exercise.snapshotName
    }

    private func workingSets(_ session: StrengthSessionRecord) -> Int {
        session.exercises.flatMap(\.sets).filter {
            $0.completed && $0.setType != StrengthSetType.warmup.rawValue
        }.count
    }

    private func volume(_ session: StrengthSessionRecord) -> String {
        let kg = session.exercises.flatMap(\.sets).filter(\.completed).reduce(0.0) {
            $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0)
        }
        return kg > 0 ? "\(Int(kg.rounded())) kg" : "—"
    }

    private func score(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "—"
    }

    private func historyDetails(_ session: StrengthSessionRecord) -> String {
        let duration = session.endedAt.map {
            max(0, $0 - session.startedAt) / 60
        }
        let muscleNames = (muscleLoads[session.id] ?? []).prefix(3).compactMap {
            NOOPMuscle(rawValue: $0.muscleId)?.localizedName
        }.joined(separator: " · ")
        var details: [String] = []
        if let duration {
            details.append(
                String(
                    format: String(localized: "%lld min"),
                    Int64(duration)
                )
            )
        }
        if let rpe = session.sessionRPE {
            details.append("RPE \(String(format: "%.1f", rpe))")
        }
        if !muscleNames.isEmpty { details.append(muscleNames) }
        return details.joined(separator: " · ")
    }

    private func historyStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(StrandFont.overline)
            Text(value).font(StrandFont.captionNumber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localizedConfidence(_ rawValue: String) -> String {
        switch StrengthConfidence(rawValue: rawValue) {
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        case nil: rawValue
        }
    }

    private func date(_ timestamp: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
            .formatted(date: .abbreviated, time: .omitted)
    }
}

struct StrengthCompletedEditor: View {
    let sessionId: String
    let onDone: () -> Void
    @EnvironmentObject private var repository: Repository
    @EnvironmentObject private var model: AppModel
    @StateObject private var viewModel = StrengthTrainingViewModel()
    @State private var saving = false
    @State private var historyExercise: StrengthSessionExerciseRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.loading {
                        ProgressView("Loading strength workout…")
                    } else if let session = viewModel.session {
                        ForEach(session.exercises) { exercise in
                            NoopCard(tint: StrandPalette.metricCyan) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(viewModel.displayName(for: exercise))
                                            .font(StrandFont.headline)
                                        Spacer()
                                        Button("History") {
                                            historyExercise = exercise
                                        }
                                        Button("Remove", role: .destructive) {
                                            viewModel.deleteExercise(exercise.id)
                                        }
                                    }
                                    if let e1RM = bestE1RM(exercise.sets) {
                                        Text(String(
                                            format: String(localized: "Estimated 1RM: %.1f kg"),
                                            e1RM))
                                            .font(StrandFont.footnote)
                                            .foregroundStyle(StrandPalette.textSecondary)
                                    }
                                    ForEach(exercise.sets) { set in
                                        StrengthSetRow(
                                            set: set,
                                            onChange: { change in
                                                viewModel.updateSet(
                                                    exerciseId: exercise.id, setId: set.id, change)
                                            },
                                            onDelete: {
                                                viewModel.deleteSet(
                                                    exerciseId: exercise.id, setId: set.id)
                                            },
                                            onComplete: {
                                                viewModel.updateSet(
                                                    exerciseId: exercise.id, setId: set.id) {
                                                        $0.completed.toggle()
                                                    }
                                            })
                                    }
                                    Button("Add set") { viewModel.addSet(to: exercise.id) }
                                }
                            }
                        }
                        NoopButton("Add missing exercise", systemImage: "plus.circle",
                                   kind: .secondary, fullWidth: true) {
                            viewModel.showingPicker = true
                        }
                        TextField("Session notes", text: Binding(
                            get: { session.notes ?? "" }, set: viewModel.setNotes))
                            .textFieldStyle(.roundedBorder)
                        Picker("Session RPE", selection: Binding(
                            get: { Int(session.sessionRPE ?? 0) },
                            set: { viewModel.setSessionRPE($0 == 0 ? nil : Double($0)) })) {
                                Text("Not set").tag(0)
                                ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(StrandPalette.metricCyan)
                        if let load = viewModel.loadOutput {
                            Text("Estimated Muscular Load: \(Int(load.muscularLoad.rounded()))/100 · Confidence: \(load.confidence.rawValue.capitalized)")
                                .font(StrandFont.subhead)
                                .foregroundStyle(StrandPalette.metricCyan)
                        }
                    }
                }
                .screenPadding()
                .padding(.vertical)
            }
            .background(StrandPalette.surfaceBase)
            .navigationTitle("Edit strength workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        saving = true
                        Task {
                            let saved = await viewModel.saveCompletedEdits()
                            saving = false
                            if saved { onDone() }
                        }
                    }
                    .disabled(saving)
                }
            }
            .task {
                await viewModel.loadCompleted(
                    repository: repository, sessionId: sessionId,
                    bodyweightKg: model.profile.weightKg)
            }
            .alert("Could not save strength workout", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showingPicker) {
                ExercisePicker(viewModel: viewModel)
                    .strengthSheetPresentation(largeFirst: true)
            }
            .sheet(item: $historyExercise) { exercise in
                ExerciseHistorySheet(exerciseId: exercise.exerciseId,
                                     exerciseName: viewModel.displayName(for: exercise))
                    .environmentObject(repository)
                    .strengthSheetPresentation(largeFirst: true)
            }
        }
    }

    private func bestE1RM(_ sets: [StrengthSetRecord]) -> Double? {
        sets.compactMap { set in
            guard set.completed, let weight = set.weightKg, let reps = set.reps else {
                return nil
            }
            return MuscularLoadEngine.estimatedOneRepMax(weightKg: weight, reps: reps)
        }.max()
    }
}

extension View {
    @ViewBuilder
    func strengthSheetPresentation(largeFirst: Bool) -> some View {
        #if os(iOS)
        self.noopSheetPresentation(largeFirst: largeFirst)
        #else
        self.frame(minWidth: 520, minHeight: largeFirst ? 680 : 520)
        #endif
    }
}

private struct ExerciseHistorySheet: View {
    let exerciseId: String
    let exerciseName: String
    @EnvironmentObject private var repository: Repository
    @Environment(\.dismiss) private var dismiss
    @State private var history: [ExercisePerformanceRecord] = []

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    Text("No previous sessions")
                        .foregroundStyle(StrandPalette.textSecondary)
                }
                ForEach(history) { performance in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(Date(timeIntervalSince1970: TimeInterval(
                                performance.startedAt)).formatted(
                                    date: .abbreviated, time: .omitted))
                            Spacer()
                            if performance.sessionId == personalBestSessionId {
                                Label("Personal best", systemImage: "trophy.fill")
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.statusWarning)
                            }
                        }
                        Text(setSummary(performance.sets))
                            .font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary)
                        if let e1RM = bestE1RM(performance.sets) {
                            Text(String(
                                format: String(localized: "Estimated 1RM: %.1f kg"),
                                e1RM))
                                .font(StrandFont.footnote)
                                .foregroundStyle(StrandPalette.metricCyan)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(exerciseName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard let store = await repository.storeHandle() else { return }
                history = (try? await store.exercisePerformanceHistory(
                    deviceId: repository.deviceId, exerciseId: exerciseId)) ?? []
            }
        }
    }

    private var personalBestSessionId: String? {
        history.compactMap { performance in
            bestE1RM(performance.sets).map { (performance.sessionId, $0) }
        }.max { $0.1 < $1.1 }?.0
    }

    private func bestE1RM(_ sets: [StrengthSetRecord]) -> Double? {
        sets.compactMap { set in
            guard set.completed, let weight = set.weightKg, let reps = set.reps else {
                return nil
            }
            return MuscularLoadEngine.estimatedOneRepMax(weightKg: weight, reps: reps)
        }.max()
    }

    private func setSummary(_ sets: [StrengthSetRecord]) -> String {
        sets.filter(\.completed).prefix(8).map {
            let weight = $0.weightKg.map { String(format: "%.1f kg", $0) }
                ?? String(localized: "Bodyweight")
            return "\(weight) × \($0.reps.map(String.init) ?? "—")"
        }.joined(separator: " · ")
    }
}

// One source file compiles on iOS and macOS without importing UIKit/AppKit into the shared view.
private enum UIKeyboardTypeCompat { case decimalPad, numberPad }

private extension View {
    @ViewBuilder
    func keyboardTypeCompat(_ type: UIKeyboardTypeCompat) -> some View {
        #if os(iOS)
        switch type {
        case .decimalPad: self.keyboardType(.decimalPad)
        case .numberPad: self.keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }
}
