import Foundation
import StrandAnalytics
import WhoopStore

extension AICoachEngine {
    enum StrengthToolBlock {
        case summary, recent, load, residual, soreness, recovery
    }

    func strengthToolBlock(_ kind: StrengthToolBlock, now: Date = Date()) async -> String {
        guard let store = await repo.storeHandle() else {
            return "Strength data is unavailable because the local database is not open."
        }
        let deviceId = repo.deviceId
        do {
            switch kind {
            case .summary:
                let sessions = try await store.strengthSessions(deviceId: deviceId, limit: 30)
                    .filter { $0.status == StrengthSessionStatus.completed.rawValue }
                guard !sessions.isEmpty else { return "No finalized strength sessions yet." }
                let durationMinutes = sessions.reduce(0.0) { total, session in
                    total + Double(max(0, (session.endedAt ?? session.startedAt) - session.startedAt)) / 60
                }
                let averageLoad = sessions.compactMap(\.muscularLoad).average
                let recentLoads = try await store.historicalMuscleLoads(
                    deviceId: deviceId,
                    from: Int(CanonicalDay.calendar().date(
                        byAdding: .day, value: -28, to: now)?.timeIntervalSince1970 ?? 0))
                let top = Dictionary(grouping: recentLoads, by: \.muscleId)
                    .map { ($0.key, $0.value.reduce(0) { $0 + $1.rawStimulus }) }
                    .sorted { $0.1 > $1.1 }.prefix(5).map(\.0)
                return """
                Strength summary
                Finalized sessions: \(sessions.count)
                Total duration: \(CoachDurationFormatter.format(minutes: durationMinutes))
                Average muscular load: \(averageLoad.map { String(format: "%.1f/100", $0) } ?? "unavailable")
                Most trained muscles: \(top.isEmpty ? "unavailable" : top.joined(separator: ", "))
                Data confidence: \(sessions.count >= 8 ? "medium" : "low")
                """

            case .recent:
                let sessions = try await store.strengthSessions(deviceId: deviceId, limit: 6)
                    .filter { $0.status == StrengthSessionStatus.completed.rawValue }
                guard !sessions.isEmpty else { return "No finalized strength sessions yet." }
                return (["Recent strength sessions"] + sessions.map { session in
                    let date = Date(timeIntervalSince1970: TimeInterval(session.startedAt))
                    let duration = Double(max(0, (session.endedAt ?? session.startedAt)
                                              - session.startedAt)) / 60
                    let exercises = session.exercises.prefix(6).map {
                        "\($0.snapshotName) (\($0.sets.filter { $0.completed }.count) sets)"
                    }.joined(separator: ", ")
                    return """
                    \(CanonicalDay.key(for: date)) — \(session.title)
                    Duration: \(CoachDurationFormatter.format(minutes: duration))
                    Exercises: \(exercises.isEmpty ? "not recorded" : exercises)
                    Session RPE: \(session.sessionRPE.map { String(format: "%.1f/10", $0) } ?? "unavailable")
                    Muscular load: \(session.muscularLoad.map { String(format: "%.1f/100", $0) } ?? "unavailable")
                    """
                }).joined(separator: "\n")

            case .load:
                let start = CanonicalDay.key(
                    for: CanonicalDay.calendar().date(byAdding: .day, value: -6, to: now) ?? now)
                let end = CanonicalDay.key(for: now)
                let rows = try await store.dailyMuscleLoads(deviceId: deviceId, from: start, to: end)
                guard !rows.isEmpty else { return "No muscular-load data in the last 7 calendar days." }
                let grouped = Dictionary(grouping: rows, by: \.muscleId)
                let lines = grouped.map { muscle, values in
                    let raw = values.reduce(0) { $0 + $1.rawStimulus }
                    let bounded = values.map(\.normalizedLoad).max() ?? 0
                    return (muscle, raw, bounded)
                }.sorted { $0.1 > $1.1 }.prefix(10).map {
                    "\($0.0): \(String(format: "%.1f/100", $0.2))"
                }
                return "7-day muscle load (\(start) through \(end)); raw-first aggregation:\n"
                    + lines.joined(separator: "\n")

            case .residual:
                let rows = await CurrentMuscleResidualService.shared.currentLoads(
                    store: store, deviceId: deviceId, now: now,
                    refreshToken: repo.refreshSeq,
                    recovery: .init(
                        sleepHours: repo.today?.totalSleepMin.map { $0 / 60 },
                        charge: repo.today?.recovery))
                guard !rows.isEmpty else { return "No residual muscular load is available yet." }
                return "Current residual muscular load (time-decayed at \(CanonicalDay.key(for: now))):\n"
                    + rows.prefix(10).map {
                        "\($0.muscleId): \(String(format: "%.1f/100", $0.residualLoad)); confidence \($0.confidence)"
                    }.joined(separator: "\n")

            case .soreness:
                guard let value = try await store.latestSorenessCheckIn(deviceId: deviceId) else {
                    return "Soreness check-in: unavailable (missing is not zero)."
                }
                let recorded = Date(timeIntervalSince1970: TimeInterval(value.recordedAt))
                let ageHours = max(0, now.timeIntervalSince(recorded) / 3_600)
                let freshness = ageHours < 24 ? "current" : (ageHours < 72 ? "recent" : "stale")
                let overall = value.overallSoreness.map { "\($0)/10" } ?? "unavailable"
                var lines = [
                    "Soreness check-in",
                    "Observed day: \(CanonicalDay.key(for: recorded))",
                    "Freshness: \(freshness)",
                    "Overall: \(overall)",
                ]
                if !value.perMuscleSoreness.isEmpty {
                    lines.append("Per muscle: " + value.perMuscleSoreness.sorted { $0.key < $1.key }
                        .map { "\($0.key) \($0.value)/10" }.joined(separator: ", "))
                }
                if toolConsent.enabled.contains(.painSensitive),
                   let pain = try await store.latestPainCheckIn(deviceId: deviceId) {
                    lines.append("Pain-sensitive summary: pain present = \(pain.painPresent ? "yes" : "no")")
                    if let note = pain.note, !note.isEmpty { lines.append("User pain note: \(note)") }
                }
                return lines.joined(separator: "\n")

            case .recovery:
                async let residual = strengthToolBlock(.residual, now: now)
                async let soreness = strengthToolBlock(.soreness, now: now)
                let (residualText, sorenessText) = await (residual, soreness)
                return residualText + "\n\n" + sorenessText
                    + "\nPain is never converted into muscular or residual load."
            }
        } catch {
            return "Strength summary is unavailable because the local derived data could not be read."
        }
    }

    func strengthProgressionTool(exerciseId: String) async -> String {
        let canonical = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return "A canonical exercise_id is required." }
        guard let store = await repo.storeHandle() else { return "Strength data is unavailable." }
        do {
            let history = try await store.exercisePerformanceHistory(
                deviceId: repo.deviceId, exerciseId: canonical, limit: 12)
            guard !history.isEmpty else { return "No finalized history for exercise_id \(canonical)." }
            return (["Exercise progression: \(canonical)"] + history.map { entry in
                let best = entry.sets.compactMap { set -> Double? in
                    guard set.completed, let weight = set.weightKg, let reps = set.reps else { return nil }
                    return MuscularLoadEngine.estimatedOneRepMax(weightKg: weight, reps: reps)
                }.max()
                return "\(CanonicalDay.key(for: Date(timeIntervalSince1970: TimeInterval(entry.startedAt))))"
                    + ": completed sets \(entry.sets.filter { $0.completed }.count), "
                    + "estimated 1RM \(best.map { String(format: "%.1f kg", $0) } ?? "unavailable")"
            }).joined(separator: "\n")
        } catch {
            return "Exercise progression is unavailable from the local database."
        }
    }
}

private extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
