import Foundation

struct LocalCoachProfile: Codable, Equatable, Sendable {
    var primaryGoals: [String] = []
    var sportsAndActivities: [String] = []
    var experienceLevel: String = ""
    var preferredTrainingDays: [String] = []
    var availableMinutes: Int?
    var availableEquipment: [String] = []
    var trainingLimitations: String = ""
    var preferredLanguage: String = ""
}

struct CoachSorenessCheckIn: Codable, Equatable, Sendable {
    var overallSoreness: Int?
    var perMuscleSoreness: [String: Int] = [:]
    var recordedAt: Date
    var note: String = ""
    var painPresent: Bool?
    var painNote: String = ""

    init(overallSoreness: Int? = nil,
         perMuscleSoreness: [String: Int] = [:],
         recordedAt: Date = Date(),
         note: String = "",
         painPresent: Bool? = nil,
         painNote: String = "") {
        self.overallSoreness = overallSoreness.map { min(10, max(0, $0)) }
        self.perMuscleSoreness = perMuscleSoreness.mapValues { min(10, max(0, $0)) }
        self.recordedAt = recordedAt
        self.note = note
        self.painPresent = painPresent
        self.painNote = painNote
    }
}

enum LocalCoachPreferences {
    static let profileKey = "ai.localCoachProfile.v1"
    static let sorenessKey = "ai.sorenessCheckIn.v1"

    static func loadProfile(defaults: UserDefaults = .standard) -> LocalCoachProfile {
        guard let data = defaults.data(forKey: profileKey),
              let value = try? JSONDecoder().decode(LocalCoachProfile.self, from: data)
        else { return .init() }
        return value
    }

    static func saveProfile(_ profile: LocalCoachProfile,
                            defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    static func loadCheckIn(defaults: UserDefaults = .standard) -> CoachSorenessCheckIn? {
        guard let data = defaults.data(forKey: sorenessKey) else { return nil }
        return try? JSONDecoder().decode(CoachSorenessCheckIn.self, from: data)
    }

    static func saveCheckIn(_ checkIn: CoachSorenessCheckIn?,
                            defaults: UserDefaults = .standard) {
        guard let checkIn else {
            defaults.removeObject(forKey: sorenessKey)
            return
        }
        guard let data = try? JSONEncoder().encode(checkIn) else { return }
        defaults.set(data, forKey: sorenessKey)
    }

    /// Soreness is a modest estimate modifier: full influence for 24 hours,
    /// linearly tapering to no influence at 72 hours. Missing soreness remains
    /// unavailable and pain is intentionally ignored here.
    static func sorenessMultiplier(checkIn: CoachSorenessCheckIn?,
                                   muscleId: String,
                                   now: Date) -> Double {
        guard let checkIn else { return 1 }
        let ageHours = now.timeIntervalSince(checkIn.recordedAt) / 3_600
        guard ageHours >= 0, ageHours < 72 else { return 1 }
        let freshness = ageHours <= 24 ? 1 : (72 - ageHours) / 48
        guard let soreness = checkIn.perMuscleSoreness[muscleId]
                ?? checkIn.overallSoreness
        else { return 1 }
        return 1 + 0.15 * (Double(min(10, max(0, soreness))) / 10) * freshness
    }
}
