import XCTest
@testable import WhoopStore

final class CardiovascularEffortTests: XCTestCase {
    func testExplicitScalesNormalizeWithoutMagnitudeInference() {
        let stored = CardiovascularEffortValue(
            rawValue: 10.5, scale: .noop100, source: .stored)
        let imported = CardiovascularEffortValue(
            rawValue: 10.5, scale: .whoop21, source: .whoopCSVImport)

        XCTAssertEqual(stored.normalized100, 10.5, accuracy: 0.000_001)
        XCTAssertEqual(imported.normalized100, 50, accuracy: 0.000_001)
    }

    func testRoundTripBetweenNoopAndWhoopAxes() {
        let effort = CardiovascularEffortValue(
            rawValue: 73.25, scale: .noop100, source: .stored)
        let whoop = effort.value(on: .whoop21)
        let restored = CardiovascularEffortValue(
            rawValue: whoop, scale: .whoop21, source: .whoopCSVImport)

        XCTAssertEqual(restored.normalized100, 73.25, accuracy: 0.000_001)
    }

    func testInvalidAndOutOfRangeValuesAreClamped() {
        XCTAssertEqual(
            CardiovascularEffortValue(
                rawValue: .infinity, scale: .noop100, source: .unknown
            ).normalized100,
            0
        )
        XCTAssertEqual(
            CardiovascularEffortValue(
                rawValue: 30, scale: .whoop21, source: .whoopCSVImport
            ).normalized100,
            100
        )
    }
}
