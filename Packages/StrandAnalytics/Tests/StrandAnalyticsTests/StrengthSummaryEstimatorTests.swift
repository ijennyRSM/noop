import XCTest
@testable import StrandAnalytics

final class StrengthSummaryEstimatorTests: XCTestCase {
    func testIntensityRPEAndDurationAdjustScoreWithinBounds() {
        let baseline = StrengthSummaryEstimator.estimate(
            region: .lowerBody, intensity: .moderate,
            rpe: nil, durationMinutes: nil)
        let harder = StrengthSummaryEstimator.estimate(
            region: .lowerBody, intensity: .moderate,
            rpe: 8, durationMinutes: 75)

        XCTAssertEqual(baseline.score, 45, accuracy: 0.001)
        XCTAssertGreaterThan(harder.score, baseline.score)
        XCTAssertLessThanOrEqual(harder.score, 100)
    }

    func testRegionContributionsSumToOne() {
        for region in StrengthSummaryEstimator.Region.allCases {
            XCTAssertEqual(
                StrengthSummaryEstimator.contributions(region).values.reduce(0, +),
                1,
                accuracy: 0.000_001
            )
        }
    }

    func testEstimateDoesNotInventSetsOrLaterality() {
        let estimate = StrengthSummaryEstimator.estimate(
            region: .fullBody, intensity: .hard,
            rpe: 8, durationMinutes: 60)
        XCTAssertEqual(estimate.source, "detected-summary-v2")
        XCTAssertTrue(estimate.muscles.allSatisfy {
            $0.workingSets == 0 && $0.side == "both"
        })
    }
}
