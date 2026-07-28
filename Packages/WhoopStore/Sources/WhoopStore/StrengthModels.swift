import Foundation

public enum NOOPMuscle: String, CaseIterable, Codable, Sendable {
    case chest
    case lats
    case upperBack = "upper_back"
    case lowerBack = "lower_back"
    case traps
    case frontDelts = "front_delts"
    case sideDelts = "side_delts"
    case rearDelts = "rear_delts"
    case biceps
    case triceps
    case forearms
    case abdominals
    case obliques
    case erectorSpinae = "erector_spinae"
    case hipFlexors = "hip_flexors"
    case glutes
    case quadriceps
    case hamstrings
    case adductors
    case abductors
    case calves
    case tibialis

    public var englishName: String {
        switch self {
        case .chest: "Chest"
        case .lats: "Lats"
        case .upperBack: "Upper Back"
        case .lowerBack: "Lower Back"
        case .traps: "Traps"
        case .frontDelts: "Front Delts"
        case .sideDelts: "Side Delts"
        case .rearDelts: "Rear Delts"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abdominals: "Abdominals"
        case .obliques: "Obliques"
        case .erectorSpinae: "Erector Spinae / Core Stabilizers"
        case .hipFlexors: "Hip Flexors"
        case .glutes: "Glutes"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Hamstrings"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .calves: "Calves"
        case .tibialis: "Tibialis"
        }
    }
}

public enum ExerciseMuscleRole: String, Codable, Sendable {
    case primary, secondary, stabilizer
}

public enum StrengthLaterality: String, Codable, Sendable {
    case bilateral, unilateral
}

public enum StrengthLoadType: String, Codable, Sendable {
    case external, bodyweight
}

public enum StrengthSetType: String, CaseIterable, Codable, Sendable {
    case warmup, working, drop, failure
}

public enum StrengthSide: String, CaseIterable, Codable, Sendable {
    case both, left, right
}

public enum StrengthConfidence: String, CaseIterable, Codable, Sendable {
    case low, medium, high
}

public enum StrengthSessionStatus: String, Codable, Sendable {
    case draft, completed
}

public struct ExerciseMuscleContribution: Codable, Equatable, Sendable {
    public var muscleId: String
    public var role: String
    public var weight: Double

    public init(muscleId: String, role: String, weight: Double) {
        self.muscleId = muscleId
        self.role = role
        self.weight = weight
    }
}

public struct ExerciseDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var canonicalName: String
    public var aliases: [String]
    public var equipment: [String]
    public var movementPattern: String
    public var laterality: String
    public var loadType: String
    public var muscles: [ExerciseMuscleContribution]
    public var effectiveBodyweightCoefficient: Double?
    public var source: String
    public var sourceURL: String
    public var license: String
    public var licenseURL: String
    public var libraryVersion: Int
    public var builtIn: Bool

    public init(id: String, canonicalName: String, aliases: [String] = [],
                equipment: [String], movementPattern: String, laterality: String,
                loadType: String, muscles: [ExerciseMuscleContribution],
                effectiveBodyweightCoefficient: Double? = nil,
                source: String, sourceURL: String, license: String,
                licenseURL: String, libraryVersion: Int, builtIn: Bool = true) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.equipment = equipment
        self.movementPattern = movementPattern
        self.laterality = laterality
        self.loadType = loadType
        self.muscles = muscles
        self.effectiveBodyweightCoefficient = effectiveBodyweightCoefficient
        self.source = source
        self.sourceURL = sourceURL
        self.license = license
        self.licenseURL = licenseURL
        self.libraryVersion = libraryVersion
        self.builtIn = builtIn
    }
}

public struct StrengthSetRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var setIndex: Int
    public var setType: String
    public var weightKg: Double?
    public var reps: Int?
    public var rpe: Double?
    public var rir: Double?
    public var side: String
    public var completed: Bool
    public var reachedFailure: Bool
    public var notes: String?

    public init(id: String = UUID().uuidString, setIndex: Int,
                setType: String = StrengthSetType.working.rawValue,
                weightKg: Double? = nil, reps: Int? = nil, rpe: Double? = nil,
                rir: Double? = nil, side: String = StrengthSide.both.rawValue,
                completed: Bool = false, reachedFailure: Bool = false, notes: String? = nil) {
        self.id = id
        self.setIndex = setIndex
        self.setType = setType
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.side = side
        self.completed = completed
        self.reachedFailure = reachedFailure
        self.notes = notes
    }
}

public struct StrengthSessionExerciseRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var exerciseId: String
    public var snapshotName: String
    public var orderIndex: Int
    public var notes: String?
    public var sets: [StrengthSetRecord]

    public init(id: String = UUID().uuidString, exerciseId: String, snapshotName: String,
                orderIndex: Int, notes: String? = nil, sets: [StrengthSetRecord] = []) {
        self.id = id
        self.exerciseId = exerciseId
        self.snapshotName = snapshotName
        self.orderIndex = orderIndex
        self.notes = notes
        self.sets = sets
    }
}

