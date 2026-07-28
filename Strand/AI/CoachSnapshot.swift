import Foundation
import StrandAnalytics
import WhoopStore

/// Structured local snapshot used by AI Coach. It contains summary values only and never raw
/// R-R, PPG, accelerometer, gyroscope, GPS, or sleep-stage epoch streams.
struct CoachSnapshot: Equatable {
    enum Trend: String { case rising, falling, stable, insufficient }
    enum Freshness: String { case current, recent, stale, unavailable }

    struct Metric: Equatable {
        var current: Double?
        var average7: Double?
        var baseline30: Double?
        var difference: Double?
        var percentDifference: Double?
        var trend: Trend
        var availableCount: Int
        var expectedCount: Int
        var source: String
        var timeRange: String
        var observedDay: String? = nil
        var freshness: Freshness = .unavailable

        var completeness: Double {
            expectedCount > 0 ? Double(availableCount) / Double(expectedCount) : 0
        }
    }

    struct Recovery: Equatable {
        var charge: Metric
        var hrv: Metric
        var restingHR: Metric
        var respiratoryRate: Metric
        var skinTemperatureDeviation: Metric
        var spo2: Metric
        var consecutiveMeaningfulDeviationDays: Int
    }

    struct Sleep: Equatable {
        var durationMinutes: Metric
        var restScore: Metric
        var sleepNeedMinutes: Double?
        var versusNeedMinutes: Double?
        var debtMinutes: Double?
        var efficiencyPercent: Double?
        var consistencyPercent: Double?
        var deepMinutes: Double?
        var remMinutes: Double?
        var lightMinutes: Double?
        var restorativeMinutes: Double?
        var disturbances: Int?
        var bedtime: Date?
        var wakeTime: Date?
        var naps: Int
        var debtTrend: Trend
    }

    struct Training: Equatable {
        struct RecentWorkout: Equatable {
            var activity: String
            var startedAt: Date
            var durationMinutes: Double?
            var cardiovascularEffort: Double?
            var zoneMinutes: [Double]?
        }

        var workoutCount7: Int
        var workoutCount28: Int
        var durationMinutes7: Double
        var durationMinutes28: Double
        var cardiovascularEffortTotal7: Double
        var cardiovascularEffortTotal28: Double
        var cardiovascularEffortAverage7: Double?
        var acuteLoad: Double?
        var chronicLoad: Double?
        var acuteChronicRatio: Double?
        var monotony: Double?
        var consecutiveHardDays: Int
        var hoursSinceHardWorkout: Double?
        var frequentActivities: [String]
        var readiness: String
        var readinessDrivers: [String]
        var completeness: Double
        var recentWorkouts: [RecentWorkout] = []
    }

    struct Strength: Equatable {
        struct Muscle: Equatable {
            var id: String
            var load: Double
            var residual: Double?
            var confidence: String
        }
        struct Progression: Equatable {
            var exerciseName: String
            var sessions: [String]
        }

        var latestSessionTitle: String?
        var latestSessionDate: Date?
        var durationMinutes: Double?
        var workingSets: Int
        var sessionRPE: Double?
        var cardiovascularEffort: Double?
        var muscularLoad: Double?
        var totalTrainingLoad: Double?
        var confidence: String?
        var muscles: [Muscle]
        var progression: [Progression]
    }

    var recovery: Recovery
    var sleep: Sleep
    var training: Training
    var strength: Strength?
    var coachProfile: LocalCoachProfile? = nil
    var sorenessCheckIn: CoachSorenessCheckIn? = nil
    var generatedAt: Date = Date()
}

