import Foundation
import WhoopStore

/// Original, transparent V1 estimate derived from user-entered strength work. It is not a
/// physiological measurement and does not estimate muscle damage, inflammation, or injury risk.
public enum MuscularLoadEngine {
    public struct Configuration: Equatable, Sendable {
        public var warmupFactor: Double = 0.35
        public var workingFactor: Double = 1.0
        public var dropFactor: Double = 0.9
        public var failureFactor: Double = 1.12
        public var defaultEffortFactor: Double = 0.82
        public var bodyweightFallbackKg: Double = 55
        public var coldStartReference: Double = 1_800
        public var cardioWeight: Double = 0.50
        public var muscularWeight: Double = 0.50
        public var defaultHalfLifeHours: Double = 30

        public init() {}
    }

    public struct SetInput: Equatable, Sendable {
        public var set: StrengthSetRecord
        public var exercise: ExerciseDefinition
        public var userBodyweightKg: Double?
        public var estimatedOneRepMaxKg: Double?

        public init(set: StrengthSetRecord, exercise: ExerciseDefinition,
                    userBodyweightKg: Double? = nil, estimatedOneRepMaxKg: Double? = nil) {
            self.set = set
            self.exercise = exercise
            self.userBodyweightKg = userBodyweightKg
            self.estimatedOneRepMaxKg = estimatedOneRepMaxKg
        }
    }

    public struct MuscleHistory: Equatable, Sendable {
        public var muscleId: String
        /// Completed-session raw stimuli from the preceding 28 days.
        public var rawStimuli: [Double]

        public init(muscleId: String, rawStimuli: [Double]) {
            self.muscleId = muscleId
            self.rawStimuli = rawStimuli
        }
    }

    public struct MuscleOutput: Equatable, Sendable {
        public var muscleId: String
        public var side: String
        public var rawStimulus: Double
        public var normalizedLoad: Double
        public var workingSets: Int

        public init(muscleId: String, side: String, rawStimulus: Double,
                    normalizedLoad: Double, workingSets: Int) {
            self.muscleId = muscleId
            self.side = side
            self.rawStimulus = rawStimulus
            self.normalizedLoad = normalizedLoad
            self.workingSets = workingSets
        }
    }

    public struct SessionOutput: Equatable, Sendable {
        public var muscularLoad: Double
        public var muscles: [MuscleOutput]
        public var confidence: StrengthConfidence
        public var assumptions: [String]

        public init(muscularLoad: Double, muscles: [MuscleOutput],
                    confidence: StrengthConfidence, assumptions: [String]) {
            self.muscularLoad = muscularLoad
            self.muscles = muscles
            self.confidence = confidence
            self.assumptions = assumptions
        }
    }

    public struct HistoricalMuscleLoad: Equatable, Sendable {
        public var muscleId: String
        public var side: String
        public var load: Double
        public var trainedAt: Date
        public var confidence: StrengthConfidence

        public init(muscleId: String, side: String = StrengthSide.both.rawValue,
                    load: Double, trainedAt: Date, confidence: StrengthConfidence) {
            self.muscleId = muscleId
            self.side = side
            self.load = load
            self.trainedAt = trainedAt
            self.confidence = confidence
        }
    }

    public struct RecoveryModifiers: Equatable, Sendable {
        public var sleepHours: Double?
        public var sleepDebtHours: Double?
        public var charge: Double?
        public var soreness: Double?

        public init(sleepHours: Double? = nil, sleepDebtHours: Double? = nil,
                    charge: Double? = nil, soreness: Double? = nil) {
            self.sleepHours = sleepHours
            self.sleepDebtHours = sleepDebtHours
            self.charge = charge
            self.soreness = soreness
        }
    }

    public struct ResidualOutput: Equatable, Sendable {
        public var muscleId: String
        public var side: String
        public var residualLoad: Double
        public var lastTrainedAt: Date?
        public var confidence: StrengthConfidence

        public init(muscleId: String, side: String, residualLoad: Double,
                    lastTrainedAt: Date?, confidence: StrengthConfidence) {
            self.muscleId = muscleId
            self.side = side
            self.residualLoad = residualLoad
            self.lastTrainedAt = lastTrainedAt
            self.confidence = confidence
        }
    }

