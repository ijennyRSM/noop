import XCTest
@testable import Strand

final class LocalCoachProfileTests: XCTestCase {
    func testMissingSorenessDoesNotBecomeZero() {
        XCTAssertNil(CoachSorenessCheckIn().overallSoreness)
        XCTAssertEqual(
            LocalCoachPreferences.sorenessMultiplier(
                checkIn: CoachSorenessCheckIn(),
                muscleId: "quadriceps",
                now: Date()
            ),
            1
        )
    }

    func testSorenessInfluenceTapersAndExpires() {
        let recorded = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIn = CoachSorenessCheckIn(
            overallSoreness: 10, recordedAt: recorded)
        XCTAssertEqual(
            LocalCoachPreferences.sorenessMultiplier(
                checkIn: checkIn, muscleId: "quadriceps",
                now: recorded.addingTimeInterval(12 * 3_600)),
            1.15,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            LocalCoachPreferences.sorenessMultiplier(
                checkIn: checkIn, muscleId: "quadriceps",
                now: recorded.addingTimeInterval(48 * 3_600)),
            1.075,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            LocalCoachPreferences.sorenessMultiplier(
                checkIn: checkIn, muscleId: "quadriceps",
                now: recorded.addingTimeInterval(72 * 3_600)),
            1,
            accuracy: 0.000_001
        )
    }

    func testPerMuscleSorenessOverridesOverallAndPainDoesNotChangeLoad() {
        let now = Date()
        let withoutPain = CoachSorenessCheckIn(
            overallSoreness: 2,
            perMuscleSoreness: ["quadriceps": 8],
            recordedAt: now,
            painPresent: false
        )
        let withPain = CoachSorenessCheckIn(
            overallSoreness: 2,
            perMuscleSoreness: ["quadriceps": 8],
            recordedAt: now,
            painPresent: true,
            painNote: "knee"
        )
        let first = LocalCoachPreferences.sorenessMultiplier(
            checkIn: withoutPain, muscleId: "quadriceps", now: now)
        let second = LocalCoachPreferences.sorenessMultiplier(
            checkIn: withPain, muscleId: "quadriceps", now: now)
        XCTAssertEqual(first, 1.12, accuracy: 0.000_001)
        XCTAssertEqual(first, second, accuracy: 0.000_001)
    }

    func testProfileAndCheckInRoundTripLocally() throws {
        let suite = "LocalCoachProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = LocalCoachProfile(
            primaryGoals: ["strength"],
            sportsAndActivities: ["football"],
            experienceLevel: "intermediate",
            preferredTrainingDays: ["Monday"],
            availableMinutes: 45,
            availableEquipment: ["barbell"],
            trainingLimitations: "",
            preferredLanguage: "Thai"
        )
        let checkIn = CoachSorenessCheckIn(
            overallSoreness: 4, recordedAt: Date(timeIntervalSince1970: 100))
        LocalCoachPreferences.saveProfile(profile, defaults: defaults)
        LocalCoachPreferences.saveCheckIn(checkIn, defaults: defaults)
        XCTAssertEqual(LocalCoachPreferences.loadProfile(defaults: defaults), profile)
        XCTAssertEqual(LocalCoachPreferences.loadCheckIn(defaults: defaults), checkIn)
        LocalCoachPreferences.saveCheckIn(nil, defaults: defaults)
        XCTAssertNil(LocalCoachPreferences.loadCheckIn(defaults: defaults))
    }
}