public struct StrengthSessionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var deviceId: String
    public var workoutStartTs: Int?
    public var startedAt: Int
    public var endedAt: Int?
    public var title: String
    public var status: String
    public var source: String
    public var sessionRPE: Double?
    public var notes: String?
    public var quickRegion: String?
    public var quickIntensity: String?
    public var confidence: String
    public var cardiovascularEffort: Double?
    public var muscularLoad: Double?
    public var totalTrainingLoad: Double?
    public var exercises: [StrengthSessionExerciseRecord]

    public init(id: String = UUID().uuidString, deviceId: String, workoutStartTs: Int? = nil,
                startedAt: Int, endedAt: Int? = nil, title: String = "Strength Training",
                status: String = StrengthSessionStatus.draft.rawValue, source: String = "manual",
                sessionRPE: Double? = nil, notes: String? = nil, quickRegion: String? = nil,
                quickIntensity: String? = nil,
                confidence: String = StrengthConfidence.low.rawValue,
                cardiovascularEffort: Double? = nil, muscularLoad: Double? = nil,
                totalTrainingLoad: Double? = nil,
                exercises: [StrengthSessionExerciseRecord] = []) {
        self.id = id
        self.deviceId = deviceId
        self.workoutStartTs = workoutStartTs
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.status = status
        self.source = source
        self.sessionRPE = sessionRPE
        self.notes = notes
        self.quickRegion = quickRegion
        self.quickIntensity = quickIntensity
        self.confidence = confidence
        self.cardiovascularEffort = cardiovascularEffort
        self.muscularLoad = muscularLoad
        self.totalTrainingLoad = totalTrainingLoad
        self.exercises = exercises
    }
}

public struct DailyMuscleLoadRecord: Codable, Equatable, Sendable {
    public var day: String
    public var muscleId: String
    public var side: String
    public var rawStimulus: Double
    public var normalizedLoad: Double
    public var workingSets: Int
    public var confidence: String

    public init(day: String, muscleId: String, side: String = StrengthSide.both.rawValue,
                rawStimulus: Double, normalizedLoad: Double, workingSets: Int,
                confidence: String) {
        self.day = day
        self.muscleId = muscleId
        self.side = side
        self.rawStimulus = rawStimulus
        self.normalizedLoad = normalizedLoad
        self.workingSets = workingSets
        self.confidence = confidence
    }
}

public struct MuscleResidualRecord: Codable, Equatable, Sendable {
    public var capturedAt: Int
    public var muscleId: String
    public var side: String
    public var residualLoad: Double
    public var confidence: String
    public var lastTrainedAt: Int?

    public init(capturedAt: Int, muscleId: String,
                side: String = StrengthSide.both.rawValue, residualLoad: Double,
                confidence: String, lastTrainedAt: Int?) {
        self.capturedAt = capturedAt
        self.muscleId = muscleId
        self.side = side
        self.residualLoad = residualLoad
        self.confidence = confidence
        self.lastTrainedAt = lastTrainedAt
    }
}

public struct MuscleTrainingLoadRecord: Codable, Equatable, Sendable {
    public var trainedAt: Int
    public var muscleId: String
    public var side: String
    public var rawStimulus: Double
    public var normalizedLoad: Double
    public var confidence: String

    public init(trainedAt: Int, muscleId: String, side: String,
                rawStimulus: Double, normalizedLoad: Double, confidence: String) {
        self.trainedAt = trainedAt
        self.muscleId = muscleId
        self.side = side
        self.rawStimulus = rawStimulus
        self.normalizedLoad = normalizedLoad
        self.confidence = confidence
    }
}

public struct DetectedWorkoutRelabel: Codable, Equatable, Sendable {
    public var sourceDeviceId: String
    public var targetDeviceId: String
    public var workout: WorkoutRow
    public var targetSport: String

    public init(sourceDeviceId: String, targetDeviceId: String,
                workout: WorkoutRow, targetSport: String) {
        self.sourceDeviceId = sourceDeviceId
        self.targetDeviceId = targetDeviceId
        self.workout = workout
        self.targetSport = targetSport
    }
}

/// Complete strength write unit. Session detail, per-session muscle loads,
/// rebuilt daily rows, optional residual cache, and a detected-workout relabel
/// are committed or rolled back together.
public struct StrengthDerivedCommit: Codable, Equatable, Sendable {
    public var session: StrengthSessionRecord
    public var day: String
    public var muscleLoads: [DailyMuscleLoadRecord]
    public var residualSnapshot: [MuscleResidualRecord]
    public var residualCapturedAt: Int?
    public var detectedWorkoutRelabel: DetectedWorkoutRelabel?

    public init(session: StrengthSessionRecord,
                day: String,
                muscleLoads: [DailyMuscleLoadRecord],
                residualSnapshot: [MuscleResidualRecord] = [],
                residualCapturedAt: Int? = nil,
                detectedWorkoutRelabel: DetectedWorkoutRelabel? = nil) {
        self.session = session
        self.day = day
        self.muscleLoads = muscleLoads
        self.residualSnapshot = residualSnapshot
        self.residualCapturedAt = residualCapturedAt
        self.detectedWorkoutRelabel = detectedWorkoutRelabel
    }
}

public struct ExercisePerformanceRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { sessionId }
    public var sessionId: String
    public var startedAt: Int
    public var exerciseName: String
    public var sets: [StrengthSetRecord]

    public init(sessionId: String, startedAt: Int, exerciseName: String,
                sets: [StrengthSetRecord]) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.exerciseName = exerciseName
        self.sets = sets
    }
}

public struct WorkoutTemplateRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var notes: String?
    public var exercises: [StrengthSessionExerciseRecord]

    public init(id: String = UUID().uuidString, name: String, notes: String? = nil,
                exercises: [StrengthSessionExerciseRecord] = []) {
        self.id = id
        self.name = name
        self.notes = notes
        self.exercises = exercises
    }
}
