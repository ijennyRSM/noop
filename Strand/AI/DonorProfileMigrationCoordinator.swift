import Foundation

/// One-time bridge from the donor's old profile payload into DX-owned concepts. It never creates a
/// second profile system: the legacy blob is decoded only to prepare a review. Soreness and pain are
/// deliberately excluded because they are time-sensitive check-ins, not permanent memory.
@MainActor
enum DonorProfileMigrationCoordinator {
    struct PendingReview: Codable, Equatable {
        var goals: [String]
        var ordinaryMemory: [String]
        var limitationsNeedingConfirmation: [String]
        var preferredLanguage: String?
        var preparedAt: Date
    }

    private static let legacyProfileKey = "ai.localCoachProfile.v1"
    private static let pendingKey = "ai.donorProfileMigration.pending.v1"
    private static let completedKey = "ai.donorProfileMigration.completed.v1"

    static func prepareIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completedKey),
              defaults.data(forKey: pendingKey) == nil,
              let data = defaults.data(forKey: legacyProfileKey),
              let legacy = try? JSONDecoder().decode(LocalCoachProfile.self, from: data)
        else { return }

        var ordinary: [String] = []
        if !legacy.sportsAndActivities.isEmpty {
            ordinary.append("Activities: " + legacy.sportsAndActivities.joined(separator: ", "))
        }
        if !legacy.experienceLevel.isEmpty {
            ordinary.append("Training experience: \(legacy.experienceLevel)")
        }
        if !legacy.availableEquipment.isEmpty {
            ordinary.append("Available equipment: " + legacy.availableEquipment.joined(separator: ", "))
        }
        if !legacy.preferredTrainingDays.isEmpty {
            ordinary.append("Preferred training days: "
                + legacy.preferredTrainingDays.joined(separator: ", "))
        }
        if let minutes = legacy.availableMinutes {
            ordinary.append("Typical available training time: \(minutes) minutes")
        }
        let limitations = legacy.trainingLimitations
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let review = PendingReview(
            goals: legacy.primaryGoals.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            ordinaryMemory: Array(Set(ordinary)).sorted(),
            limitationsNeedingConfirmation: limitations.isEmpty ? [] : [limitations],
            preferredLanguage: legacy.preferredLanguage.isEmpty ? nil : legacy.preferredLanguage,
            preparedAt: Date()
        )
        if let encoded = try? JSONEncoder().encode(review) {
            defaults.set(encoded, forKey: pendingKey)
        }
    }

    static func pending(defaults: UserDefaults = .standard) -> PendingReview? {
        guard let data = defaults.data(forKey: pendingKey) else { return nil }
        return try? JSONDecoder().decode(PendingReview.self, from: data)
    }

    /// Called only after the review sheet's explicit confirmation. Confirmed goal titles become DX
    /// custom goals; limitations still enter Memory as pending confirmation and are never auto-pinned.
    static func applyPending(defaults: UserDefaults = .standard) {
        guard let review = pending(defaults: defaults) else { return }
        for goal in review.goals {
            let title = goal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty,
                  !CoachGoalStore.shared.goals.contains(where: {
                      $0.title.caseInsensitiveCompare(title) == .orderedSame
                  })
            else { continue }
            let kind = goalKind(for: title)
            guard CoachGoalStore.shared.canAdd(kind: kind) == nil else { continue }
            CoachGoalStore.shared.commit(CoachGoal(kind: kind, title: title))
        }
        for fact in review.ordinaryMemory {
            CoachMemory.shared.add(fact, category: .preference, source: .legacy,
                                   referenceID: "donor-profile")
        }
        for limitation in review.limitationsNeedingConfirmation {
            CoachMemory.shared.add(limitation, category: .injury, importance: .normal,
                                   source: .legacy, referenceID: "donor-profile")
        }
        if let language = review.preferredLanguage {
            defaults.set(language, forKey: "ai.preferredLanguage")
        }
        defaults.removeObject(forKey: pendingKey)
        defaults.set(true, forKey: completedKey)
    }

    private static func goalKind(for title: String) -> CoachGoal.Kind {
        let value = title.lowercased()
        if value.contains("strength") || value.contains("muscle") { return .strength }
        if value.contains("run") || value.contains("marathon") { return .run }
        if value.contains("sleep") { return .sleep }
        if value.contains("recover") { return .recovery }
        if value.contains("stress") { return .stress }
        if value.contains("weight") { return .weight }
        if value.contains("regular") || value.contains("consisten") { return .consistency }
        return .custom
    }

    static func discardPending(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingKey)
        defaults.set(true, forKey: completedKey)
    }
}
