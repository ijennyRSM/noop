import Foundation
import GRDB

private struct BundledExerciseLibrary: Decodable {
    let libraryVersion: Int
    let exerciseCount: Int
    let exercises: [ExerciseDefinition]
}

enum StrengthCommitFailurePoint {
    case afterSession
    case afterMuscleLoads
}

extension WhoopStore {
    private static func normalizedExerciseSearch(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        String(data: try JSONEncoder().encode(value), encoding: .utf8) ?? "[]"
    }

    private static func decodeJSON<T: Decodable>(_ type: T.Type, _ value: String?) -> T? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Seeds or upgrades the bundled public-domain exercise facts. The transaction is idempotent:
    /// each stable ID is updated in place and aliases/muscles are replaced only for that ID.
    @discardableResult
    public func ensureExerciseLibrarySeeded() async throws -> Int {
        guard let url = Bundle.module.url(forResource: "exercise-library-v1", withExtension: "json") else {
            throw NSError(domain: "WhoopStore.ExerciseLibrary", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bundled exercise library is missing"])
        }
        let document = try JSONDecoder().decode(
            BundledExerciseLibrary.self, from: Data(contentsOf: url))
        guard document.exerciseCount == document.exercises.count,
              document.exerciseCount >= 300 else {
            throw NSError(domain: "WhoopStore.ExerciseLibrary", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Bundled exercise library is incomplete"])
        }
        let now = Int(Date().timeIntervalSince1970)
        return try syncWrite { db in
            var changed = 0
            for exercise in document.exercises {
                try Self.validateExercise(exercise)
                try db.execute(sql: """
                    INSERT INTO exerciseDefinition
                      (id, canonicalName, equipmentJSON, movementPattern, laterality, loadType,
                       effectiveBodyweightCoefficient, source, sourceURL, license, licenseURL,
                       libraryVersion, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                      canonicalName = excluded.canonicalName,
                      equipmentJSON = excluded.equipmentJSON,
                      movementPattern = excluded.movementPattern,
                      laterality = excluded.laterality,
                      loadType = excluded.loadType,
                      effectiveBodyweightCoefficient = excluded.effectiveBodyweightCoefficient,
                      source = excluded.source, sourceURL = excluded.sourceURL,
                      license = excluded.license, licenseURL = excluded.licenseURL,
                      libraryVersion = excluded.libraryVersion, updatedAt = excluded.updatedAt
                    """, arguments: [
                        exercise.id, exercise.canonicalName, try Self.encodeJSON(exercise.equipment),
                        exercise.movementPattern, exercise.laterality, exercise.loadType,
                        exercise.effectiveBodyweightCoefficient, exercise.source, exercise.sourceURL,
                        exercise.license, exercise.licenseURL, document.libraryVersion, now,
                    ])
                changed += db.changesCount
                try db.execute(sql: "DELETE FROM exerciseAlias WHERE exerciseId = ?",
                               arguments: [exercise.id])
                let aliases = [exercise.canonicalName] + exercise.aliases
                for alias in aliases {
                    let normalized = Self.normalizedExerciseSearch(alias)
                    guard !normalized.isEmpty else { continue }
                    try db.execute(sql: """
                        INSERT OR IGNORE INTO exerciseAlias (exerciseId, alias, normalizedAlias)
                        VALUES (?, ?, ?)
                        """, arguments: [exercise.id, alias, normalized])
                }
                try db.execute(sql: "DELETE FROM exerciseMuscle WHERE exerciseId = ?",
                               arguments: [exercise.id])
                for muscle in exercise.muscles {
                    try db.execute(sql: """
                        INSERT INTO exerciseMuscle (exerciseId, muscleId, role, contribution)
                        VALUES (?, ?, ?, ?)
                        """, arguments: [exercise.id, muscle.muscleId, muscle.role, muscle.weight])
                }
            }
            return changed
        }
    }

    private static func validateExercise(_ exercise: ExerciseDefinition) throws {
        let knownMuscles = Set(NOOPMuscle.allCases.map(\.rawValue))
        let total = exercise.muscles.reduce(0) { $0 + $1.weight }
        guard !exercise.id.isEmpty, !exercise.canonicalName.isEmpty,
              !exercise.equipment.isEmpty, !exercise.muscles.isEmpty,
              exercise.muscles.allSatisfy({ knownMuscles.contains($0.muscleId)
                  && $0.weight > 0 && $0.weight <= 1 }),
              total > 0.99, total < 1.01,
              !exercise.source.isEmpty, !exercise.license.isEmpty else {
            throw NSError(domain: "WhoopStore.ExerciseLibrary", code: 3,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Invalid exercise definition: \(exercise.id)"])
        }
    }

    public func exerciseLibraryCount() async throws -> Int {
        try syncRead { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM exerciseDefinition") ?? 0 }
    }

    /// Indexed alias/name search with optional muscle and equipment filters. Custom exercises are
    /// merged locally after the built-in query and never leave the device.
    public func searchExercises(query: String = "", muscleId: String? = nil,
                                equipment: String? = nil, limit: Int = 80) async throws
        -> [ExerciseDefinition] {
        let normalized = Self.normalizedExerciseSearch(query)
        return try syncRead { db in
            var predicates = ["1 = 1"]
            var arguments: StatementArguments = []
            if !normalized.isEmpty {
                predicates.append("""
                    EXISTS (SELECT 1 FROM exerciseAlias a
                            WHERE a.exerciseId = e.id AND a.normalizedAlias LIKE ?)
                    """)
                arguments += ["%\(normalized)%"]
            }
            if let muscleId, !muscleId.isEmpty {
                predicates.append("""
                    EXISTS (SELECT 1 FROM exerciseMuscle m
                            WHERE m.exerciseId = e.id AND m.muscleId = ?)
                    """)
                arguments += [muscleId]
            }
            if let equipment, !equipment.isEmpty {
                predicates.append("e.equipmentJSON LIKE ?")
                arguments += ["%\"\(equipment)\"%"]
            }
            arguments += [max(1, limit)]
            let rows = try Row.fetchAll(db, sql: """
                SELECT e.* FROM exerciseDefinition e
                WHERE \(predicates.joined(separator: " AND "))
                ORDER BY e.canonicalName COLLATE NOCASE
                LIMIT ?
                """, arguments: arguments)
            var result = try rows.map { try Self.exerciseDefinition(from: $0, db: db) }
            let customRows = try Row.fetchAll(db, sql: """
                SELECT * FROM customExercise WHERE deletedAt IS NULL
                ORDER BY canonicalName COLLATE NOCASE
                """)
            for row in customRows {
                guard result.count < limit,
                      let custom = Self.customExercise(from: row),
                      (normalized.isEmpty
                       || Self.normalizedExerciseSearch(
                            ([custom.canonicalName] + custom.aliases).joined(separator: " "))
                            .contains(normalized)),
                      (muscleId == nil || custom.muscles.contains { $0.muscleId == muscleId }),
                      (equipment.map { custom.equipment.contains($0) } ?? true) else { continue }
                result.append(custom)
            }
            return result.sorted { $0.canonicalName.localizedCaseInsensitiveCompare(
                $1.canonicalName) == .orderedAscending }
        }
    }

    public func exerciseDefinition(id: String) async throws -> ExerciseDefinition? {
        try syncRead { db in
            if let row = try Row.fetchOne(db, sql: "SELECT * FROM exerciseDefinition WHERE id = ?",
                                          arguments: [id]) {
                return try Self.exerciseDefinition(from: row, db: db)
            }
            guard let row = try Row.fetchOne(db, sql: """
                SELECT * FROM customExercise WHERE id = ? AND deletedAt IS NULL
                """, arguments: [id]) else { return nil }
            return Self.customExercise(from: row)
        }
    }

    private static func exerciseDefinition(from row: Row, db: Database) throws -> ExerciseDefinition {
        let id: String = row["id"]
        let canonicalName: String = row["canonicalName"]
        let aliases = try String.fetchAll(db, sql: """
            SELECT alias FROM exerciseAlias
            WHERE exerciseId = ? AND normalizedAlias != ?
            ORDER BY alias COLLATE NOCASE
            """, arguments: [id, normalizedExerciseSearch(canonicalName)])
        let muscleRows = try Row.fetchAll(db, sql: """
            SELECT muscleId, role, contribution FROM exerciseMuscle
            WHERE exerciseId = ? ORDER BY contribution DESC, muscleId
            """, arguments: [id])
        return ExerciseDefinition(
            id: id, canonicalName: canonicalName, aliases: aliases,
            equipment: decodeJSON([String].self, row["equipmentJSON"]) ?? ["other"],
            movementPattern: row["movementPattern"], laterality: row["laterality"],
            loadType: row["loadType"],
            muscles: muscleRows.map {
                ExerciseMuscleContribution(muscleId: $0["muscleId"], role: $0["role"],
                                           weight: $0["contribution"])
            },
            effectiveBodyweightCoefficient: row["effectiveBodyweightCoefficient"],
            source: row["source"], sourceURL: row["sourceURL"], license: row["license"],
            licenseURL: row["licenseURL"], libraryVersion: row["libraryVersion"], builtIn: true)
    }

    private static func customExercise(from row: Row) -> ExerciseDefinition? {
        guard let aliases = decodeJSON([String].self, row["aliasesJSON"]),
              let equipment = decodeJSON([String].self, row["equipmentJSON"]),
              let muscles = decodeJSON([ExerciseMuscleContribution].self, row["musclesJSON"])
        else { return nil }
        return ExerciseDefinition(
            id: row["id"], canonicalName: row["canonicalName"], aliases: aliases,
            equipment: equipment, movementPattern: row["movementPattern"],
            laterality: row["laterality"], loadType: row["loadType"], muscles: muscles,
            effectiveBodyweightCoefficient: row["effectiveBodyweightCoefficient"],
            source: "NOOP user", sourceURL: "", license: "User-created",
            licenseURL: "", libraryVersion: 0, builtIn: false)
    }

    public func saveCustomExercise(_ exercise: ExerciseDefinition) async throws {
        try Self.validateExercise(exercise)
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO customExercise
                  (id, canonicalName, aliasesJSON, equipmentJSON, movementPattern, laterality,
                   loadType, musclesJSON, effectiveBodyweightCoefficient, createdAt, updatedAt, deletedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                  canonicalName = excluded.canonicalName, aliasesJSON = excluded.aliasesJSON,
                  equipmentJSON = excluded.equipmentJSON,
                  movementPattern = excluded.movementPattern, laterality = excluded.laterality,
                  loadType = excluded.loadType, musclesJSON = excluded.musclesJSON,
                  effectiveBodyweightCoefficient = excluded.effectiveBodyweightCoefficient,
                  updatedAt = excluded.updatedAt, deletedAt = NULL
                """, arguments: [
                    exercise.id, exercise.canonicalName, try Self.encodeJSON(exercise.aliases),
                    try Self.encodeJSON(exercise.equipment), exercise.movementPattern,
                    exercise.laterality, exercise.loadType, try Self.encodeJSON(exercise.muscles),
                    exercise.effectiveBodyweightCoefficient, now, now,
                ])
        }
    }

    public func softDeleteCustomExercise(id: String) async throws {
        try syncWrite { db in
            let now = Int(Date().timeIntervalSince1970)
            try db.execute(sql: """
                UPDATE customExercise SET deletedAt = ?, updatedAt = ? WHERE id = ?
                """, arguments: [now, now, id])
        }
    }

    /// Whole-session transactional autosave. Replacing child rows makes reorder/delete/edit
    /// deterministic and prevents partially persisted sets after an interruption.
    public func saveStrengthSession(_ session: StrengthSessionRecord) async throws {
        try Self.validateSession(session)
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            try Self.writeStrengthSession(session, db: db, now: now)
        }
    }

    private static func writeStrengthSession(_ session: StrengthSessionRecord,
                                             db: Database,
                                             now: Int) throws {
        try db.execute(sql: """
            INSERT INTO strengthSession
              (id, deviceId, workoutStartTs, startedAt, endedAt, title, status, source,
               sessionRPE, notes, quickRegion, quickIntensity, confidence,
               cardiovascularEffort, muscularLoad, totalTrainingLoad, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              deviceId = excluded.deviceId, workoutStartTs = excluded.workoutStartTs,
              startedAt = excluded.startedAt, endedAt = excluded.endedAt,
              title = excluded.title, status = excluded.status, source = excluded.source,
              sessionRPE = excluded.sessionRPE, notes = excluded.notes,
              quickRegion = excluded.quickRegion, quickIntensity = excluded.quickIntensity,
              confidence = excluded.confidence,
              cardiovascularEffort = excluded.cardiovascularEffort,
              muscularLoad = excluded.muscularLoad,
              totalTrainingLoad = excluded.totalTrainingLoad, updatedAt = excluded.updatedAt
            """, arguments: [
                session.id, session.deviceId, session.workoutStartTs, session.startedAt,
                session.endedAt, session.title, session.status, session.source,
                session.sessionRPE, session.notes, session.quickRegion, session.quickIntensity,
                session.confidence, session.cardiovascularEffort, session.muscularLoad,
                session.totalTrainingLoad, now, now,
            ])
        try db.execute(sql: "DELETE FROM strengthSessionExercise WHERE sessionId = ?",
                       arguments: [session.id])
        for exercise in session.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            try db.execute(sql: """
                INSERT INTO strengthSessionExercise
                  (id, sessionId, exerciseId, snapshotName, orderIndex, notes, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    exercise.id, session.id, exercise.exerciseId, exercise.snapshotName,
                    exercise.orderIndex, exercise.notes, now, now,
                ])
            for set in exercise.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                try db.execute(sql: """
                    INSERT INTO strengthSet
                      (id, sessionExerciseId, setIndex, setType, weightKg, reps, rpe, rir,
                       side, completed, reachedFailure, notes, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        set.id, exercise.id, set.setIndex, set.setType, set.weightKg, set.reps,
                        set.rpe, set.rir, set.side, set.completed, set.reachedFailure,
                        set.notes, now, now,
                    ])
            }
        }
    }

    private static func validateSession(_ session: StrengthSessionRecord) throws {
        guard session.startedAt > 0,
              session.endedAt.map({ $0 >= session.startedAt }) ?? true,
              session.sessionRPE.map({ (0...10).contains($0) }) ?? true else {
            throw NSError(domain: "WhoopStore.Strength", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid strength session"])
        }
        for exercise in session.exercises {
            let indexes = exercise.sets.map(\.setIndex)
            guard Set(indexes).count == indexes.count,
                  exercise.sets.allSatisfy({
                      ($0.weightKg.map { $0 >= 0 && $0.isFinite } ?? true)
                      && ($0.reps.map { $0 >= 0 && $0 <= 1000 } ?? true)
                      && ($0.rpe.map { (0...10).contains($0) } ?? true)
                      && ($0.rir.map { (0...20).contains($0) } ?? true)
                  }) else {
                throw NSError(domain: "WhoopStore.Strength", code: 11,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Invalid or duplicate strength set"])
            }
        }
    }

    public func commitStrengthDerived(_ commit: StrengthDerivedCommit) async throws {
        try await commitStrengthDerived(commit, failAt: nil)
    }

    /// Internal failure seam used only by package tests to prove the transaction
    /// rolls back session and derived rows together.
    func commitStrengthDerived(_ commit: StrengthDerivedCommit,
                               failAt: StrengthCommitFailurePoint?) async throws {
        try Self.validateSession(commit.session)
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            var affectedDays = Set(try String.fetchAll(db, sql: """
                SELECT DISTINCT day FROM strengthSessionMuscleLoad WHERE sessionId = ?
                """, arguments: [commit.session.id]))
            affectedDays.insert(commit.day)

            try Self.writeStrengthSession(commit.session, db: db, now: now)
            if failAt == .afterSession {
                throw NSError(domain: "WhoopStore.Strength.TransactionTest", code: 1)
            }

            try db.execute(sql: "DELETE FROM strengthSessionMuscleLoad WHERE sessionId = ?",
                           arguments: [commit.session.id])
            for row in commit.muscleLoads {
                try db.execute(sql: """
                    INSERT INTO strengthSessionMuscleLoad
                      (sessionId, deviceId, day, trainedAt, muscleId, side, rawStimulus,
                       normalizedLoad, workingSets, confidence)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        commit.session.id, commit.session.deviceId, commit.day,
                        commit.session.startedAt, row.muscleId, row.side,
                        row.rawStimulus, row.normalizedLoad, row.workingSets,
                        row.confidence,
                    ])
            }
            if failAt == .afterMuscleLoads {
                throw NSError(domain: "WhoopStore.Strength.TransactionTest", code: 2)
            }
            for day in affectedDays {
                try Self.rebuildDailyMuscleLoads(
                    db: db, deviceId: commit.session.deviceId, day: day, now: now)
            }

            if let capturedAt = commit.residualCapturedAt {
                try Self.writeResidualSnapshot(
                    commit.residualSnapshot,
                    db: db,
                    deviceId: commit.session.deviceId,
                    capturedAt: capturedAt
                )
            }
            if let relabel = commit.detectedWorkoutRelabel {
                try Self.relabelDetectedWorkout(relabel, db: db)
            }
        }
    }

    private static func rebuildDailyMuscleLoads(db: Database,
                                                deviceId: String,
                                                day: String,
                                                now: Int) throws {
        try db.execute(sql: """
            DELETE FROM dailyMuscleLoad WHERE deviceId = ? AND day = ?
            """, arguments: [deviceId, day])
        try db.execute(sql: """
            INSERT INTO dailyMuscleLoad
              (deviceId, day, muscleId, side, rawStimulus, normalizedLoad,
               workingSets, confidence, updatedAt)
            SELECT deviceId, day, muscleId, side, SUM(rawStimulus),
                   MAX(normalizedLoad), SUM(workingSets),
                   CASE
                     WHEN SUM(CASE WHEN confidence = 'low' THEN 1 ELSE 0 END) > 0 THEN 'low'
                     WHEN SUM(CASE WHEN confidence = 'medium' THEN 1 ELSE 0 END) > 0 THEN 'medium'
                     ELSE 'high'
                   END,
                   ?
            FROM strengthSessionMuscleLoad
            WHERE deviceId = ? AND day = ?
            GROUP BY deviceId, day, muscleId, side
            """, arguments: [now, deviceId, day])
    }

    private static func writeResidualSnapshot(_ rows: [MuscleResidualRecord],
                                              db: Database,
                                              deviceId: String,
                                              capturedAt: Int) throws {
        // This table is a fallback cache, not an immutable physiological history.
        // Keep one complete snapshot per device so stale captures cannot accumulate.
        try db.execute(sql: """
            DELETE FROM muscleResidualSnapshot WHERE deviceId = ?
            """, arguments: [deviceId])
        for row in rows {
            try db.execute(sql: """
                INSERT INTO muscleResidualSnapshot
                  (deviceId, capturedAt, muscleId, side, residualLoad, confidence, lastTrainedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    deviceId, capturedAt, row.muscleId, row.side,
                    row.residualLoad, row.confidence, row.lastTrainedAt,
                ])
        }
    }

    private static func relabelDetectedWorkout(_ relabel: DetectedWorkoutRelabel,
                                               db: Database) throws {
        let sport = relabel.targetSport.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sport.isEmpty else {
            throw NSError(domain: "WhoopStore.Strength", code: 12,
                          userInfo: [NSLocalizedDescriptionKey:
                            "A canonical strength activity is required"])
        }
        let row = relabel.workout
        try db.execute(sql: """
            INSERT INTO workout
              (deviceId, startTs, endTs, sport, source, durationS, energyKcal,
               avgHr, maxHr, strain, distanceM, zonesJSON, notes)
            VALUES (?, ?, ?, ?, 'manual', ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(deviceId, startTs, sport) DO UPDATE SET
              endTs = excluded.endTs, source = excluded.source,
              durationS = excluded.durationS, energyKcal = excluded.energyKcal,
              avgHr = excluded.avgHr, maxHr = excluded.maxHr,
              strain = excluded.strain, distanceM = excluded.distanceM,
              zonesJSON = excluded.zonesJSON, notes = excluded.notes
            """, arguments: [
                relabel.targetDeviceId, row.startTs, row.endTs, sport,
                row.durationS, row.energyKcal, row.avgHr, row.maxHr,
                row.strain, row.distanceM, row.zonesJSON, row.notes,
            ])
        let rewroteSameNaturalKey =
            relabel.sourceDeviceId == relabel.targetDeviceId
            && row.sport.caseInsensitiveCompare(sport) == .orderedSame
        if !rewroteSameNaturalKey {
            try db.execute(sql: """
                DELETE FROM workout
                WHERE deviceId = ? AND startTs = ? AND sport = ?
                """, arguments: [
                    relabel.sourceDeviceId, row.startTs, row.sport,
                ])
        }
    }

    public func strengthSession(id: String) async throws -> StrengthSessionRecord? {
        try syncRead { db in try Self.readStrengthSession(db: db, id: id) }
    }

    public func activeStrengthSession(deviceId: String) async throws -> StrengthSessionRecord? {
        try syncRead { db in
            guard let id = try String.fetchOne(db, sql: """
                SELECT id FROM strengthSession
                WHERE deviceId = ? AND status = 'draft'
                ORDER BY updatedAt DESC LIMIT 1
                """, arguments: [deviceId]) else { return nil }
            return try Self.readStrengthSession(db: db, id: id)
        }
    }

    public func strengthSession(deviceId: String, workoutStartTs: Int) async throws
        -> StrengthSessionRecord? {
        try syncRead { db in
            guard let id = try String.fetchOne(db, sql: """
                SELECT id FROM strengthSession
                WHERE deviceId = ? AND workoutStartTs = ?
                ORDER BY updatedAt DESC LIMIT 1
                """, arguments: [deviceId, workoutStartTs]) else { return nil }
            return try Self.readStrengthSession(db: db, id: id)
        }
    }

    public func strengthSessions(deviceId: String, limit: Int = 50) async throws
        -> [StrengthSessionRecord] {
        try syncRead { db in
            let ids = try String.fetchAll(db, sql: """
                SELECT id FROM strengthSession WHERE deviceId = ?
                ORDER BY startedAt DESC LIMIT ?
                """, arguments: [deviceId, max(1, limit)])
            return try ids.compactMap { try Self.readStrengthSession(db: db, id: $0) }
        }
    }

    public func exercisePerformanceHistory(deviceId: String, exerciseId: String,
                                           limit: Int = 30) async throws
        -> [ExercisePerformanceRecord] {
        try syncRead { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.id AS sessionId, s.startedAt, e.snapshotName
                FROM strengthSession s
                JOIN strengthSessionExercise e ON e.sessionId = s.id
                WHERE s.deviceId = ? AND s.status = 'completed' AND e.exerciseId = ?
                ORDER BY s.startedAt DESC
                LIMIT ?
                """, arguments: [deviceId, exerciseId, max(1, limit)])
            return try rows.compactMap { row in
                let sessionId: String = row["sessionId"]
                guard let session = try Self.readStrengthSession(db: db, id: sessionId),
                      let exercise = session.exercises.first(where: {
                          $0.exerciseId == exerciseId
                      }) else { return nil }
                return ExercisePerformanceRecord(
                    sessionId: sessionId, startedAt: row["startedAt"],
                    exerciseName: row["snapshotName"], sets: exercise.sets)
            }
        }
    }

    private static func readStrengthSession(db: Database, id: String) throws -> StrengthSessionRecord? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM strengthSession WHERE id = ?",
                                         arguments: [id]) else { return nil }
        let exerciseRows = try Row.fetchAll(db, sql: """
            SELECT * FROM strengthSessionExercise WHERE sessionId = ? ORDER BY orderIndex
            """, arguments: [id])
        let exercises = try exerciseRows.map { exerciseRow -> StrengthSessionExerciseRecord in
            let exerciseId: String = exerciseRow["id"]
            let setRows = try Row.fetchAll(db, sql: """
                SELECT * FROM strengthSet WHERE sessionExerciseId = ? ORDER BY setIndex
                """, arguments: [exerciseId])
            let sets = setRows.map { setRow in
                StrengthSetRecord(
                    id: setRow["id"], setIndex: setRow["setIndex"],
                    setType: setRow["setType"], weightKg: setRow["weightKg"],
                    reps: setRow["reps"], rpe: setRow["rpe"], rir: setRow["rir"],
                    side: setRow["side"], completed: setRow["completed"],
                    reachedFailure: setRow["reachedFailure"], notes: setRow["notes"])
            }
            return StrengthSessionExerciseRecord(
                id: exerciseId, exerciseId: exerciseRow["exerciseId"],
                snapshotName: exerciseRow["snapshotName"], orderIndex: exerciseRow["orderIndex"],
                notes: exerciseRow["notes"], sets: sets)
        }
        return StrengthSessionRecord(
            id: row["id"], deviceId: row["deviceId"], workoutStartTs: row["workoutStartTs"],
            startedAt: row["startedAt"], endedAt: row["endedAt"], title: row["title"],
            status: row["status"], source: row["source"], sessionRPE: row["sessionRPE"],
            notes: row["notes"], quickRegion: row["quickRegion"],
            quickIntensity: row["quickIntensity"], confidence: row["confidence"],
            cardiovascularEffort: row["cardiovascularEffort"],
            muscularLoad: row["muscularLoad"], totalTrainingLoad: row["totalTrainingLoad"],
            exercises: exercises)
    }

    public func upsertDailyMuscleLoads(_ rows: [DailyMuscleLoadRecord],
                                       deviceId: String) async throws {
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            for row in rows {
                try db.execute(sql: """
                    INSERT INTO dailyMuscleLoad
                      (deviceId, day, muscleId, side, rawStimulus, normalizedLoad,
                       workingSets, confidence, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(deviceId, day, muscleId, side) DO UPDATE SET
                      rawStimulus = excluded.rawStimulus,
                      normalizedLoad = excluded.normalizedLoad,
                      workingSets = excluded.workingSets,
                      confidence = excluded.confidence, updatedAt = excluded.updatedAt
                    """, arguments: [
                        deviceId, row.day, row.muscleId, row.side, row.rawStimulus,
                        row.normalizedLoad, row.workingSets, row.confidence, now,
                    ])
            }
        }
    }

