#if os(iOS)
import SwiftUI

/// Stable presentation contract for the four root destinations. Destinations
/// intentionally map to existing views; this type owns no navigation state.
enum PerformanceRootDestination: Int, CaseIterable, Identifiable {
    case home
    case health
    case progress
    case more

    static let selectionStorageKey = "noop.performance.selectedRootTab"

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .health: "Health"
        case .progress: "Progress"
        case .more: "More"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .health: "heart.text.square"
        case .progress: "chart.bar.fill"
        case .more: "line.3.horizontal"
        }
    }

    static func sanitizedTag(_ value: Int) -> Int {
        Self(rawValue: value)?.rawValue ?? home.rawValue
    }
}
#endif
