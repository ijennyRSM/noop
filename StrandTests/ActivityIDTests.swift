import XCTest
@testable import Strand

final class ActivityIDTests: XCTestCase {
    func testStrengthAliasesResolveThroughStableIDs() {
        for id in [
            "strength_training", "strength", "weight_training",
            "functional_strength_training", "traditional_strength_training",
            "powerlifting", "bodybuilding",
        ] {
            XCTAssertTrue(ActivityID.isStrength(activityID: id, canonicalSport: nil))
        }
    }

    func testLocalizedDisplayDoesNotControlStrengthRouting() {
        XCTAssertTrue(ActivityID.isStrength(
            activityID: "strength_training",
            canonicalSport: "การฝึกความแข็งแรง"
        ))
        XCTAssertFalse(ActivityID.isStrength(
            activityID: "running",
            canonicalSport: "การวิ่ง"
        ))
    }

    func testCatalogueExposesStableActivityID() {
        XCTAssertEqual(
            WorkoutCatalog.sport(named: "Strength Training")?.activityID,
            "strength_training"
        )
    }
}
