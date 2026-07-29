import Foundation
import WhoopStore

/// Transparent, versioned estimate used when a detected strength workout has no
/// exercise/set detail. It never invents exercises, set counts, laterality, or
/// measured muscle activation.
public enum StrengthSummaryEstimator {
    public static let sourceVersion = "detected-summary-v2"

    public enum Region: String, CaseIterable, Codable, Sendable, Hashable {
        case upperBody = "upper_body"
        case lowerBody = "lower_body"
        case fullBody = "full_body"
        case core
    }

    public enum Intensity: String, CaseIterable, Codable, Sendable, Hashable {
        case light
        case moderate
        case hard
        case veryHard = "very_hard"

        fileprivate var baseScore: Double {
            switch self {
            case .light: 25
            case .moderate: 45
            case .hard: 70
            case .veryHard: 88
            }
        }

        fileprivate var expectedRPE: Double {
            switch self {
            case .light: 3
            case .moderate: 5.5
            case .hard: 7.5
            case .veryHard: 9
            }
        }
    }

    public struct Estimate: Equatable, Sendable {
        public var score: Double
        public var muscles: [MuscularLoadEngine.MuscleOutput]
        public var source: String
        public var assumptions: [String]

        public init(score: Double, muscles: [MuscularLoadEngine.MuscleOutput],
                    source: String, assumptions: [String]) {
            self.score = score
            self.muscles = muscles
            self.source = source
            self.assumptions = assumptions
        }
    }

    public static func estimate(region: Region, intensity: Intensity,
                                rpe: Double?, durationMinutes: Double?,
                                coldStartReference: Double = 1_800) -> Estimate {
        let validRPE = rpe.flatMap { $0.isFinite && (1...10).contains($0) ? $0 : nil }
        let rpeAdjustment = validRPE.map {
            min(12, max(-12, ($0 - intensity.expectedRPE) * 4))
        } ?? 0
        let validDuration = durationMinutes.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let durationAdjustment = validDuration.map {
            min(9, max(-6, ($0 - 45) / 5))
        } ?? 0
        let score = min(100, max(0, intensity.baseScore + rpeAdjustment + durationAdjustment))
        let weights = contributions(region)
        let peak = weights.values.max() ?? 1
        let muscles = weights.map { muscle, contribution in
            let normalized = score * contribution / peak
            let raw = normalized > 0
                ? coldStartReference * pow(2, (normalized - 50) / 22)
                : 0
            return MuscularLoadEngine.MuscleOutput(
                muscleId: muscle,
                side: StrengthSide.both.rawValue,
                rawStimulus: raw,
                normalizedLoad: normalized,
                workingSets: 0
            )
        }.sorted {
            if $0.normalizedLoad == $1.normalizedLoad { return $0.muscleId < $1.muscleId }
            return $0.normalizedLoad > $1.normalizedLoad
        }

        var assumptions = [
            "Estimated from body region and intensity",
            "No exercise, set, side, or activation detail inferred",
        ]
        if validRPE == nil { assumptions.append("Session RPE unavailable") }
        if validDuration == nil { assumptions.append("Duration adjustment unavailable") }
        return Estimate(score: score, muscles: muscles, source: sourceVersion,
                        assumptions: assumptions)
    }

    public static func contributions(_ region: Region) -> [String: Double] {
        let upper: [String: Double] = [
            "chest": 0.18, "lats": 0.18, "upper_back": 0.14,
            "front_delts": 0.08, "side_delts": 0.08, "rear_delts": 0.08,
            "biceps": 0.08, "triceps": 0.08, "forearms": 0.10,
        ]
        let lower: [String: Double] = [
            "quadriceps": 0.28, "glutes": 0.26, "hamstrings": 0.22,
            "calves": 0.10, "adductors": 0.14,
        ]
        let core: [String: Double] = [
            "abdominals": 0.30, "obliques": 0.25,
            "erector_spinae": 0.25, "lower_back": 0.20,
        ]
        switch region {
        case .upperBody: return upper
        case .lowerBody: return lower
        case .core: return core
        case .fullBody:
            var result: [String: Double] = [:]
            for (muscle, weight) in lower { result[muscle] = weight * 0.45 }
            for (muscle, weight) in upper { result[muscle] = weight * 0.40 }
            for (muscle, weight) in core { result[muscle] = weight * 0.15 }
            return result
        }
    }
}
