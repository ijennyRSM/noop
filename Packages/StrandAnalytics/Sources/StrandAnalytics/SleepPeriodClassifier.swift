import Foundation

/// Shared main-sleep/nap classification used by analytics, Sleep UI, and AI
/// Coach. It delegates the winning-night and split-night bridge rules to the
/// existing `SleepStageTotals` source of truth.
public enum SleepPeriodClassifier {
    public struct Period: Equatable, Sendable {
        public var start: Int
        public var end: Int

        public init(start: Int, end: Int) {
            self.start = start
            self.end = end
        }
    }

    public struct Result: Equatable, Sendable {
        public var winningIndex: Int?
        public var mainIndices: [Int]
        public var napIndices: [Int]

        public init(winningIndex: Int?, mainIndices: [Int], napIndices: [Int]) {
            self.winningIndex = winningIndex
            self.mainIndices = mainIndices
            self.napIndices = napIndices
        }
    }

    public static func classify(_ periods: [Period],
                                offsetSec: Int,
                                habitualMidsleepSec: Int? = nil) -> Result {
        guard !periods.isEmpty else {
            return .init(winningIndex: nil, mainIndices: [], napIndices: [])
        }
        let blocks = periods.map {
            SleepStageTotals.NightBlock(start: $0.start, end: $0.end)
        }
        let main = SleepStageTotals.mainNightGroupIndices(
            blocks,
            offsetSec: offsetSec,
            habitualMidsleepSec: habitualMidsleepSec
        ) ?? []
        let winner = SleepStageTotals.mainNightIndex(
            blocks,
            offsetSec: offsetSec,
            habitualMidsleepSec: habitualMidsleepSec
        )
        let mainSet = Set(main)
        return .init(
            winningIndex: winner,
            mainIndices: main.sorted { periods[$0].start < periods[$1].start },
            napIndices: periods.indices.filter { !mainSet.contains($0) }
        )
    }
}
