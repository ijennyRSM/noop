import XCTest
import WhoopStore
@testable import StrandAnalytics

final class WeeklyMuscleLoadEngineTests: XCTestCase {
    func testSumsRawStimulusBeforeNormalizing() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2024, month: 1, day: 1, hour: 20)
        ))
        let rows = [
            row(daysBefore: 0, raw: 900, now: now, calendar: calendar),
            row(daysBefore: 1, raw: 900, now: now, calendar: calendar),
        ]
        let result = WeeklyMuscleLoadEngine.aggregate(
            rows: rows, now: now, calendar: calendar)
        let first = try XCTUnwrap(result.first)
        XCTAssertEqual(first.rawStimulus, 1_800, accuracy: 0.001)
        XCTAssertEqual(first.normalizedLoad, 50, accuracy: 0.001)
        XCTAssertEqual(first.sessionCount, 2)
    }

    func testCalendarWindowExcludesEightDayOldSession() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let now = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2024, month: 1, day: 1, hour: 20)
        ))
        let rows = [
            row(daysBefore: 0, raw: 1_800, now: now, calendar: calendar),
            row(daysBefore: 8, raw: 9_000, now: now, calendar: calendar),
        ]
        let result = WeeklyMuscleLoadEngine.aggregate(
            rows: rows, now: now, calendar: calendar)
        let first = try XCTUnwrap(result.first)
        XCTAssertEqual(first.rawStimulus, 1_800, accuracy: 0.001)
    }

    private func row(daysBefore: Int, raw: Double, now: Date,
                     calendar: Calendar) -> MuscleTrainingLoadRecord {
        let date = calendar.date(byAdding: .day, value: -daysBefore,
                                 to: calendar.startOfDay(for: now))!
            .addingTimeInterval(12 * 3_600)
        return .init(
            trainedAt: Int(date.timeIntervalSince1970),
            muscleId: "quadriceps",
            side: "both",
            rawStimulus: raw,
            normalizedLoad: 50,
            confidence: "high"
        )
    }
}