    /// Replace one session's derived contributions, then rebuild only its affected day. This keeps
    /// edits idempotent and lets two sessions on the same day accumulate without double-counting.
    public func replaceSessionMuscleLoads(
        sessionId: String, deviceId: String, day: String, trainedAt: Int,
        rows: [DailyMuscleLoadRecord]
    ) async throws {
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            try db.execute(sql: "DELETE FROM strengthSessionMuscleLoad WHERE sessionId = ?",
                           arguments: [sessionId])
            for row in rows {
                try db.execute(sql: """
                    INSERT INTO strengthSessionMuscleLoad
                      (sessionId, deviceId, day, trainedAt, muscleId, side, rawStimulus,
                       normalizedLoad, workingSets, confidence)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        sessionId, deviceId, day, trainedAt, row.muscleId, row.side,
                        row.rawStimulus, row.normalizedLoad, row.workingSets, row.confidence,
                    ])
            }
            try db.execute(sql: """
                DELETE FROM dailyMuscleLoad WHERE deviceId = ? AND day = ?
                """, arguments: [deviceId, day])
            try db.execute(sql: """
                INSERT INTO dailyMuscleLoad
                  (deviceId, day, muscleId, side, rawStimulus, normalizedLoad,
                   workingSets, confidence, updatedAt)
                SELECT deviceId, day, muscleId, side, SUM(rawStimulus),
                       MAX(normalizedLoad), SUM(workingSets),
                       CASE
                         WHEN SUM(CASE WHEN confidence = 'low' THEN 1 ELSE 0 END) > 0 THEN 'low'
                         WHEN SUM(CASE WHEN confidence = 'medium' THEN 1 ELSE 0 END) > 0 THEN 'medium'
                         ELSE 'high'
                       END,
                       ?
                FROM strengthSessionMuscleLoad
                WHERE deviceId = ? AND day = ?
                GROUP BY deviceId, day, muscleId, side
                """, arguments: [now, deviceId, day])
        }
    }

    public func historicalMuscleLoads(deviceId: String, from trainedAt: Int) async throws
        -> [MuscleTrainingLoadRecord] {
        try syncRead { db in
            try Row.fetchAll(db, sql: """
                SELECT trainedAt, muscleId, side, rawStimulus, normalizedLoad, confidence
                FROM strengthSessionMuscleLoad
                WHERE deviceId = ? AND trainedAt >= ?
                ORDER BY trainedAt
                """, arguments: [deviceId, trainedAt]).map {
                MuscleTrainingLoadRecord(
                    trainedAt: $0["trainedAt"], muscleId: $0["muscleId"],
                    side: $0["side"], rawStimulus: $0["rawStimulus"],
                    normalizedLoad: $0["normalizedLoad"],
                    confidence: $0["confidence"])
            }
        }
    }

    public func dailyMuscleLoads(deviceId: String, from: String, to: String) async throws
        -> [DailyMuscleLoadRecord] {
        try syncRead { db in
            try Row.fetchAll(db, sql: """
                SELECT day, muscleId, side, rawStimulus, normalizedLoad, workingSets, confidence
                FROM dailyMuscleLoad
                WHERE deviceId = ? AND day >= ? AND day <= ?
                ORDER BY day, muscleId, side
                """, arguments: [deviceId, from, to]).map {
                DailyMuscleLoadRecord(day: $0["day"], muscleId: $0["muscleId"],
                                      side: $0["side"], rawStimulus: $0["rawStimulus"],
                                      normalizedLoad: $0["normalizedLoad"],
                                      workingSets: $0["workingSets"], confidence: $0["confidence"])
            }
        }
    }

    /// Rebuild the disposable day aggregate from session-level source rows after a backup restore.
    /// Residual snapshots are intentionally dropped; the runtime service recomputes them at the current
    /// time rather than reviving a value captured on the exporting device.
    public func rebuildStrengthDerivedCaches() async throws {
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            try db.execute(sql: "DELETE FROM dailyMuscleLoad")
            try db.execute(sql: """
                INSERT INTO dailyMuscleLoad
                  (deviceId, day, muscleId, side, rawStimulus, normalizedLoad,
                   workingSets, confidence, updatedAt)
                SELECT deviceId, day, muscleId, side, SUM(rawStimulus),
                       MAX(normalizedLoad), SUM(workingSets),
                       CASE
                         WHEN SUM(CASE WHEN confidence = 'low' THEN 1 ELSE 0 END) > 0 THEN 'low'
                         WHEN SUM(CASE WHEN confidence = 'medium' THEN 1 ELSE 0 END) > 0 THEN 'medium'
                         ELSE 'high'
                       END,
                       ?
                FROM strengthSessionMuscleLoad
                GROUP BY deviceId, day, muscleId, side
                """, arguments: [now])
            try db.execute(sql: "DELETE FROM muscleResidualSnapshot")
        }
    }

    public func strengthSessionMuscleLoads(sessionId: String) async throws
        -> [DailyMuscleLoadRecord] {
        try syncRead { db in
            try Row.fetchAll(db, sql: """
                SELECT day, muscleId, side, rawStimulus, normalizedLoad, workingSets, confidence
                FROM strengthSessionMuscleLoad
                WHERE sessionId = ?
                ORDER BY normalizedLoad DESC, muscleId, side
                """, arguments: [sessionId]).map {
                DailyMuscleLoadRecord(
                    day: $0["day"], muscleId: $0["muscleId"], side: $0["side"],
                    rawStimulus: $0["rawStimulus"],
                    normalizedLoad: $0["normalizedLoad"],
                    workingSets: $0["workingSets"], confidence: $0["confidence"])
            }
        }
    }

    public func replaceResidualSnapshot(_ rows: [MuscleResidualRecord],
                                        deviceId: String, capturedAt: Int) async throws {
        try syncWrite { db in
            // Snapshot rows are a replaceable cache. Session-level muscle loads
            // remain the source of truth for current decay.
            try db.execute(sql: """
                DELETE FROM muscleResidualSnapshot WHERE deviceId = ?
                """, arguments: [deviceId])
            for row in rows {
                try db.execute(sql: """
                    INSERT INTO muscleResidualSnapshot
                      (deviceId, capturedAt, muscleId, side, residualLoad, confidence, lastTrainedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        deviceId, capturedAt, row.muscleId, row.side, row.residualLoad,
                        row.confidence, row.lastTrainedAt,
                    ])
            }
        }
    }

    public func latestResidualLoads(deviceId: String) async throws -> [MuscleResidualRecord] {
        try syncRead { db in
            guard let capturedAt = try Int.fetchOne(db, sql: """
                SELECT MAX(capturedAt) FROM muscleResidualSnapshot WHERE deviceId = ?
                """, arguments: [deviceId]) else { return [] }
            return try Row.fetchAll(db, sql: """
                SELECT capturedAt, muscleId, side, residualLoad, confidence, lastTrainedAt
                FROM muscleResidualSnapshot WHERE deviceId = ? AND capturedAt = ?
                ORDER BY residualLoad DESC
                """, arguments: [deviceId, capturedAt]).map {
                MuscleResidualRecord(capturedAt: $0["capturedAt"], muscleId: $0["muscleId"],
                                     side: $0["side"], residualLoad: $0["residualLoad"],
                                     confidence: $0["confidence"], lastTrainedAt: $0["lastTrainedAt"])
            }
        }
    }

    public func setExerciseFavorite(_ exerciseId: String, favorite: Bool) async throws {
        try syncWrite { db in
            if favorite {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO exerciseFavorite (exerciseId, createdAt) VALUES (?, ?)
                    """, arguments: [exerciseId, Int(Date().timeIntervalSince1970)])
            } else {
                try db.execute(sql: "DELETE FROM exerciseFavorite WHERE exerciseId = ?",
                               arguments: [exerciseId])
            }
        }
    }

    public func favoriteExerciseIds() async throws -> Set<String> {
        try syncRead { db in
            Set(try String.fetchAll(db, sql: "SELECT exerciseId FROM exerciseFavorite"))
        }
    }

    public func noteExerciseUsed(_ exerciseId: String, at timestamp: Int) async throws {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO exerciseRecent (exerciseId, lastUsedAt, useCount) VALUES (?, ?, 1)
                ON CONFLICT(exerciseId) DO UPDATE SET
                  lastUsedAt = excluded.lastUsedAt, useCount = useCount + 1
                """, arguments: [exerciseId, timestamp])
        }
    }

    public func recentExerciseIds(limit: Int = 12) async throws -> [String] {
        try syncRead { db in
            try String.fetchAll(db, sql: """
                SELECT exerciseId FROM exerciseRecent ORDER BY lastUsedAt DESC LIMIT ?
                """, arguments: [max(1, limit)])
        }
    }

    public func saveWorkoutTemplate(_ template: WorkoutTemplateRecord) async throws {
        let trimmed = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "WhoopStore.Strength", code: 20,
                          userInfo: [NSLocalizedDescriptionKey: "Template name is required"])
        }
        let now = Int(Date().timeIntervalSince1970)
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO workoutTemplate (id, name, notes, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  name = excluded.name, notes = excluded.notes, updatedAt = excluded.updatedAt
                """, arguments: [template.id, trimmed, template.notes, now, now])
            try db.execute(sql: "DELETE FROM workoutTemplateExercise WHERE templateId = ?",
                           arguments: [template.id])
            for item in template.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let exerciseRowId = UUID().uuidString
                try db.execute(sql: """
                    INSERT INTO workoutTemplateExercise
                      (id, templateId, exerciseId, snapshotName, orderIndex, notes)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        exerciseRowId, template.id, item.exerciseId, item.snapshotName,
                        item.orderIndex, item.notes,
                    ])
                for set in item.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                    try db.execute(sql: """
                        INSERT INTO workoutTemplateSet
                          (id, templateExerciseId, setIndex, setType,
                           targetWeightKg, targetReps, targetRPE, targetRIR)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """, arguments: [
                            UUID().uuidString, exerciseRowId, set.setIndex, set.setType,
                            set.weightKg, set.reps, set.rpe, set.rir,
                        ])
                }
            }
        }
    }

    public func workoutTemplates() async throws -> [WorkoutTemplateRecord] {
        try syncRead { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM workoutTemplate ORDER BY updatedAt DESC, name COLLATE NOCASE
                """)
            return try rows.map { row in
                let templateId: String = row["id"]
                let exerciseRows = try Row.fetchAll(db, sql: """
                    SELECT * FROM workoutTemplateExercise
                    WHERE templateId = ? ORDER BY orderIndex
                    """, arguments: [templateId])
                let exercises = try exerciseRows.map { exercise -> StrengthSessionExerciseRecord in
                    let templateExerciseId: String = exercise["id"]
                    let setRows = try Row.fetchAll(db, sql: """
                        SELECT * FROM workoutTemplateSet
                        WHERE templateExerciseId = ? ORDER BY setIndex
                        """, arguments: [templateExerciseId])
                    return StrengthSessionExerciseRecord(
                        exerciseId: exercise["exerciseId"],
                        snapshotName: exercise["snapshotName"],
                        orderIndex: exercise["orderIndex"],
                        notes: exercise["notes"],
                        sets: setRows.map {
                            StrengthSetRecord(
                                setIndex: $0["setIndex"], setType: $0["setType"],
                                weightKg: $0["targetWeightKg"], reps: $0["targetReps"],
                                rpe: $0["targetRPE"], rir: $0["targetRIR"])
                        })
                }
                return WorkoutTemplateRecord(id: templateId, name: row["name"],
                                             notes: row["notes"], exercises: exercises)
            }
        }
    }

    public func deleteWorkoutTemplate(id: String) async throws {
        try syncWrite { db in
            try db.execute(sql: "DELETE FROM workoutTemplate WHERE id = ?", arguments: [id])
        }
    }

    public func deleteStrengthSession(id: String) async throws {
        try syncWrite { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT deviceId, day
                FROM strengthSessionMuscleLoad WHERE sessionId = ?
                """, arguments: [id])
            try db.execute(sql: "DELETE FROM strengthSession WHERE id = ?", arguments: [id])
            let now = Int(Date().timeIntervalSince1970)
            for row in rows {
                let deviceId: String = row["deviceId"]
                let day: String = row["day"]
                try Self.rebuildDailyMuscleLoads(
                    db: db, deviceId: deviceId, day: day, now: now)
            }
        }
    }
}
