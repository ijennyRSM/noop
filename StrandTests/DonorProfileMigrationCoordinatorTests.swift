import XCTest
@testable import Strand

@MainActor
final class DonorProfileMigrationCoordinatorTests: XCTestCase {
    func testPreparesReviewOnceAndExcludesTransientSorenessAndPain() throws {
        let suite = "DonorProfileMigrationCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let profile = LocalCoachProfile(
            primaryGoals: ["Build strength"],
            sportsAndActivities: ["Football"],
            experienceLevel: "Intermediate",
            preferredTrainingDays: ["Tuesday"],
            availableMinutes: 45,
            availableEquipment: ["Dumbbells"],
            trainingLimitations: "Old knee issue",
            preferredLanguage: "th")
        defaults.set(try JSONEncoder().encode(profile), forKey: LocalCoachPreferences.profileKey)
        defaults.set(Data("must-not-migrate".utf8), forKey: LocalCoachPreferences.sorenessKey)

        DonorProfileMigrationCoordinator.prepareIfNeeded(defaults: defaults)
        let pending = try XCTUnwrap(DonorProfileMigrationCoordinator.pending(defaults: defaults))
        XCTAssertEqual(pending.goals, ["Build strength"])
        XCTAssertEqual(pending.limitationsNeedingConfirmation, ["Old knee issue"])
        XCTAssertEqual(pending.preferredLanguage, "th")
        XCTAssertFalse(pending.ordinaryMemory.contains { $0.localizedCaseInsensitiveContains("pain") })
        XCTAssertFalse(pending.ordinaryMemory.contains { $0.localizedCaseInsensitiveContains("sore") })

        let first = pending
        DonorProfileMigrationCoordinator.prepareIfNeeded(defaults: defaults)
        XCTAssertEqual(DonorProfileMigrationCoordinator.pending(defaults: defaults), first,
                       "preparation must be idempotent")
    }
}
