import XCTest
@testable import Strand
import WhoopStore

@MainActor
final class CoachSnapshotTests: XCTestCase {
    private func metric(_ current: Double? = nil, _ seven: Double? = nil,
                        _ baseline: Double? = nil) -> CoachSnapshot.Metric {
        .init(
            current: current, average7: seven, baseline30: baseline,
            difference: zip(current, baseline).map { $0.0 - $0.1 },
            percentDifference: nil, trend: .stable,
            sevenDayAvailableCount: current == nil ? 0 : 1,
            sevenDayExpectedCount: 7,
            baselineAvailableCount: baseline == nil ? 0 : 20,
            baselineExpectedCount: 30,
            currentDayAvailable: current != nil,
            source: "test", timeRange: "test")
    }

    func testFormatterSeparatesSleepDurationFromRestScore() {
        let snapshot = CoachSnapshot(
            recovery: .init(
                charge: metric(70, 65, 62), hrv: metric(55, 52, 50),
                restingHR: metric(50, 51, 52), respiratoryRate: metric(),
                skinTemperatureDeviation: metric(), spo2: metric(),
                consecutiveMeaningfulDeviationDays: 0),
            sleep: .init(
                durationMinutes: metric(288, 360, 390),
                restScore: metric(78, 74, 72),
                sleepNeedMinutes: 480, versusNeedMinutes: -192, debtMinutes: 120,
                efficiencyPercent: 88, consistencyPercent: 80, deepMinutes: 60,
                remMinutes: 70, lightMinutes: 158, restorativeMinutes: 130,
                disturbances: 4, bedtime: nil, wakeTime: nil, naps: 0,
                debtTrend: .rising),
            training: .init(
                workoutCount7: 3, workoutCount28: 12,
                durationMinutes7: 180, durationMinutes28: 750,
                cardiovascularEffortTotal7: 140,
                cardiovascularEffortTotal28: 520,
                cardiovascularEffortAverage7: 46.7,
                acuteLoad: 46.7, chronicLoad: 43.3, acuteChronicRatio: 1.08,
                monotony: 1.2, consecutiveHardDays: 0, hoursSinceHardWorkout: 30,
                frequentActivities: ["Strength Training"], readiness: "balanced",
                readinessDrivers: [], availableDayCount28: 20,
                expectedDayCount28: 28),
            strength: nil)
        let output = CoachSnapshotFormatter.format(snapshot)
        XCTAssertTrue(output.contains("Sleep duration: latest 4 h 48 min"))
        XCTAssertTrue(output.contains("Rest score (separate from duration): latest 78.0/100"))
        XCTAssertFalse(output.contains("Rest score (separate from duration): latest 288"))
    }

    func testFormatterNeverIncludesRawSensorChannels() {
        let snapshot = CoachSnapshot(
            recovery: .init(
                charge: metric(), hrv: metric(), restingHR: metric(),
                respiratoryRate: metric(), skinTemperatureDeviation: metric(),
                spo2: metric(), consecutiveMeaningfulDeviationDays: 0),
            sleep: .init(
                durationMinutes: metric(), restScore: metric(),
                sleepNeedMinutes: nil, versusNeedMinutes: nil, debtMinutes: nil,
                efficiencyPercent: nil, consistencyPercent: nil, deepMinutes: nil,
                remMinutes: nil, lightMinutes: nil, restorativeMinutes: nil,
                disturbances: nil, bedtime: nil, wakeTime: nil, naps: 0,
                debtTrend: .insufficient),
            training: .init(
                workoutCount7: 0, workoutCount28: 0,
                durationMinutes7: 0, durationMinutes28: 0,
                cardiovascularEffortTotal7: 0, cardiovascularEffortTotal28: 0,
                cardiovascularEffortAverage7: nil, acuteLoad: nil, chronicLoad: nil,
                acuteChronicRatio: nil, monotony: nil, consecutiveHardDays: 0,
                hoursSinceHardWorkout: nil, frequentActivities: [],
                readiness: "insufficient", readinessDrivers: [],
                availableDayCount28: 0, expectedDayCount28: 28),
            strength: nil)
        let output = CoachSnapshotFormatter.format(snapshot).lowercased()
        XCTAssertFalse(output.contains("spo2red"))
        XCTAssertFalse(output.contains("spo2ir"))
        XCTAssertFalse(output.contains("accelerometer"))
        XCTAssertFalse(output.contains("gyroscope"))
        XCTAssertFalse(output.contains("gps points"))
        XCTAssertFalse(output.contains("rrinterval"))
    }

