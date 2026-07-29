import Foundation

/// Stable machine-readable activity identity. Display strings may be localized;
/// persisted canonical workout names remain unchanged for backup/CSV parity.
enum ActivityID {
    static let strengthTraining = "strength_training"

    static func slug(forCanonicalName name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private static let strengthIDs: Set<String> = [
        "strength_training",
        "strength",
        "weight_training",
        "weightlifting",
        "functional_strength_training",
        "traditional_strength_training",
        "powerlifting",
        "bodybuilding",
    ]

    static func isStrength(activityID: String?,
                           canonicalSport: String?) -> Bool {
        if let activityID, strengthIDs.contains(slug(forCanonicalName: activityID)) {
            return true
        }
        guard let canonicalSport else { return false }
        return strengthIDs.contains(slug(forCanonicalName: canonicalSport))
    }
}