@MainActor
enum CoachSnapshotBuilder {
    static func build(repository: Repository, question: String? = nil,
                      now: Date = Date()) async -> CoachSnapshot {
        let sorted = repository.days.sorted { $0.day < $1.day }
        let latest = sorted.last
        let readiness = ReadinessEngine.evaluate(
            days: sorted,
            today: Repository.localDayKey(now)
        )

        let charge = metric(sorted.compactMap { row in
            row.recovery.map { (row.day, $0) }
        }, now: now)
        let hrv = metric(sorted.compactMap { row in
            row.avgHrv.map { (row.day, $0) }
        }, now: now)
        let rhr = metric(sorted.compactMap { row in
            row.restingHr.map { (row.day, Double($0)) }
        }, now: now)
        let respiratory = metric(sorted.compactMap { row in
            row.respRateBpm.map { (row.day, $0) }
        }, now: now)
        let skin = metric(sorted.compactMap { row in
            row.skinTempDevC.map { (row.day, $0) }
        }, now: now)
        // Only calibrated percentages from `spo2Pct`; the raw red/IR columns are deliberately absent.
        let spo2 = metric(sorted.compactMap { row in
            row.spo2Pct.flatMap { (70...100).contains($0) ? (row.day, $0) : nil }
        }, now: now)
        let deviations = consecutiveDeviations(days: sorted)

        let duration = metric(sorted.compactMap { row in
            row.totalSleepMin.map { (row.day, $0) }
        }, now: now)
        let restSeries = await repository.exploreSeries(
            key: "sleep_performance", source: repository.deviceId, days: 60)
        let rest = metric(restSeries, now: now)
        let need = await lastValue("sleep_need_min", repository: repository)
        let debt = await lastValue("sleep_debt_min", repository: repository)
        let consistency = await lastValue("sleep_consistency", repository: repository)
        let debtSeries = await repository.exploreSeries(
            key: "sleep_debt_min", source: repository.deviceId, days: 14)
        let sleepSession = await repository.allSleepSessions(days: 14)
        let habitualMidsleep = await repository.habitualMidsleepSec()
        let groupedSleep = Dictionary(grouping: sleepSession) {
            Repository.localDayKey(
                Date(timeIntervalSince1970: TimeInterval($0.endTs)))
        }
        let sleepDayKeys = groupedSleep.keys.sorted()
        let latestSleepDay = sleepDayKeys.last
        var latestMainSleep: [CachedSleepSession] = []
        var napCount = 0
        let sevenDayStart = Calendar.current.date(
            byAdding: .day, value: -6,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now
        let sevenDayStartKey = Repository.localDayKey(sevenDayStart)
        for key in sleepDayKeys {
            let sessions = groupedSleep[key] ?? []
            let classification = SleepPeriodClassifier.classify(
                sessions.map { .init(start: $0.effectiveStartTs, end: $0.endTs) },
                offsetSec: TimeZone.current.secondsFromGMT(for: now),
                habitualMidsleepSec: habitualMidsleep
            )
            if key >= sevenDayStartKey {
                napCount += classification.napIndices.count
            }
            if key == latestSleepDay {
                latestMainSleep = classification.mainIndices.map { sessions[$0] }
            }
        }
        let latestDay = latest
        let sleep = CoachSnapshot.Sleep(
            durationMinutes: duration,
            restScore: rest,
            sleepNeedMinutes: need,
            versusNeedMinutes: zipOptional(latestDay?.totalSleepMin, need).map { $0.0 - $0.1 },
            debtMinutes: debt,
            efficiencyPercent: latestDay?.efficiency.map { $0 <= 1 ? $0 * 100 : $0 },
            consistencyPercent: consistency,
            deepMinutes: latestDay?.deepMin,
            remMinutes: latestDay?.remMin,
            lightMinutes: latestDay?.lightMin,
            restorativeMinutes: zipOptional(latestDay?.deepMin, latestDay?.remMin).map { $0.0 + $0.1 },
            disturbances: latestDay?.disturbances,
            bedtime: latestMainSleep.map(\.effectiveStartTs).min().map {
                Date(timeIntervalSince1970: TimeInterval($0))
            },
            wakeTime: latestMainSleep.map(\.endTs).max().map {
                Date(timeIntervalSince1970: TimeInterval($0))
            },
            naps: napCount,
            debtTrend: trend(debtSeries.map(\.value)))

        let workouts = await repository.workoutRows(days: 28)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let start7 = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let start28 = calendar.date(byAdding: .day, value: -27, to: todayStart) ?? todayStart
        let rows7 = workouts.filter {
            Date(timeIntervalSince1970: TimeInterval($0.startTs)) >= start7
        }
        let rows28 = workouts.filter {
            Date(timeIntervalSince1970: TimeInterval($0.startTs)) >= start28
        }
        let strains7 = rows7.compactMap {
            CardiovascularEffortValue.stored($0.strain)?.normalized100
        }
        let strains28 = rows28.compactMap {
            CardiovascularEffortValue.stored($0.strain)?.normalized100
        }
        let daily7 = sorted.filter { dayIsInWindow($0.day, start: start7, end: now) }
            .compactMap(\.strain)
        let daily28 = sorted.filter { dayIsInWindow($0.day, start: start28, end: now) }
            .compactMap(\.strain)
        let acute = daily7.count >= 4 ? mean(daily7) : nil
        let chronic = daily28.count >= 14 ? mean(daily28) : nil
        let acwr = zipOptional(acute, chronic).flatMap {
            $0.1 > 0 ? $0.0 / $0.1 : nil
        }
        let monotony: Double? = {
            guard daily7.count >= 4,
                  let average = mean(daily7),
                  let standardDeviation = sampleSD(daily7),
                  standardDeviation > 0 else { return nil }
            return average / standardDeviation
        }()
        let hardDays = consecutiveHardDays(sorted, now: now)
        let latestHard = workouts.filter {
            CardiovascularEffortValue.stored($0.strain)?.isHardWorkout == true
        }.map(\.endTs).max()
        let groupedActivities: [String: [WorkoutRow]] = Dictionary(
            grouping: rows28,
            by: { workout in workout.sport })
        let counts: [(sport: String, count: Int)] = groupedActivities.map {
            (sport: $0.key, count: $0.value.count)
        }.sorted {
            $0.count == $1.count ? $0.sport < $1.sport : $0.count > $1.count
        }
        let recentWorkouts = workouts.sorted { $0.startTs > $1.startTs }.prefix(6).map {
            let zoneSummary = WorkoutZones.summary(from: [$0])
            return CoachSnapshot.Training.RecentWorkout(
                activity: $0.sport,
                startedAt: Date(timeIntervalSince1970: TimeInterval($0.startTs)),
                durationMinutes: ($0.durationS
                    ?? Double(max(0, $0.endTs - $0.startTs))) / 60,
                cardiovascularEffort:
                    CardiovascularEffortValue.stored($0.strain)?.normalized100,
                zoneMinutes: zoneSummary?.minutes
            )
        }
        let training = CoachSnapshot.Training(
            workoutCount7: rows7.count,
            workoutCount28: rows28.count,
            durationMinutes7: rows7.compactMap(\.durationS).reduce(0, +) / 60,
            durationMinutes28: rows28.compactMap(\.durationS).reduce(0, +) / 60,
            cardiovascularEffortTotal7: strains7.reduce(0, +),
            cardiovascularEffortTotal28: strains28.reduce(0, +),
            cardiovascularEffortAverage7: mean(strains7),
            acuteLoad: acute,
            chronicLoad: chronic,
            acuteChronicRatio: acwr,
            monotony: monotony,
            consecutiveHardDays: hardDays,
            hoursSinceHardWorkout: latestHard.map {
                max(0, now.timeIntervalSince1970 - Double($0)) / 3_600
            },
            frequentActivities: counts.prefix(4).map { $0.sport },
            readiness: readiness.level.rawValue,
            readinessDrivers: readiness.signals.map {
                [$0.label, $0.evidence, $0.detail].compactMap { $0 }.joined(separator: ": ")
            },
            completeness: Double(Set(sorted.filter {
                dayIsInWindow($0.day, start: start28, end: now)
            }.map(\.day)).count) / 28,
            recentWorkouts: recentWorkouts)

        let strength = await buildStrength(repository: repository, question: question, now: now)
        return CoachSnapshot(
            recovery: .init(
                charge: charge, hrv: hrv, restingHR: rhr,
                respiratoryRate: respiratory, skinTemperatureDeviation: skin,
                spo2: spo2, consecutiveMeaningfulDeviationDays: deviations),
            sleep: sleep,
            training: training,
            strength: strength,
            coachProfile: LocalCoachPreferences.loadProfile(),
            sorenessCheckIn: LocalCoachPreferences.loadCheckIn(),
            generatedAt: now)
    }

    static func shouldIncludeDetailedStrength(question: String,
                                              exercises: [ExerciseDefinition] = []) -> Bool {
        let q = normalize(question)
        let tokens = [
            "strength", "weight", "set", "sets", "rep", "reps", "rpe", "rir",
            "progress", "progression", "personal record", "pr", "กล้าม", "เวท",
            "น้ำหนัก", "เซต", "ครั้ง", "rpe", "rir",
        ] + NOOPMuscle.allCases.flatMap { [$0.rawValue, normalize($0.englishName)] }
        if tokens.contains(where: { q.contains(normalize($0)) }) { return true }
        return exercises.contains {
            q.contains(normalize($0.canonicalName))
                || $0.aliases.contains(where: { q.contains(normalize($0)) })
        }
    }

    private static func buildStrength(repository: Repository, question: String?,
                                      now: Date) async -> CoachSnapshot.Strength? {
        guard let store = await repository.storeHandle() else { return nil }
        let sessions = (try? await store.strengthSessions(deviceId: repository.deviceId, limit: 30)) ?? []
        let complete = sessions.filter { $0.status == StrengthSessionStatus.completed.rawValue }
        guard let latest = complete.first else { return nil }
        let start = Date(timeIntervalSince1970: TimeInterval(latest.startedAt))
        let residual = await CurrentMuscleResidualService.shared.currentLoads(
            store: store,
            deviceId: repository.deviceId,
            now: now,
            refreshToken: repository.refreshSeq,
            recovery: .init(
                sleepHours: repository.today?.totalSleepMin.map { $0 / 60 },
                charge: repository.today?.recovery
            ),
            checkIn: LocalCoachPreferences.loadCheckIn()
        )
        let sessionLoads = (try? await store.strengthSessionMuscleLoads(
            sessionId: latest.id)) ?? []
        let residualByMuscle = Dictionary(
            residual.map { ($0.muscleId, $0.residualLoad) },
            uniquingKeysWith: max)
        let muscles = sessionMuscles(
            sessionLoads: sessionLoads,
            residualByMuscle: residualByMuscle
        )

        var definitions: [String: ExerciseDefinition] = [:]
        for session in complete.prefix(8) {
            for exercise in session.exercises where definitions[exercise.exerciseId] == nil {
                definitions[exercise.exerciseId] = try? await store.exerciseDefinition(id: exercise.exerciseId)
            }
        }
        let includeDetail = question.map {
            shouldIncludeDetailedStrength(question: $0,
                                          exercises: Array(definitions.values))
        } ?? false
        var progression: [CoachSnapshot.Strength.Progression] = []
        if includeDetail {
            let q = normalize(question ?? "")
            let relevant = definitions.values.filter { definition in
                q.contains(normalize(definition.canonicalName))
                    || definition.aliases.contains(where: { q.contains(normalize($0)) })
            }
            let ids = Set((relevant.isEmpty
                ? latest.exercises.prefix(3).map(\.exerciseId)
                : relevant.map(\.id)))
            for id in ids {
                let name = definitions[id]?.canonicalName
                    ?? complete.flatMap(\.exercises).first(where: { $0.exerciseId == id })?.snapshotName
                    ?? id
                let history = complete.compactMap { session -> String? in
                    guard let exercise = session.exercises.first(where: { $0.exerciseId == id }) else {
                        return nil
                    }
                    let sets = exercise.sets.filter {
                        $0.completed && $0.setType != StrengthSetType.warmup.rawValue
                    }
                    guard !sets.isEmpty else { return nil }
                    let formatted = sets.prefix(6).map { set in
                        let weight = set.weightKg.map { "\(format($0)) kg" } ?? "bodyweight"
                        let reps = set.reps.map(String.init) ?? "?"
                        return "\(weight) × \(reps)"
                    }.joined(separator: ", ")
                    return "\(dayString(session.startedAt)): \(formatted)"
                }
                progression.append(.init(exerciseName: name,
                                         sessions: Array(history.prefix(3))))
            }
        }
        return .init(
            latestSessionTitle: latest.title,
            latestSessionDate: start,
            durationMinutes: latest.endedAt.map { Double($0 - latest.startedAt) / 60 },
            workingSets: latest.exercises.flatMap(\.sets).filter {
                $0.completed && $0.setType != StrengthSetType.warmup.rawValue
            }.count,
            sessionRPE: latest.sessionRPE,
            cardiovascularEffort: latest.cardiovascularEffort,
            muscularLoad: latest.muscularLoad,
            totalTrainingLoad: latest.totalTrainingLoad,
            confidence: latest.confidence,
            muscles: muscles,
            progression: progression)
    }

    static func sessionMuscles(
        sessionLoads: [DailyMuscleLoadRecord],
        residualByMuscle: [String: Double],
        limit: Int = 8
    ) -> [CoachSnapshot.Strength.Muscle] {
        sessionLoads.sorted {
            $0.normalizedLoad > $1.normalizedLoad
        }.prefix(limit).map {
            CoachSnapshot.Strength.Muscle(
                id: $0.muscleId,
                load: $0.normalizedLoad,
                residual: residualByMuscle[$0.muscleId],
                confidence: $0.confidence
            )
        }
    }

    static func metric(_ values: [(day: String, value: Double)],
                       now: Date) -> CoachSnapshot.Metric {
        let valid = values.filter { $0.value.isFinite && date(fromDay: $0.day) != nil }
            .sorted { $0.day < $1.day }
        let latest = valid.last
        let today = Calendar.current.startOfDay(for: now)
        let start7 = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        let start30 = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
        let seven = valid.filter { dayIsInWindow($0.day, start: start7, end: now) }
        let baseline = valid.filter {
            guard let date = date(fromDay: $0.day) else { return false }
            return date >= start30 && date < today
        }
        let current = latest?.value
        let avg7 = mean(seven.map(\.value))
        let avg30 = mean(baseline.map(\.value))
        let difference = zipOptional(current, avg30).map { $0.0 - $0.1 }
        let percent = zipOptional(difference, avg30).flatMap { pair in
            abs(pair.1) > 0.0001 ? pair.0 / abs(pair.1) * 100 : nil
        }
        let freshness: CoachSnapshot.Freshness = {
            guard let latestDay = latest?.day,
                  let date = date(fromDay: latestDay) else { return .unavailable }
            let distance = Calendar.current.dateComponents(
                [.day], from: date, to: today).day ?? Int.max
            if distance <= 0 { return .current }
            if distance == 1 { return .recent }
            return .stale
        }()
        return .init(
            current: current, average7: avg7, baseline30: avg30,
            difference: difference, percentDifference: percent,
            trend: trend(seven.map(\.value)),
            availableCount: baseline.count, expectedCount: 30,
            source: "on-device merged wearable data",
            timeRange: "latest / 7 calendar days / prior 30 calendar days",
            observedDay: latest?.day,
            freshness: freshness)
    }

    private static func lastValue(_ key: String, repository: Repository) async -> Double? {
        await repository.exploreSeries(
            key: key, source: repository.deviceId, days: 60).last?.value
    }

    private static func consecutiveDeviations(days: [DailyMetric]) -> Int {
        let baseline = Array(days.dropLast().suffix(30))
        guard let hrvBase = mean(baseline.compactMap(\.avgHrv)),
              let rhrBase = mean(baseline.compactMap { $0.restingHr.map(Double.init) })
        else { return 0 }
        var count = 0
        for day in days.reversed() {
            let deviates = (day.avgHrv.map { $0 < hrvBase * 0.85 } ?? false)
                || (day.restingHr.map { Double($0) > rhrBase * 1.08 } ?? false)
            guard deviates else { break }
            count += 1
        }
        return count
    }

    private static func consecutiveHardDays(_ days: [DailyMetric], now: Date) -> Int {
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        var count = 0
        let today = Calendar.current.startOfDay(for: now)
        for offset in 0..<28 {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: today),
                  let day = byDay[Repository.localDayKey(date)],
                  CardiovascularEffortValue.stored(day.strain)?.isHardWorkout == true
            else { break }
            count += 1
        }
        return count
    }

