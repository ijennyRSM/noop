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
        let thaiSquat = try await store.searchExercises(query: "สควอตด้วยบาร์เบล", limit: 20)
        XCTAssertTrue(thaiSquat.contains { $0.id == "barbell_squat" })
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

    func testDerivedCommitRollsBackAllRowsOnInjectedFailure() async throws {
        let store = try await WhoopStore.inMemory()
        let session = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_000,
            status: StrengthSessionStatus.completed.rawValue)
        let commit = StrengthDerivedCommit(
            session: session,
            day: "2023-11-14",
            muscleLoads: [
                .init(day: "2023-11-14", muscleId: "quadriceps",
                      rawStimulus: 1_000, normalizedLoad: 60,
                      workingSets: 4, confidence: "medium"),
            ]
        )

        do {
            try await store.commitStrengthDerived(commit, failAt: .afterMuscleLoads)
            XCTFail("injected transaction failure must throw")
        } catch { }

        let rolledBackSession = try await store.strengthSession(id: session.id)
        let rolledBackLoads = try await store.strengthSessionMuscleLoads(
            sessionId: session.id)
        let rolledBackDaily = try await store.dailyMuscleLoads(
            deviceId: "test", from: "2023-11-14", to: "2023-11-14")
        XCTAssertNil(rolledBackSession)
        XCTAssertTrue(rolledBackLoads.isEmpty)
        XCTAssertTrue(rolledBackDaily.isEmpty)
    }

    func testDerivedCommitKeepsSessionsSeparateAndRebuildsDailyRawLoad() async throws {
        let store = try await WhoopStore.inMemory()
        let day = "2023-11-14"
        let first = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_000,
            status: StrengthSessionStatus.completed.rawValue)
        let second = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_003_600,
            status: StrengthSessionStatus.completed.rawValue)
        for (session, raw, normalized) in [(first, 800.0, 55.0), (second, 1_100.0, 70.0)] {
            try await store.commitStrengthDerived(.init(
                session: session,
                day: day,
                muscleLoads: [
                    .init(day: day, muscleId: "quadriceps",
                          rawStimulus: raw, normalizedLoad: normalized,
                          workingSets: 3, confidence: "high"),
                ]
            ))
        }

        let firstLoads = try await store.strengthSessionMuscleLoads(sessionId: first.id)
        let secondLoads = try await store.strengthSessionMuscleLoads(sessionId: second.id)
        XCTAssertEqual(firstLoads.first?.rawStimulus, 800)
        XCTAssertEqual(secondLoads.first?.rawStimulus, 1_100)
        let daily = try await store.dailyMuscleLoads(
            deviceId: "test", from: day, to: day)
        XCTAssertEqual(daily.first?.rawStimulus, 1_900)
        XCTAssertEqual(daily.first?.normalizedLoad, 70,
                       "daily rows must not sum bounded normalized scores")

        try await store.deleteStrengthSession(id: second.id)
        let rebuilt = try await store.dailyMuscleLoads(
            deviceId: "test", from: day, to: day)
        XCTAssertEqual(rebuilt.first?.rawStimulus, 800)
        XCTAssertEqual(rebuilt.first?.normalizedLoad, 55)
    }

    func testRestoreRebuildRegeneratesDailyAggregateAndDropsResidualCache() async throws {
        let store = try await WhoopStore.inMemory()
        let session = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_000,
            status: StrengthSessionStatus.completed.rawValue)
        try await store.commitStrengthDerived(.init(
            session: session,
            day: "2023-11-14",
            muscleLoads: [
                .init(day: "2023-11-14", muscleId: "quadriceps",
                      rawStimulus: 900, normalizedLoad: 58,
                      workingSets: 3, confidence: "high"),
            ],
            residualSnapshot: [
                .init(capturedAt: 1_700_000_100, muscleId: "quadriceps",
                      residualLoad: 44, confidence: "high",
                      lastTrainedAt: 1_700_000_000),
            ],
            residualCapturedAt: 1_700_000_100
        ))

        try await store.rebuildStrengthDerivedCaches()

        let daily = try await store.dailyMuscleLoads(
            deviceId: "test", from: "2023-11-14", to: "2023-11-14")
        let residual = try await store.latestResidualLoads(deviceId: "test")
        XCTAssertEqual(daily.first?.rawStimulus, 900)
        XCTAssertEqual(daily.first?.normalizedLoad, 58)
        XCTAssertTrue(residual.isEmpty)
    }

    func testDerivedCommitRelabelsDetectedWorkoutAtomically() async throws {
        let store = try await WhoopStore.inMemory()
        let workout = WorkoutRow(
            startTs: 1_000, endTs: 2_000, sport: "detected",
            source: "detected", durationS: 1_000, energyKcal: 100,
            avgHr: 120, maxHr: 160, strain: 48,
            distanceM: nil, zonesJSON: #"{"z2":50}"#, notes: nil)
        try await store.upsertWorkouts([workout], deviceId: "computed")
        let session = StrengthSessionRecord(
            deviceId: "strap", workoutStartTs: 1_000, startedAt: 1_000,
            endedAt: 2_000, status: StrengthSessionStatus.completed.rawValue)
        try await store.commitStrengthDerived(.init(
            session: session,
            day: "1970-01-01",
            muscleLoads: [],
            detectedWorkoutRelabel: .init(
                sourceDeviceId: "computed",
                targetDeviceId: "strap",
                workout: workout,
                targetSport: "Strength Training"
            )
        ))

        let detected = try await store.workouts(
            deviceId: "computed", from: 0, to: 3_000, limit: 10)
        XCTAssertTrue(detected.isEmpty)
        let manual = try await store.workouts(
            deviceId: "strap", from: 0, to: 3_000, limit: 10)
        XCTAssertEqual(manual.first?.sport, "Strength Training")
        XCTAssertEqual(manual.first?.source, "manual")
    }

    func testRelabelOnSameNaturalKeyUpdatesInsteadOfDeletingWorkout() async throws {
        let store = try await WhoopStore.inMemory()
        let workout = WorkoutRow(
            startTs: 1_000, endTs: 2_000, sport: "Strength Training",
            source: "detected", durationS: 1_000, energyKcal: nil,
            avgHr: 120, maxHr: 160, strain: 48,
            distanceM: nil, zonesJSON: nil, notes: nil)
        try await store.upsertWorkouts([workout], deviceId: "strap")
        let session = StrengthSessionRecord(
            deviceId: "strap", workoutStartTs: 1_000, startedAt: 1_000,
            endedAt: 2_000, status: StrengthSessionStatus.completed.rawValue)
        try await store.commitStrengthDerived(.init(
            session: session,
            day: "1970-01-01",
            muscleLoads: [],
            detectedWorkoutRelabel: .init(
                sourceDeviceId: "strap",
                targetDeviceId: "strap",
                workout: workout,
                targetSport: "Strength Training"
            )
        ))

        let rows = try await store.workouts(
            deviceId: "strap", from: 0, to: 3_000, limit: 10)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.source, "manual")
    }

    func testSorenessAndPainAreStoredSeparatelyAndDeletionIsSoft() async throws {
        let store = try await WhoopStore.inMemory()
        let soreness = SorenessCheckInRecord(
            deviceId: "test", recordedAt: 1_700_000_000,
            overallSoreness: 4, perMuscleSoreness: ["quadriceps": 8],
            note: "Legs feel worked")
        let pain = PainCheckInRecord(
            deviceId: "test", recordedAt: 1_700_000_100,
            painPresent: true, note: "User-entered caution")
        try await store.saveSorenessCheckIn(soreness)
        try await store.savePainCheckIn(pain)

        let storedSoreness = try await store.latestSorenessCheckIn(deviceId: "test")
        let storedPain = try await store.latestPainCheckIn(deviceId: "test")
        XCTAssertEqual(storedSoreness, soreness)
        XCTAssertEqual(storedPain, pain)

        try await store.deleteSorenessCheckIn(id: soreness.id)
        let deletedSoreness = try await store.latestSorenessCheckIn(deviceId: "test")
        let retainedPain = try await store.latestPainCheckIn(deviceId: "test")
        XCTAssertNil(deletedSoreness)
        XCTAssertEqual(retainedPain, pain,
                       "deleting soreness must not delete or rewrite pain")
    }

    func testStrengthPlanLinkStartsUnboundAndCanCompleteAfterSessionFinalizes() async throws {
        let store = try await WhoopStore.inMemory()
        let proposal = UUID().uuidString
        try await store.upsertStrengthPlanLink(.init(
            proposalId: proposal,
            canonicalActivityId: "strength_training",
            createdAt: 1_700_000_000
        ))
        let unbound = try await store.strengthPlanLink(proposalId: proposal)
        XCTAssertNil(unbound?.sessionId)
        let pending = try await store.pendingStrengthPlanLink(
            forSessionStartedAt: 1_700_000_100)
        XCTAssertEqual(pending?.proposalId, proposal)
        let unrelatedLaterSession = try await store.pendingStrengthPlanLink(
            forSessionStartedAt: 1_700_100_000)
        XCTAssertNil(unrelatedLaterSession,
                     "an abandoned plan must not attach to an unrelated future workout")

        let session = StrengthSessionRecord(
            deviceId: "test", startedAt: 1_700_000_100,
            endedAt: 1_700_003_000, status: StrengthSessionStatus.completed.rawValue)
        try await store.saveStrengthSession(session)
        try await store.upsertStrengthPlanLink(.init(
            proposalId: proposal, sessionId: session.id,
            canonicalActivityId: "strength_training",
            createdAt: 1_700_000_000, completedAt: 1_700_003_000
        ))
        let storedLink = try await store.strengthPlanLink(proposalId: proposal)
        let linked = try XCTUnwrap(storedLink)
        XCTAssertEqual(linked.sessionId, session.id)
        XCTAssertEqual(linked.completedAt, 1_700_003_000)
    }
}