    func testDetailedStrengthSelectionIsDeterministic() {
        XCTAssertTrue(CoachSnapshotBuilder.shouldIncludeDetailedStrength(
            question: "How should I progress my squat sets and RPE?"))
        XCTAssertTrue(CoachSnapshotBuilder.shouldIncludeDetailedStrength(
            question: "วันนี้ควรเล่นเวทขาไหม"))
        XCTAssertFalse(CoachSnapshotBuilder.shouldIncludeDetailedStrength(
            question: "How was my sleep last night?"))
    }

    func testDefaultCoachPromptSupportsMultipleModalitiesAndMuscularCaveat() {
        let prompt = AICoachEngine.defaultSystemPrompt
        XCTAssertTrue(prompt.contains("strength training"))
        XCTAssertTrue(prompt.contains("football"))
        XCTAssertTrue(prompt.contains("swimming"))
        XCTAssertTrue(prompt.contains(
            "Low cardiovascular Effort during strength training does not prove low muscular fatigue."))
        XCTAssertTrue(prompt.contains("Never fabricate a missing score or metric."))
    }

    func testMetricUsesCalendarWindowsAndReportsStaleFreshness() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 28, hour: 12))!
        let value = CoachSnapshotBuilder.metric([
            ("2026-06-20", 999),
            ("2026-07-20", 20),
            ("2026-07-26", 40),
        ], now: now)
        XCTAssertEqual(value.current, 40)
        XCTAssertEqual(value.average7, 40)
        XCTAssertEqual(value.baseline30, 30)
        XCTAssertEqual(value.sevenDayAvailableCount, 1)
        XCTAssertEqual(value.baselineAvailableCount, 2)
        XCTAssertEqual(value.freshness, .stale)
    }

    func testLatestStrengthMusclesComeOnlyFromRequestedSessionLoads() {
        let morning: [DailyMuscleLoadRecord] = [
            .init(day: "2026-07-28", muscleId: "quadriceps",
                  rawStimulus: 1_000, normalizedLoad: 80,
                  workingSets: 5, confidence: "high"),
        ]
        let evening: [DailyMuscleLoadRecord] = [
            .init(day: "2026-07-28", muscleId: "chest",
                  rawStimulus: 900, normalizedLoad: 70,
                  workingSets: 4, confidence: "high"),
        ]
        let latest = CoachSnapshotBuilder.sessionMuscles(
            sessionLoads: evening,
            residualByMuscle: ["chest": 55, "quadriceps": 60]
        )
        XCTAssertEqual(latest.map(\.id), ["chest"])
        XCTAssertFalse(latest.contains { $0.id == morning[0].muscleId })
    }

    func testRecentWorkoutFormattingIncludesZonesButNoRawStreamsAndIsBounded() {
        var snapshot = CoachSnapshot(
            recovery: .init(
                charge: metric(), hrv: metric(), restingHR: metric(),
                respiratoryRate: metric(), skinTemperatureDeviation: metric(),
                spo2: metric(), consecutiveMeaningfulDeviationDays: 0),
            sleep: .init(
                durationMinutes: metric(), restScore: metric(),
                sleepNeedMinutes: nil, versusNeedMinutes: nil, debtMinutes: nil,
                efficiencyPercent: nil, consistencyPercent: nil,
                deepMinutes: nil, remMinutes: nil, lightMinutes: nil,
                restorativeMinutes: nil, disturbances: nil,
                bedtime: nil, wakeTime: nil, naps: 0, debtTrend: .insufficient),
            training: .init(
                workoutCount7: 1, workoutCount28: 1,
                durationMinutes7: 60, durationMinutes28: 60,
                cardiovascularEffortTotal7: 75,
                cardiovascularEffortTotal28: 75,
                cardiovascularEffortAverage7: 75,
                acuteLoad: nil, chronicLoad: nil, acuteChronicRatio: nil,
                monotony: nil, consecutiveHardDays: 1,
                hoursSinceHardWorkout: 1,
                frequentActivities: ["Running"],
                readiness: "balanced", readinessDrivers: [],
                availableDayCount28: 1, expectedDayCount28: 28),
            strength: nil)
        snapshot.training.recentWorkouts = [
            .init(activity: "Running", startedAt: Date(timeIntervalSince1970: 100),
                  durationMinutes: 60, cardiovascularEffort: 75,
                  zoneMinutes: [5, 10, 20, 15, 5]),
        ]
        let output = CoachSnapshotFormatter.format(snapshot, maxCharacters: 6_000)
        XCTAssertLessThanOrEqual(output.count, 6_000)
        XCTAssertTrue(output.contains("Z3 20 min"))
        XCTAssertFalse(output.lowercased().contains("rrinterval"))
        XCTAssertFalse(output.lowercased().contains("gps points"))
    }

    func testThaiDeviceFreshnessUsesGregorianLocalCalendarDays() throws {
        let bangkok = try XCTUnwrap(TimeZone(identifier: "Asia/Bangkok"))
        let now = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok)?
                .addingTimeInterval(20 * 3_600)
        )
        let current = CoachSnapshotBuilder.metric(
            [("2026-07-28", 80)], now: now, timeZone: bangkok)
        let recent = CoachSnapshotBuilder.metric(
            [("2026-07-27", 70)], now: now, timeZone: bangkok)
        let stale = CoachSnapshotBuilder.metric(
            [("2026-07-26", 60)], now: now, timeZone: bangkok)
        let future = CoachSnapshotBuilder.metric(
            [("2026-07-29", 90)], now: now, timeZone: bangkok)

        XCTAssertEqual(current.freshness, .current)
        XCTAssertTrue(current.currentDayAvailable)
        XCTAssertEqual(recent.freshness, .recent)
        XCTAssertFalse(recent.currentDayAvailable)
        XCTAssertEqual(stale.freshness, .stale)
        XCTAssertEqual(future.freshness, .unavailable)
    }

    func testMetricCoverageCountsUniqueGregorianDaysAndExcludesTodayFromBaseline() throws {
        let bangkok = try XCTUnwrap(TimeZone(identifier: "Asia/Bangkok"))
        let now = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok)?
                .addingTimeInterval(12 * 3_600)
        )
        let value = CoachSnapshotBuilder.metric([
            ("2026-07-28", 80),
            ("2026-07-28", 82),
        ], now: now, timeZone: bangkok)
        XCTAssertEqual(value.current, 82)
        XCTAssertEqual(value.freshness, .current)
        XCTAssertEqual(value.sevenDayAvailableCount, 1)
        XCTAssertEqual(value.sevenDayExpectedCount, 7)
        XCTAssertEqual(value.baselineAvailableCount, 0)
        XCTAssertEqual(value.baselineExpectedCount, 30)
    }

    func testFormatterExplainsCurrentFreshnessCoverageAndNaturalDurations() throws {
        let bangkok = try XCTUnwrap(TimeZone(identifier: "Asia/Bangkok"))
        let generated = try XCTUnwrap(
            CanonicalDay.date(from: "2026-07-28", timeZone: bangkok)?
                .addingTimeInterval(19 * 3_600 + 45 * 60)
        )
        var currentMetric = metric(80, 80, nil)
        currentMetric.observedDay = "2026-07-28"
        currentMetric.freshness = .current
        currentMetric.currentDayAvailable = true
        currentMetric.sevenDayAvailableCount = 1
        currentMetric.baselineAvailableCount = 0
        var sleepDuration = currentMetric
        sleepDuration.current = 286.7
        sleepDuration.average7 = 286.7

        var snapshot = CoachSnapshot(
            recovery: .init(
                charge: currentMetric, hrv: currentMetric,
                restingHR: currentMetric, respiratoryRate: currentMetric,
                skinTemperatureDeviation: metric(), spo2: metric(),
                consecutiveMeaningfulDeviationDays: 0),
            sleep: .init(
                durationMinutes: sleepDuration, restScore: currentMetric,
                sleepNeedMinutes: nil, versusNeedMinutes: nil, debtMinutes: nil,
                efficiencyPercent: nil, consistencyPercent: nil,
                deepMinutes: nil, remMinutes: nil, lightMinutes: nil,
                restorativeMinutes: nil, disturbances: nil,
                bedtime: nil, wakeTime: nil, naps: 0, debtTrend: .insufficient),
            training: .init(
                workoutCount7: 1, workoutCount28: 1,
                durationMinutes7: 64, durationMinutes28: 64,
                cardiovascularEffortTotal7: 59.8,
                cardiovascularEffortTotal28: 59.8,
                cardiovascularEffortAverage7: 59.8,
                acuteLoad: nil, chronicLoad: nil, acuteChronicRatio: nil,
                monotony: nil, consecutiveHardDays: 0,
                hoursSinceHardWorkout: nil, frequentActivities: ["Football"],
                readiness: "balanced", readinessDrivers: [],
                availableDayCount28: 1, expectedDayCount28: 28),
            strength: nil,
            generatedAt: generated)
        snapshot.training.recentWorkouts = [
            .init(
                activity: "Football", startedAt: generated.addingTimeInterval(-3_600),
                durationMinutes: 64, cardiovascularEffort: 59.8,
                zoneMinutes: nil),
        ]

        let output = CoachSnapshotFormatter.format(
            snapshot, timeZone: bangkok)
        XCTAssertTrue(output.contains("Generated local date: 2026-07-28"))
        XCTAssertTrue(output.contains("Generated local time: 19:45"))
        XCTAssertTrue(output.contains("Asia/Bangkok (UTC+07:00)"))
        XCTAssertTrue(output.contains("Sleep duration: latest 4 h 47 min"))
        XCTAssertTrue(output.contains("Duration: 1 h 4 min"))
        XCTAssertTrue(output.contains("freshness current"))
        XCTAssertTrue(output.contains(
            "30-day baseline coverage 0/30 prior days"))
        XCTAssertTrue(output.contains("28-day training coverage: 1/28 days"))
        XCTAssertTrue(output.contains("2026-07-28 (today)"))
        XCTAssertTrue(output.contains(
            "Do not describe a metric marked current as stale"))
        XCTAssertFalse(output.contains("286.7 min"))
        XCTAssertFalse(output.contains("64.0 min"))
        XCTAssertFalse(output.contains("Daily-data completeness"))
        XCTAssertFalse(output.contains("freshness stale"))
    }

    func testDefaultPromptSeparatesCurrentFreshnessFromBaselineCoverage() {
        let prompt = AICoachEngine.defaultSystemPrompt
        XCTAssertEqual(AICoachEngine.defaultSystemPromptVersion, 3)
        XCTAssertTrue(prompt.contains(
            "Do not describe a metric marked current as stale"))
        XCTAssertTrue(prompt.contains(
            "0/30 prior baseline days can coexist with a valid current value"))
    }

    private func zip(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}