    private static func trend(_ values: [Double]) -> CoachSnapshot.Trend {
        guard values.count >= 3 else { return .insufficient }
        let half = values.count / 2
        guard let first = mean(Array(values.prefix(half))),
              let second = mean(Array(values.suffix(values.count - half))) else {
            return .insufficient
        }
        let threshold = max(abs(first) * 0.03, 0.2)
        if second - first > threshold { return .rising }
        if first - second > threshold { return .falling }
        return .stable
    }

    private static func mean(_ values: [Double]) -> Double? {
        let valid = values.filter(\.isFinite)
        return valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
    }

    private static func sampleSD(_ values: [Double]) -> Double? {
        guard values.count >= 2, let average = mean(values) else { return nil }
        let sum = values.reduce(0) { $0 + pow($1 - average, 2) }
        return sqrt(sum / Double(values.count - 1))
    }

    private static func date(fromDay day: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day)
    }

    private static func dayIsInWindow(_ day: String, start: Date, end: Date) -> Bool {
        guard let date = date(fromDay: day) else { return false }
        return date >= Calendar.current.startOfDay(for: start)
            && date <= Calendar.current.startOfDay(for: end)
    }

    private static func zipOptional<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func dayString(_ timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

enum CoachSnapshotFormatter {
    static func format(_ snapshot: CoachSnapshot,
                       maxCharacters: Int = 6_000) -> String {
        var lines = ["USER HEALTH AND TRAINING SUMMARY (local summaries; missing values are not inferred):"]
        lines += ["", "RECOVERY"]
        lines.append(metric("Charge", snapshot.recovery.charge, unit: "/100"))
        lines.append(metric("HRV", snapshot.recovery.hrv, unit: " ms"))
        lines.append(metric("Resting HR", snapshot.recovery.restingHR, unit: " bpm"))
        lines.append(metric("Respiratory rate", snapshot.recovery.respiratoryRate, unit: "/min"))
        lines.append(metric("Skin-temperature deviation",
                            snapshot.recovery.skinTemperatureDeviation, unit: "°C"))
        lines.append(metric("SpO₂ (calibrated percentage only)", snapshot.recovery.spo2, unit: "%"))
        lines.append("  Consecutive meaningful-deviation days: "
                     + "\(snapshot.recovery.consecutiveMeaningfulDeviationDays)")

        let sleep = snapshot.sleep
        lines += ["", "SLEEP"]
        lines.append(metric("Sleep duration", sleep.durationMinutes, unit: " min"))
        lines.append(metric("Rest score (separate from duration)", sleep.restScore, unit: "/100"))
        lines.append("  Need: \(number(sleep.sleepNeedMinutes, suffix: " min")); "
                     + "versus need: \(signed(sleep.versusNeedMinutes, suffix: " min")); "
                     + "debt: \(number(sleep.debtMinutes, suffix: " min")) (\(sleep.debtTrend.rawValue))")
        lines.append("  Efficiency: \(number(sleep.efficiencyPercent, suffix: "%")); "
                     + "consistency: \(number(sleep.consistencyPercent, suffix: "%")); "
                     + "deep: \(number(sleep.deepMinutes, suffix: " min")); "
                     + "REM: \(number(sleep.remMinutes, suffix: " min")); "
                     + "light: \(number(sleep.lightMinutes, suffix: " min")); "
                     + "restorative: \(number(sleep.restorativeMinutes, suffix: " min"))")
        lines.append("  Disturbances: \(sleep.disturbances.map(String.init) ?? "missing"); "
                     + "bedtime: \(clock(sleep.bedtime)); wake: \(clock(sleep.wakeTime)); "
                     + "naps (7d estimate): \(sleep.naps)")

        let training = snapshot.training
        lines += ["", "TRAINING LOAD"]
        lines.append("  Workouts: \(training.workoutCount7) in 7d / \(training.workoutCount28) in 28d; "
                     + "duration: \(Int(training.durationMinutes7.rounded())) min / "
                     + "\(Int(training.durationMinutes28.rounded())) min")
        lines.append("  Cardiovascular Effort: total \(one(training.cardiovascularEffortTotal7)) in 7d, "
                     + "\(one(training.cardiovascularEffortTotal28)) in 28d; "
                     + "7d average \(number(training.cardiovascularEffortAverage7))")
        lines.append("  Acute/chronic: \(number(training.acuteLoad)) / "
                     + "\(number(training.chronicLoad)); ratio "
                     + "\(number(training.acuteChronicRatio)); monotony "
                     + "\(number(training.monotony)) (training heuristics, not medical claims)")
        lines.append("  Consecutive hard days: \(training.consecutiveHardDays); "
                     + "hours since latest hard workout: \(number(training.hoursSinceHardWorkout))")
        lines.append("  Activities: "
                     + (training.frequentActivities.isEmpty ? "missing"
                        : training.frequentActivities.joined(separator: ", ")))
        lines.append("  Readiness: \(training.readiness); drivers: "
                     + (training.readinessDrivers.isEmpty ? "missing"
                        : training.readinessDrivers.joined(separator: " | ")))
        lines.append("  Daily-data completeness: \(Int((training.completeness * 100).rounded()))%")
        if !training.recentWorkouts.isEmpty {
            lines += ["", "RECENT WORKOUTS (newest first; summary only)"]
            for workout in training.recentWorkouts {
                let zones = workout.zoneMinutes.map {
                    zip(1...5, $0).map { "Z\($0.0) \(one($0.1)) min" }
                        .joined(separator: ", ")
                } ?? "zones unavailable"
                lines.append(
                    "  \(dayClock(workout.startedAt)) \(workout.activity); "
                    + "duration \(number(workout.durationMinutes, suffix: " min")); "
                    + "Effort \(number(workout.cardiovascularEffort, suffix: "/100")); "
                    + zones
                )
            }
        }

        if let profile = snapshot.coachProfile,
           profile != LocalCoachProfile() {
            lines += ["", "LOCAL COACH PROFILE (user-entered)"]
            lines.append("  Goals: \(list(profile.primaryGoals)); activities: "
                         + list(profile.sportsAndActivities))
            lines.append("  Experience: \(missingIfEmpty(profile.experienceLevel)); "
                         + "preferred days: \(list(profile.preferredTrainingDays)); "
                         + "available time: \(profile.availableMinutes.map(String.init) ?? "missing") min")
            lines.append("  Equipment: \(list(profile.availableEquipment)); limitations: "
                         + missingIfEmpty(profile.trainingLimitations)
                         + "; coaching language: "
                         + missingIfEmpty(profile.preferredLanguage))
        }
        if let checkIn = snapshot.sorenessCheckIn {
            let ageHours = max(
                0, snapshot.generatedAt.timeIntervalSince(checkIn.recordedAt) / 3_600)
            let usable = ageHours < 72
            lines += ["", "OPTIONAL CHECK-IN (user-entered)"]
            lines.append("  Overall soreness: "
                         + (checkIn.overallSoreness.map { "\($0)/10" } ?? "unavailable")
                         + "; age \(one(ageHours)) h; residual influence "
                         + (usable ? "freshness-weighted" : "expired"))
            if !checkIn.perMuscleSoreness.isEmpty {
                lines.append("  Per-muscle soreness: "
                             + checkIn.perMuscleSoreness.sorted { $0.key < $1.key }
                                .map { "\($0.key) \($0.value)/10" }
                                .joined(separator: ", "))
            }
            if !checkIn.note.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty {
                lines.append("  User note: \(checkIn.note)")
            }
            if checkIn.painPresent == true {
                lines.append("  Pain/discomfort reported"
                             + (checkIn.painNote.isEmpty ? ""
                                : ": \(checkIn.painNote)")
                             + " (separate from load; do not diagnose)")
            }
        }

        if let strength = snapshot.strength {
            lines += ["", "STRENGTH TRAINING SUMMARY"]
            lines.append("  Last session: \(strength.latestSessionTitle ?? "missing"); "
                         + "duration \(number(strength.durationMinutes, suffix: " min")); "
                         + "working sets \(strength.workingSets); session RPE "
                         + "\(number(strength.sessionRPE, suffix: "/10"))")
            lines.append("  Cardiovascular Effort \(number(strength.cardiovascularEffort)); "
                         + "Estimated Muscular Load \(number(strength.muscularLoad, suffix: "/100")); "
                         + "Total Training Load \(number(strength.totalTrainingLoad, suffix: "/100")); "
                         + "confidence \(strength.confidence ?? "missing")")
            if !strength.muscles.isEmpty {
                lines.append("  Estimated muscle load (not direct tissue measurement):")
                for muscle in strength.muscles {
                    lines.append("    \(muscle.id): \(Int(muscle.load.rounded()))/100; residual "
                                 + "\(number(muscle.residual, suffix: "/100")); "
                                 + "confidence \(muscle.confidence)")
                }
            }
            for progression in strength.progression {
                lines.append("  \(progression.exerciseName) — recent logged sessions:")
                lines += progression.sessions.map { "    \($0)" }
            }
        }
        var output: [String] = []
        var count = 0
        for line in lines {
            let addition = line.count + (output.isEmpty ? 0 : 1)
            guard count + addition <= maxCharacters else { break }
            output.append(line)
            count += addition
        }
        return output.joined(separator: "\n")
    }

    private static func metric(_ title: String, _ value: CoachSnapshot.Metric,
                               unit: String) -> String {
        "  \(title): latest \(number(value.current, suffix: unit))"
            + " [\(value.observedDay ?? "no date"), \(value.freshness.rawValue)]; "
            + "7d avg \(number(value.average7, suffix: unit)); "
            + "30d baseline \(number(value.baseline30, suffix: unit)); "
            + "difference \(signed(value.difference, suffix: unit)) "
            + "(\(signed(value.percentDifference, suffix: "%"))); "
            + "trend \(value.trend.rawValue); completeness "
            + "\(value.availableCount)/\(value.expectedCount); source \(value.source)"
    }

    private static func dayClock(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }

    private static func list(_ values: [String]) -> String {
        values.isEmpty ? "missing" : values.joined(separator: ", ")
    }

    private static func missingIfEmpty(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "missing" : value
    }

    private static func number(_ value: Double?, suffix: String = "") -> String {
        guard let value, value.isFinite else { return "missing" }
        return one(value) + suffix
    }

    private static func signed(_ value: Double?, suffix: String = "") -> String {
        guard let value, value.isFinite else { return "missing" }
        return (value >= 0 ? "+" : "") + one(value) + suffix
    }

    private static func one(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func clock(_ date: Date?) -> String {
        guard let date else { return "missing" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
