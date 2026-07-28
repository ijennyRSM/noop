import XCTest
@testable import WhoopStore

final class StrengthStoreTests: XCTestCase {
    func testExerciseLibrarySeedsIdempotentlyAndSearchesAliases() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.ensureExerciseLibrarySeeded()
        let first = try await store.exerciseLibraryCount()
        try await store.ensureExerciseLibrarySeeded()
        let second = try await store.exerciseLibraryCount()
        XCTAssertEqual(first, 420)
        XCTAssertEqual(second, first)
        let rdl = try await store.searchExercises(query: "RDL", limit: 20)
        XCTAssertTrue(rdl.contains { $0.canonicalName.localizedCaseInsensitiveContains("Romanian") })
    }

    func testEveryBundledExerciseHasValidIdentityMusclesAndLicense() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.ensureExerciseLibrarySeeded()
        let all = try await store.searchExercises(limit: 1_000)
        XCTAssertGreaterThanOrEqual(all.count, 300)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        let known = Set(NOOPMuscle.allCases.map(\.rawValue))
        for exercise in all {
            XCTAssertFalse(exercise.canonicalName.isEmpty)
            XCTAssertFalse(exercise.equipment.isEmpty)
            XCTAssertFalse(exercise.muscles.isEmpty)
            XCTAssertTrue(exercise.muscles.allSatisfy { known.contains($0.muscleId) })
            XCTAssertEqual(exercise.muscles.reduce(0) { $0 + $1.weight }, 1, accuracy: 0.001)
            XCTAssertFalse(exercise.source.isEmpty)
            XCTAssertFalse(exercise.license.isEmpty)
            XCTAssertFalse(exercise.sourceURL.isEmpty)
        }
    }

    func testCustomExerciseAndSoftDeletePreserveSessionSnapshot() async throws {
        let store = try await WhoopStore.inMemory()
        let custom = ExerciseDefinition(
            id: "custom-\(UUID().uuidString)", canonicalName: "My Cable Press",
            aliases: ["Press A"], equipment: ["cable"], movementPattern: "horizontal_push",
            laterality: "bilateral", loadType: "external",
            muscles: [.init(muscleId: "chest", role: "primary", weight: 1)],
            source: "NOOP user", sourceURL: "", license: "User-created", licenseURL: "",
            libraryVersion: 0, builtIn: false)
        try await store.saveCustomExercise(custom)
        let customSaved = try await store.exerciseDefinition(id: custom.id)
        XCTAssertEqual(customSaved?.canonicalName, custom.canonicalName)
        let session = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_000,
            exercises: [.init(
                exerciseId: custom.id, snapshotName: custom.canonicalName, orderIndex: 0,
                sets: [.init(setIndex: 0, weightKg: 20, reps: 10, rpe: 8,
                             completed: true)])])
        try await store.saveStrengthSession(session)
        try await store.softDeleteCustomExercise(id: custom.id)
        let deleted = try await store.exerciseDefinition(id: custom.id)
        let history = try await store.strengthSession(id: session.id)
        XCTAssertNil(deleted)
        XCTAssertEqual(history?.exercises.first?.snapshotName, custom.canonicalName)
    }

    func testStrengthSessionAutosaveEditAndCascade() async throws {
        let store = try await WhoopStore.inMemory()
        var session = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_000,
            exercises: [.init(
                exerciseId: "barbell_back_squat", snapshotName: "Barbell Back Squat",
                orderIndex: 0,
                sets: [.init(setIndex: 0, weightKg: 80, reps: 5, completed: true)])])
        try await store.saveStrengthSession(session)
        session.exercises[0].sets[0].weightKg = 82.5
        session.exercises[0].sets.append(
            .init(setIndex: 1, weightKg: 82.5, reps: 5, rir: 2, completed: true))
        try await store.saveStrengthSession(session)
        let loaded = try await store.strengthSession(id: session.id)
        let saved = try XCTUnwrap(loaded)
        XCTAssertEqual(saved.exercises[0].sets.count, 2)
        XCTAssertEqual(saved.exercises[0].sets[0].weightKg, 82.5)
        try await store.deleteStrengthSession(id: session.id)
        let removed = try await store.strengthSession(id: session.id)
        XCTAssertNil(removed)
    }

    func testRejectsNegativeWeightAndDuplicateSetIndexes() async throws {
        let store = try await WhoopStore.inMemory()
        let invalid = StrengthSessionRecord(
            deviceId: "test", startedAt: 1,
            exercises: [.init(
                exerciseId: "x", snapshotName: "X", orderIndex: 0,
                sets: [
                    .init(setIndex: 0, weightKg: -1, reps: 5),
                    .init(setIndex: 0, weightKg: 1, reps: 5),
                ])])
        do {
            try await store.saveStrengthSession(invalid)
            XCTFail("invalid sets must be rejected")
        } catch { }
    }

    func testTemplateRoundTripAndDelete() async throws {
        let store = try await WhoopStore.inMemory()
        let template = WorkoutTemplateRecord(
            name: "Lower A",
            exercises: [.init(
                exerciseId: "barbell_back_squat", snapshotName: "Barbell Back Squat",
                orderIndex: 0,
                sets: [.init(setIndex: 0, weightKg: 60, reps: 8)])])
        try await store.saveWorkoutTemplate(template)
        let loadedTemplates = try await store.workoutTemplates()
        let saved = try XCTUnwrap(loadedTemplates.first)
        XCTAssertEqual(saved.name, "Lower A")
        XCTAssertEqual(saved.exercises.first?.sets.first?.reps, 8)
        try await store.deleteWorkoutTemplate(id: template.id)
        let remainingTemplates = try await store.workoutTemplates()
        XCTAssertTrue(remainingTemplates.isEmpty)
    }

    func testDailyAndResidualLoadsRoundTrip() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.upsertDailyMuscleLoads([
            .init(day: "2026-07-28", muscleId: "quadriceps",
                  rawStimulus: 1200, normalizedLoad: 72, workingSets: 5,
                  confidence: "high"),
        ], deviceId: "test")
        let daily = try await store.dailyMuscleLoads(
            deviceId: "test", from: "2026-07-28", to: "2026-07-28")
        XCTAssertEqual(daily.first?.normalizedLoad, 72)
        try await store.replaceResidualSnapshot([
            .init(capturedAt: 100, muscleId: "quadriceps",
                  residualLoad: 44, confidence: "high", lastTrainedAt: 50),
        ], deviceId: "test", capturedAt: 100)
        let residual = try await store.latestResidualLoads(deviceId: "test")
        XCTAssertEqual(residual.first?.residualLoad, 44)
    }
}
