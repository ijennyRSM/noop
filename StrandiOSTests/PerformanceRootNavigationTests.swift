#if os(iOS)
import XCTest
@testable import NOOP_Staging

final class PerformanceRootNavigationTests: XCTestCase {
    func testRootDestinationsHaveStableTruthfulOrder() {
        XCTAssertEqual(
            PerformanceRootDestination.allCases.map(\.rawValue),
            [0, 1, 2, 3]
        )
        XCTAssertEqual(
            PerformanceRootDestination.allCases.map(\.icon),
            ["house", "heart.text.square", "chart.bar.fill", "line.3.horizontal"]
        )
    }

    func testPersistedSelectionRejectsRetiredOrInvalidTabs() {
        XCTAssertEqual(PerformanceRootDestination.sanitizedTag(0), 0)
        XCTAssertEqual(PerformanceRootDestination.sanitizedTag(3), 3)
        XCTAssertEqual(PerformanceRootDestination.sanitizedTag(4), 0)
        XCTAssertEqual(PerformanceRootDestination.sanitizedTag(-1), 0)
    }

    func testSelectionStorageKeyRemainsStable() {
        XCTAssertEqual(
            PerformanceRootDestination.selectionStorageKey,
            "noop.performance.selectedRootTab"
        )
    }

    func testCriticalPerformanceRoutesRemainAvailable() {
        let routes: [MoreDestination] = [
            .strength, .soreness, .workouts, .dataSources,
            .backupSync, .coachSettings, .settings,
        ]
        XCTAssertEqual(Set(routes).count, routes.count)
    }
}
#endif
