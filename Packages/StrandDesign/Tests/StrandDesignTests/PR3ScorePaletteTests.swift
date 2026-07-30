import SwiftUI
import XCTest
@testable import StrandDesign

/// Locks the score identity approved in PR #9 Milestone 1.
///
/// Secondary-screen work must not let a chart theme recolour the Today/detail
/// rings or soften the discrete Charge thresholds.
final class PR3ScorePaletteTests: XCTestCase {
    func testChargeUsesDiscreteApprovedBands() {
        assertColor(PR3ScorePalette.charge(0), equals: PR3ScorePalette.poorCharge)
        assertColor(PR3ScorePalette.charge(33), equals: PR3ScorePalette.poorCharge)
        assertColor(PR3ScorePalette.charge(34), equals: PR3ScorePalette.moderateCharge)
        assertColor(PR3ScorePalette.charge(66), equals: PR3ScorePalette.moderateCharge)
        assertColor(PR3ScorePalette.charge(67), equals: PR3ScorePalette.goodCharge)
        assertColor(PR3ScorePalette.charge(100), equals: PR3ScorePalette.goodCharge)
    }

    func testPrimaryScoreIdentityIsIndependentOfChartStyle() {
        let original = StrandPalette.chartStyle
        defer { StrandPalette.chartStyle = original }

        let expectedCharge = PR3ScorePalette.charge(50)
        let expectedRest = PR3ScorePalette.rest
        let expectedEffort = PR3ScorePalette.effort

        for style in ChartStyle.allCases {
            StrandPalette.chartStyle = style
            assertColor(PR3ScorePalette.charge(50), equals: expectedCharge)
            assertColor(PR3ScorePalette.rest, equals: expectedRest)
            assertColor(PR3ScorePalette.effort, equals: expectedEffort)
        }
    }

    func testRestAndEffortRemainDistinctWithoutPurple() {
        assertColor(PR3ScorePalette.rest, equals: Color(hex: "#8EB8D0"))
        assertColor(PR3ScorePalette.effort, equals: Color(hex: "#00AEEF"))

        let rest = PR3ScorePalette.rest.rgbaComponents
        let effort = PR3ScorePalette.effort.rgbaComponents
        XCTAssertGreaterThan(rest.g, rest.r)
        XCTAssertGreaterThan(effort.b, effort.r)
    }

    private func assertColor(
        _ actual: Color,
        equals expected: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lhs = actual.rgbaComponents
        let rhs = expected.rgbaComponents
        XCTAssertEqual(lhs.r, rhs.r, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.g, rhs.g, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.b, rhs.b, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.a, rhs.a, accuracy: 0.001, file: file, line: line)
    }
}
