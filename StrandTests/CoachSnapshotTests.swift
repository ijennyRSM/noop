import XCTest
@testable import Strand

final class CoachSnapshotTests: XCTestCase {
    private func metric(_ current: Double? = nil, _ seven: Double? = nil,
                        _ baseline: Double? = nil) -> CoachSnapshot.Metric {
        .init(
            current: current, average7: seven, baseline30: baseline,
            difference: zip(current, baseline).map { $0.0 - $0.1 },
            percentDifference: nil, trend: .stable,
            availableCount: current == nil ? 0 : 20, expectedCount: 30,
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
                readinessDrivers: [], completeness: 0.9),
            strength: nil)
        let output = CoachSnapshotFormatter.format(snapshot)
        XCTAssertTrue(output.contains("Sleep duration: current 288.0 min"))
        XCTAssertTrue(output.contains("Rest score (separate from duration): current 78.0/100"))
        XCTAssertFalse(output.contains("Rest score (separate from duration): current 288"))
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
                readiness: "insufficient", readinessDrivers: [], completeness: 0),
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

    private func zip(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}
