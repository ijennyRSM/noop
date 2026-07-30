import Foundation

/// Presentation-only rendering for a stored plan proposal.
///
/// `PlanProposal.summary()` remains the stable English/context representation.
/// User-facing SwiftUI surfaces use this localized form so canonical activity
/// and intent identifiers never leak into a Thai interface.
extension PlanProposal {
    func localizedPresentationSummary() -> String {
        let sportName = WorkoutCatalog.localizedDisplayName(sport)
        let intentName = intent.label.localizedCatalogValue
        var parts = ["\(sportName) (\(intentName))"]

        if let time {
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            parts.append(formatter.string(from: time))
        }

        if let targetEffort {
            parts.append(
                "\(String(localized: "Effort")) \(Int(targetEffort.rounded()))"
            )
        }
        return parts.joined(separator: " · ")
    }
}
