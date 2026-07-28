import XCTest
import WhoopStore
@testable import StrandAnalytics

final class MuscularLoadEngineTests: XCTestCase {
    private let squat = ExerciseDefinition(
        id: "barbell_back_squat", canonicalName: "Barbell Back Squat",
        equipment: ["barbell"], movementPattern: "squat", laterality: "bilateral",
        loadType: "external",
        muscles: [
            .init(muscleId: "quadriceps", role: "primary", weight: 0.60),
            .init(muscleId: "glutes", role: "secondary", weight: 0.40),
        ],
        source: "test", sourceURL: "", license: "test", licenseURL: "",
        libraryVersion: 1)

    private func input(weight: Double = 80, reps: Int = 8, rpe: Double? = 8,
                       rir: Double? = nil, type: StrengthSetType = .working) -> MuscularLoadEngine.SetInput {
        .init(set: .init(setIndex: 0, setType: type.rawValue, weightKg: weight,
                         reps: reps, rpe: rpe, rir: rir, completed: true),
              exercise: squat)
    }

    func testWarmupProducesLessStimulusThanWorkingSet() {
        let working = MuscularLoadEngine.calculate(inputs: [input()])
        let warmup = MuscularLoadEngine.calculate(inputs: [input(type: .warmup)])
        XCTAssertGreaterThan(working.muscles[0].rawStimulus, warmup.muscles[0].rawStimulus)
    }

    func testWeightRepsAndEffortIncreaseStimulus() {
        let light = MuscularLoadEngine.calculate(inputs: [input(weight: 40, reps: 5, rpe: 6)])
        let hard = MuscularLoadEngine.calculate(inputs: [input(weight: 80, reps: 10, rpe: 10)])
        XCTAssertGreaterThan(hard.muscles[0].rawStimulus, light.muscles[0].rawStimulus)
    }

    func testRIRInfluencesStimulusAndFallbackIsFinite() {
        let nearFailure = MuscularLoadEngine.calculate(inputs: [input(rpe: nil, rir: 0)])
        let easy = MuscularLoadEngine.calculate(inputs: [input(rpe: nil, rir: 5)])
        let fallback = MuscularLoadEngine.calculate(inputs: [input(rpe: nil, rir: nil)])
        XCTAssertGreaterThan(nearFailure.muscles[0].rawStimulus, easy.muscles[0].rawStimulus)
        XCTAssertTrue(fallback.muscularLoad.isFinite)
    }

    func testBodyweightFallbackLowersConfidenceAndStaysFinite() {
        var bodyweight = squat
        bodyweight.loadType = "bodyweight"
        bodyweight.effectiveBodyweightCoefficient = 0.65
        let result = MuscularLoadEngine.calculate(inputs: [
            .init(set: .init(setIndex: 0, reps: 12, completed: true), exercise: bodyweight),
        ])
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.assumptions.contains("Bodyweight fallback used"))
        XCTAssertTrue(result.muscularLoad.isFinite)
    }

    func testPrimaryReceivesMoreThanSecondary() {
        let result = MuscularLoadEngine.calculate(inputs: [input()])
        let quad = result.muscles.first { $0.muscleId == "quadriceps" }!
        let glute = result.muscles.first { $0.muscleId == "glutes" }!
        XCTAssertGreaterThan(quad.rawStimulus, glute.rawStimulus)
    }

    func testPersonalHistoryChangesNormalization() {
        let cold = MuscularLoadEngine.calculate(inputs: [input()])
        let history = [
            MuscularLoadEngine.MuscleHistory(muscleId: "quadriceps",
                                             rawStimuli: [100, 110, 120, 130]),
            MuscularLoadEngine.MuscleHistory(muscleId: "glutes",
                                             rawStimuli: [100, 110, 120, 130]),
        ]
        let trained = MuscularLoadEngine.calculate(inputs: [input()], history: history)
        XCTAssertNotEqual(cold.muscularLoad, trained.muscularLoad)
    }

    func testResidualDecaysAndRepeatedTrainingAccumulates() {
        let now = Date()
        let recent = MuscularLoadEngine.HistoricalMuscleLoad(
            muscleId: "quadriceps", load: 80,
            trainedAt: now.addingTimeInterval(-12 * 3_600), confidence: .high)
        let old = MuscularLoadEngine.HistoricalMuscleLoad(
            muscleId: "quadriceps", load: 80,
            trainedAt: now.addingTimeInterval(-48 * 3_600), confidence: .high)
        let one = MuscularLoadEngine.residualLoads(history: [recent], at: now)[0]
        let repeated = MuscularLoadEngine.residualLoads(history: [recent, old], at: now)[0]
        XCTAssertGreaterThan(repeated.residualLoad, one.residualLoad)
        XCTAssertLessThan(one.residualLoad, recent.load)
    }

    func testTotalTrainingLoadCasesAndBounds() {
        XCTAssertEqual(MuscularLoadEngine.totalTrainingLoad(
            cardiovascularEffort: 10.5, muscularLoad: nil)!, 50, accuracy: 0.001)
        XCTAssertEqual(MuscularLoadEngine.totalTrainingLoad(
            cardiovascularEffort: nil, muscularLoad: 75)!, 75, accuracy: 0.001)
        XCTAssertNil(MuscularLoadEngine.totalTrainingLoad(
            cardiovascularEffort: nil, muscularLoad: nil))
        let mixed = MuscularLoadEngine.totalTrainingLoad(
            cardiovascularEffort: 2, muscularLoad: 95)!
        XCTAssertGreaterThan(mixed, 60)
        XCTAssertTrue((0...100).contains(mixed))
    }

    func testEpleyGuardrails() {
        XCTAssertEqual(MuscularLoadEngine.estimatedOneRepMax(weightKg: 100, reps: 6)!,
                       120, accuracy: 0.001)
        XCTAssertNil(MuscularLoadEngine.estimatedOneRepMax(weightKg: 100, reps: 20))
        XCTAssertNil(MuscularLoadEngine.estimatedOneRepMax(weightKg: -1, reps: 5))
    }
}