    public static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, weightKg.isFinite, (1...12).contains(reps) else { return nil }
        // Epley: weight × (1 + reps / 30). Useful for conventional externally loaded sets only.
        return weightKg * (1 + Double(reps) / 30)
    }

    public static func calculate(inputs: [SetInput], history: [MuscleHistory] = [],
                                 configuration: Configuration = .init()) -> SessionOutput {
        let valid = inputs.filter { input in
            input.set.completed
                && (input.set.reps ?? 0) > 0
                && input.exercise.muscles.contains { $0.weight > 0 }
        }
        guard !valid.isEmpty else {
            return SessionOutput(muscularLoad: 0, muscles: [], confidence: .low,
                                 assumptions: ["No completed strength sets"])
        }

        var raw: [String: Double] = [:]
        var counts: [String: Int] = [:]
        var assumptions = Set<String>()
        var qualityPoints = 0
        var qualityMaximum = 0

        for input in valid {
            let set = input.set
            let reps = max(1, set.reps ?? 1)
            let load: Double
            if input.exercise.loadType == StrengthLoadType.bodyweight.rawValue {
                let coefficient = input.exercise.effectiveBodyweightCoefficient ?? 0.50
                if let bodyweight = input.userBodyweightKg, bodyweight > 0 {
                    load = bodyweight * coefficient + max(0, set.weightKg ?? 0)
                    qualityPoints += 1
                } else {
                    load = configuration.bodyweightFallbackKg * coefficient
                    assumptions.insert("Bodyweight fallback used")
                }
                qualityMaximum += 1
            } else if let weight = set.weightKg, weight >= 0, weight.isFinite {
                load = weight
                qualityPoints += 1
                qualityMaximum += 1
            } else {
                load = 1
                qualityMaximum += 1
                assumptions.insert("Rep-only fallback used")
            }

            let effort = effortFactor(rpe: set.rpe, rir: set.rir,
                                      fallback: configuration.defaultEffortFactor)
            qualityMaximum += 1
            if set.rpe != nil || set.rir != nil { qualityPoints += 1 }
            let relative = relativeIntensityFactor(
                weightKg: load, estimatedOneRepMaxKg: input.estimatedOneRepMaxKg)
            if input.estimatedOneRepMaxKg != nil { qualityPoints += 1 }
            qualityMaximum += 1
            let type = setTypeFactor(set.setType, configuration: configuration)
            var stimulus = load * Double(reps) * effort * relative * type
            if input.exercise.laterality == StrengthLaterality.unilateral.rawValue,
               set.side == StrengthSide.both.rawValue {
                stimulus *= 2
                assumptions.insert("Unrecorded unilateral sides split equally")
            }

            for muscle in input.exercise.muscles {
                let side = set.side
                let key = "\(muscle.muscleId)|\(side)"
                raw[key, default: 0] += stimulus * muscle.weight
                if set.setType != StrengthSetType.warmup.rawValue {
                    counts[key, default: 0] += 1
                }
            }
        }

        let historyByMuscle = Dictionary(uniqueKeysWithValues: history.map { ($0.muscleId, $0.rawStimuli) })
        let outputs = raw.map { key, value -> MuscleOutput in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            let muscle = parts[0]
            let side = parts.count > 1 ? parts[1] : StrengthSide.both.rawValue
            return MuscleOutput(
                muscleId: muscle, side: side, rawStimulus: finiteNonnegative(value),
                normalizedLoad: normalized(raw: value, history: historyByMuscle[muscle] ?? [],
                                           coldReference: configuration.coldStartReference),
                workingSets: counts[key, default: 0])
        }.sorted {
            if $0.normalizedLoad == $1.normalizedLoad { return $0.muscleId < $1.muscleId }
            return $0.normalizedLoad > $1.normalizedLoad
        }

        let values = outputs.map(\.normalizedLoad)
        let rms = sqrt(values.map { $0 * $0 }.reduce(0, +) / Double(max(1, values.count)))
        let peak = values.max() ?? 0
        // Peak-preserving blend: a heavily loaded muscle cannot vanish in a whole-session average.
        let session = clamp(0.70 * rms + 0.30 * peak)
        let quality = qualityMaximum > 0 ? Double(qualityPoints) / Double(qualityMaximum) : 0
        let confidence: StrengthConfidence
        if valid.count >= 3, quality >= 0.72, history.count >= 3 {
            confidence = .high
        } else if valid.count >= 1, quality >= 0.35 {
            confidence = .medium
        } else {
            confidence = .low
        }
        if history.count < 3 { assumptions.insert("Cold-start personal normalization") }
        return SessionOutput(muscularLoad: session, muscles: outputs,
                             confidence: confidence, assumptions: assumptions.sorted())
    }

    public static func residualLoads(history: [HistoricalMuscleLoad], at now: Date,
                                     halfLifeHours: [String: Double] = [:],
                                     recovery: RecoveryModifiers = .init(),
                                     configuration: Configuration = .init()) -> [ResidualOutput] {
        let grouped = Dictionary(grouping: history) { "\($0.muscleId)|\($0.side)" }
        let multiplier = recoveryMultiplier(recovery)
        return grouped.compactMap { key, rows in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard let first = parts.first else { return nil }
            let halfLife = max(12, halfLifeHours[first] ?? configuration.defaultHalfLifeHours)
            let validRows = rows.filter { now >= $0.trainedAt && $0.load.isFinite && $0.load >= 0 }
            guard !validRows.isEmpty else { return nil }
            let residual = validRows.reduce(0.0) { total, row in
                let hours = now.timeIntervalSince(row.trainedAt) / 3_600
                return total + row.load * pow(0.5, hours / halfLife)
            }
            let confidence = validRows.map(\.confidence).min(by: {
                confidenceRank($0) < confidenceRank($1)
            }) ?? .low
            return ResidualOutput(
                muscleId: first,
                side: parts.count > 1 ? parts[1] : StrengthSide.both.rawValue,
                residualLoad: clamp(residual * multiplier),
                lastTrainedAt: validRows.map(\.trainedAt).max(),
                confidence: confidence)
        }.sorted {
            if $0.residualLoad == $1.residualLoad { return $0.muscleId < $1.muscleId }
            return $0.residualLoad > $1.residualLoad
        }
    }

    /// Combined score without overwriting cardiovascular Effort. A weighted RMS preserves a high
    /// component; `max` contributes a small guard so strength-only/cardio-only sessions remain visible.
    public static func totalTrainingLoad(
        cardiovascularEffort: CardiovascularEffortValue?,
        muscularLoad: Double?,
                                         configuration: Configuration = .init()) -> Double? {
        let cardio = cardiovascularEffort.map { clamp($0.normalized100) }
        let muscle = muscularLoad.map(clamp)
        switch (cardio, muscle) {
        case (nil, nil): return nil
        case (let value?, nil), (nil, let value?): return value
        case (let cardio?, let muscle?):
            let cw = max(0, configuration.cardioWeight)
            let mw = max(0, configuration.muscularWeight)
            let denominator = max(0.0001, cw + mw)
            let rms = sqrt((cw * cardio * cardio + mw * muscle * muscle) / denominator)
            return clamp(0.90 * rms + 0.10 * max(cardio, muscle))
        }
    }

    /// Compatibility entry point for values already read from NOOP storage.
    /// It deliberately treats every numeric value as 0...100 and never infers a scale.
    public static func totalTrainingLoad(
        storedCardiovascularEffort: Double?,
        muscularLoad: Double?,
        configuration: Configuration = .init()
    ) -> Double? {
        totalTrainingLoad(
            cardiovascularEffort: CardiovascularEffortValue.stored(storedCardiovascularEffort),
            muscularLoad: muscularLoad,
            configuration: configuration
        )
    }

    private static func effortFactor(rpe: Double?, rir: Double?, fallback: Double) -> Double {
        if let rpe, rpe.isFinite { return min(1.25, max(0.55, 0.50 + 0.07 * rpe)) }
        if let rir, rir.isFinite { return min(1.20, max(0.55, 1.12 - 0.08 * rir)) }
        return fallback
    }

    private static func relativeIntensityFactor(weightKg: Double, estimatedOneRepMaxKg: Double?) -> Double {
        guard let e1rm = estimatedOneRepMaxKg, e1rm > 0, e1rm.isFinite else { return 1 }
        let ratio = min(1.10, max(0.20, weightKg / e1rm))
        return 0.75 + 0.50 * ratio
    }

    private static func setTypeFactor(_ raw: String, configuration: Configuration) -> Double {
        switch raw {
        case StrengthSetType.warmup.rawValue: configuration.warmupFactor
        case StrengthSetType.drop.rawValue: configuration.dropFactor
        case StrengthSetType.failure.rawValue: configuration.failureFactor
        default: configuration.workingFactor
        }
    }

    private static func normalized(raw: Double, history: [Double], coldReference: Double) -> Double {
        let valid = history.filter { $0 > 0 && $0.isFinite }.sorted()
        let reference: Double
        if valid.count >= 3 {
            let middle = valid.count / 2
            reference = valid.count.isMultiple(of: 2)
                ? (valid[middle - 1] + valid[middle]) / 2
                : valid[middle]
        } else {
            reference = coldReference
        }
        guard raw > 0, reference > 0 else { return 0 }
        // 50 means the user's recent median. Each doubling adds 22 points; each halving removes 22.
        return clamp(50 + 22 * log2(raw / reference))
    }

    /// Public normalization primitive for aggregate views. The caller supplies an
    /// already-computed personal reference so raw stimuli are combined before the
    /// bounded 0...100 display score is produced.
    public static func normalizedLoad(raw: Double, reference: Double) -> Double {
        guard raw > 0, raw.isFinite, reference > 0, reference.isFinite else { return 0 }
        return clamp(50 + 22 * log2(raw / reference))
    }

    private static func recoveryMultiplier(_ recovery: RecoveryModifiers) -> Double {
        var result = 1.0
        if let sleep = recovery.sleepHours {
            result += min(0.08, max(-0.06, (7 - sleep) * 0.02))
        }
        if let debt = recovery.sleepDebtHours {
            result += min(0.08, max(0, debt * 0.015))
        }
        if let charge = recovery.charge {
            result += min(0.06, max(-0.05, (50 - charge) / 1_000))
        }
        if let soreness = recovery.soreness {
            result += min(0.08, max(0, soreness / 100))
        }
        return min(1.15, max(0.88, result))
    }

    private static func confidenceRank(_ value: StrengthConfidence) -> Int {
        switch value { case .low: 0; case .medium: 1; case .high: 2 }
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(0, value))
    }

    private static func finiteNonnegative(_ value: Double) -> Double {
        value.isFinite ? max(0, value) : 0
    }
}
