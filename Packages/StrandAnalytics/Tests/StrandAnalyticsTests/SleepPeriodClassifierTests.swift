import XCTest
@testable import StrandAnalytics

final class SleepPeriodClassifierTests: XCTestCase {
    func testSplitMainNightIsOneGroupAndDaytimeBlockIsNap() {
        let day = 1_700_000_000
        let periods: [SleepPeriodClassifier.Period] = [
            .init(start: day + 22 * 3_600, end: day + 26 * 3_600),
            .init(start: day + 26 * 3_600 + 20 * 60, end: day + 30 * 3_600),
            .init(start: day + 34 * 3_600, end: day + 35 * 3_600),
        ]
        let result = SleepPeriodClassifier.classify(periods, offsetSec: 0)
        XCTAssertEqual(result.mainIndices, [0, 1])
        XCTAssertEqual(result.napIndices, [2])
    }

    func testEmptyPeriodsAreUnavailableNotFabricated() {
        let result = SleepPeriodClassifier.classify([], offsetSec: 0)
        XCTAssertTrue(result.mainIndices.isEmpty)
        XCTAssertTrue(result.napIndices.isEmpty)
    }
}
