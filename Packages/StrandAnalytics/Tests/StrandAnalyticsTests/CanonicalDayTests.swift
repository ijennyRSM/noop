import XCTest
@testable import StrandAnalytics

final class CanonicalDayTests: XCTestCase {
    private let bangkok = TimeZone(identifier: "Asia/Bangkok")!

    func testGregorianKeyIsNotParsedAsBuddhistYear() throws {
        let parsed = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok))
        let gregorian = CanonicalDay.calendar(timeZone: bangkok)
        let components = gregorian.dateComponents([.year, .month, .day], from: parsed)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 28)
        XCTAssertEqual(
            CanonicalDay.key(for: parsed, timeZone: bangkok),
            "2026-07-28"
        )

        var buddhist = Calendar(identifier: .buddhist)
        buddhist.locale = Locale(identifier: "th_TH")
        buddhist.timeZone = bangkok
        XCTAssertEqual(buddhist.component(.year, from: parsed), 2569)
    }

    func testStrictParsingRejectsMalformedAndImpossibleKeys() {
        XCTAssertNil(CanonicalDay.date(from: "2026-2-3", timeZone: bangkok))
        XCTAssertNil(CanonicalDay.date(from: "2026-02-30", timeZone: bangkok))
        XCTAssertNil(CanonicalDay.date(from: "not-a-day", timeZone: bangkok))
    }

    func testFreshnessDistancesUseLocalGregorianDates() throws {
        let now = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok)?
                .addingTimeInterval(20 * 3_600)
        )
        XCTAssertEqual(
            CanonicalDay.daysBetween("2026-07-28", now, timeZone: bangkok), 0)
        XCTAssertEqual(
            CanonicalDay.daysBetween("2026-07-27", now, timeZone: bangkok), 1)
        XCTAssertEqual(
            CanonicalDay.daysBetween("2026-07-26", now, timeZone: bangkok), 2)
        XCTAssertEqual(
            CanonicalDay.daysBetween("2026-07-29", now, timeZone: bangkok), -1)
    }

    func testCalendarWindowsCrossMonthAndYearBoundaries() throws {
        let now = try XCTUnwrap(
            CanonicalDay.date(from: "2026-01-02", timeZone: bangkok)?
                .addingTimeInterval(12 * 3_600)
        )
        let sevenStart = try XCTUnwrap(
            CanonicalDay.startOfWindow(
                daysIncludingToday: 7, now: now, timeZone: bangkok))
        XCTAssertEqual(
            CanonicalDay.key(for: sevenStart, timeZone: bangkok),
            "2025-12-27"
        )
        XCTAssertTrue(CanonicalDay.isInWindow(
            key: "2025-12-27", from: sevenStart, through: now,
            timeZone: bangkok))
        XCTAssertTrue(CanonicalDay.isInWindow(
            key: "2026-01-02", from: sevenStart, through: now,
            timeZone: bangkok))
        XCTAssertFalse(CanonicalDay.isInWindow(
            key: "2025-12-26", from: sevenStart, through: now,
            timeZone: bangkok))
    }

    func testJulyWindowsHaveExactCalendarBoundaries() throws {
        let now = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok)?
                .addingTimeInterval(12 * 3_600)
        )
        let calendar = CanonicalDay.calendar(timeZone: bangkok)
        let seven = try XCTUnwrap(CanonicalDay.startOfWindow(
            daysIncludingToday: 7, now: now, timeZone: bangkok))
        let twentyEight = try XCTUnwrap(CanonicalDay.startOfWindow(
            daysIncludingToday: 28, now: now, timeZone: bangkok))
        let priorThirty = try XCTUnwrap(calendar.date(
            byAdding: .day, value: -30,
            to: calendar.startOfDay(for: now)))
        XCTAssertEqual(CanonicalDay.key(for: seven, timeZone: bangkok),
                       "2026-07-22")
        XCTAssertEqual(CanonicalDay.key(for: twentyEight, timeZone: bangkok),
                       "2026-07-01")
        XCTAssertEqual(CanonicalDay.key(for: priorThirty, timeZone: bangkok),
                       "2026-06-28")
        XCTAssertEqual(
            CanonicalDay.daysBetween("2026-06-28", now, timeZone: bangkok),
            30
        )
    }
}
