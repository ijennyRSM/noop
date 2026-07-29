import XCTest
@testable import Strand

final class CoachDurationFormatterTests: XCTestCase {
    func testUnsignedDurationsUseNaturalHoursAndMinutes() {
        let cases: [(Double, String)] = [
            (0, "0 min"),
            (15, "15 min"),
            (59.4, "59 min"),
            (59.6, "1 h"),
            (60, "1 h"),
            (64, "1 h 4 min"),
            (120, "2 h"),
            (286.7, "4 h 47 min"),
        ]
        for (minutes, expected) in cases {
            XCTAssertEqual(
                CoachDurationFormatter.format(minutes: minutes),
                expected,
                "\(minutes) minutes"
            )
        }
    }

    func testSignedDurations() {
        XCTAssertEqual(
            CoachDurationFormatter.formatSigned(minutes: 32),
            "+32 min"
        )
        XCTAssertEqual(
            CoachDurationFormatter.formatSigned(minutes: -32),
            "-32 min"
        )
        XCTAssertEqual(
            CoachDurationFormatter.formatSigned(minutes: -193),
            "-3 h 13 min"
        )
        XCTAssertEqual(
            CoachDurationFormatter.formatSigned(minutes: 0),
            "0 min"
        )
    }

    func testMissingInvalidAndNegativeUnsignedDurations() {
        XCTAssertEqual(
            CoachDurationFormatter.format(minutes: nil),
            "missing"
        )
        XCTAssertEqual(
            CoachDurationFormatter.format(minutes: .nan),
            "missing"
        )
        XCTAssertEqual(
            CoachDurationFormatter.format(minutes: .infinity),
            "missing"
        )
        XCTAssertEqual(
            CoachDurationFormatter.format(minutes: -10),
            "0 min"
        )
    }
}
