import Foundation
import WhoopStore

enum StrengthDerivedRestore {
    static let requiredKey = "backup.strengthDerivedRebuildRequired"

    static func markRequired(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: requiredKey)
    }

    static func rebuildIfRequired(
        store: WhoopStore,
        defaults: UserDefaults = .standard
    ) async {
        guard defaults.bool(forKey: requiredKey) else { return }
        do {
            try await store.rebuildStrengthDerivedCaches()
            await CurrentMuscleResidualService.shared.invalidateAll()
            defaults.removeObject(forKey: requiredKey)
        } catch {
            // Keep the flag so the next launch retries. Session-level rows remain the source of truth.
        }
    }
}
