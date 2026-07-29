import XCTest
@testable import StrandDesign

final class PerformanceScorePaletteTests: XCTestCase {
    override func tearDown() {
        StrandPalette.chartStyle = .titanium
        super.tearDown()
    }

    func testChargeUsesDiscreteInclusiveBands() {
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 0), .chargePoor)
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 33), .chargePoor)
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 34), .chargeModerate)
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 66), .chargeModerate)
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 67), .chargeGood)
        XCTAssertEqual(PerformanceScorePalette.chargeToken(score: 100), .chargeGood)
    }

    func testTodayAndDetailResolveTheSameSemanticColor() {
        XCTAssertEqual(
            PerformanceScorePalette.token(for: .charge, score: 41, style: .compact),
            PerformanceScorePalette.token(for: .charge, score: 41, style: .hero)
        )
        XCTAssertEqual(
            PerformanceScorePalette.token(for: .rest, score: 92, style: .compact),
            PerformanceScorePalette.token(for: .rest, score: 92, style: .hero)
        )
        XCTAssertEqual(
            PerformanceScorePalette.token(for: .effort, score: 33.2, style: .compact),
            PerformanceScorePalette.token(for: .effort, score: 33.2, style: .hero)
        )
    }

    func testPrimaryScoreColorsIgnoreEveryChartStyle() {
        let expected: [PerformanceScoreColorToken] = [
            .chargeModerate, .rest, .effort,
        ]
        for style in ChartStyle.allCases {
            StrandPalette.chartStyle = style
            XCTAssertEqual(
                [
                    PerformanceScorePalette.token(for: .charge, score: 41),
                    PerformanceScorePalette.token(for: .rest, score: 92),
                    PerformanceScorePalette.token(for: .effort, score: 33.2),
                ],
                expected,
                "\(style) changed a primary score identity"
            )
        }
    }

    func testScoreFormattingUsesPercentOnlyWhereItIsSemantic() {
        XCTAssertEqual(
            PerformanceScoreFormatter.text(metric: .rest, score: 92).combined,
            "92%"
        )
        XCTAssertEqual(
            PerformanceScoreFormatter.text(metric: .charge, score: 41).combined,
            "41%"
        )
        XCTAssertEqual(
            PerformanceScoreFormatter.text(metric: .effort, score: 33.2, decimals: 1).combined,
            "33.2"
        )
        XCTAssertEqual(
            PerformanceScoreFormatter.text(metric: .effort, score: nil, decimals: 1).combined,
            "–"
        )
    }

    func testRingStylesUseExplicitBalancedGeometry() {
        XCTAssertLessThan(MetricRingStyle.compact.diameter, MetricRingStyle.hero.diameter)
        XCTAssertEqual(MetricRingStyle.compact.diameter, 92)
        XCTAssertEqual(MetricRingStyle.hero.diameter, 248)
        XCTAssertEqual(MetricRingStyle.compact.strokeWidth, 6)
        XCTAssertEqual(MetricRingStyle.hero.strokeWidth, 9.5)
        XCTAssertGreaterThanOrEqual(MetricRingStyle.compact.valueFontToRingRatio, 0.35)
        XCTAssertGreaterThanOrEqual(MetricRingStyle.hero.valueFontToRingRatio, 0.30)
    }
}
