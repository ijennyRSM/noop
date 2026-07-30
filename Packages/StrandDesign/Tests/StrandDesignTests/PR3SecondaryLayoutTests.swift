import XCTest
@testable import StrandDesign

/// Protects the approved PR #9 Milestone 1 geometry while secondary screens
/// adopt a denser PR #3-derived rhythm. The two token sets must remain
/// intentionally separate: changing a settings row must not move Today.
final class PR3SecondaryLayoutTests: XCTestCase {
    func testApprovedPrimaryGeometryRemainsPinned() {
        XCTAssertEqual(NoopMetrics.cardRadius, 22)
        XCTAssertEqual(NoopMetrics.cardPadding, 16)
        XCTAssertEqual(NoopMetrics.sectionGap, 22)
        XCTAssertEqual(NoopMetrics.screenPadding, 18)
        XCTAssertEqual(NoopMetrics.screenHPadding, 20)
    }

    func testSecondaryGeometryIsCompactWithoutReplacingPrimaryTokens() {
        XCTAssertEqual(PR3SecondaryMetrics.cardRadius, 16)
        XCTAssertEqual(PR3SecondaryMetrics.cardPadding, 14)
        XCTAssertEqual(PR3SecondaryMetrics.sectionGap, 18)
        XCTAssertEqual(PR3SecondaryMetrics.screenPadding, 16)
        XCTAssertLessThan(PR3SecondaryMetrics.cardRadius, NoopMetrics.cardRadius)
        XCTAssertLessThan(PR3SecondaryMetrics.cardPadding, NoopMetrics.cardPadding)
    }

    func testSecondaryInteractiveControlsKeepPracticalHeight() {
        XCTAssertGreaterThanOrEqual(NoopMetrics.controlHeight, 44)
    }
}
