import Foundation
import GRDB

extension WhoopStore {
    public func saveSorenessCheckIn(_ value: SorenessCheckInRecord) async throws {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO coachSorenessCheckIn
                  (id, deviceId, recordedAt, overallSoreness, note, deletedAt)
                VALUES (?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                  deviceId = excluded.deviceId, recordedAt = excluded.recordedAt,
                  overallSoreness = excluded.overallSoreness, note = excluded.note,
                  deletedAt = NULL
                """, arguments: [
                    value.id, value.deviceId, value.recordedAt,
                    value.overallSoreness, value.note,
                ])
            try db.execute(sql: "DELETE FROM coachMuscleSoreness WHERE checkInId = ?",
                           arguments: [value.id])
            for (muscleId, score) in value.perMuscleSoreness {
                guard NOOPMuscle(rawValue: muscleId) != nil else { continue }
                try db.execute(sql: """
                    INSERT INTO coachMuscleSoreness (checkInId, muscleId, score)
                    VALUES (?, ?, ?)
                    """, arguments: [value.id, muscleId, min(10, max(0, score))])
            }
        }
    }

    public func latestSorenessCheckIn(deviceId: String) async throws -> SorenessCheckInRecord? {
        try syncRead { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT id, deviceId, recordedAt, overallSoreness, note
                FROM coachSorenessCheckIn
                WHERE deviceId = ? AND deletedAt IS NULL
                ORDER BY recordedAt DESC LIMIT 1
                """, arguments: [deviceId]) else { return nil }
            let id: String = row["id"]
            let muscleRows = try Row.fetchAll(db, sql: """
                SELECT muscleId, score FROM coachMuscleSoreness WHERE checkInId = ?
                """, arguments: [id])
            let perMuscle = Dictionary(uniqueKeysWithValues: muscleRows.map {
                (($0["muscleId"] as String), ($0["score"] as Int))
            })
            return SorenessCheckInRecord(
                id: id,
                deviceId: row["deviceId"],
                recordedAt: row["recordedAt"],
                overallSoreness: row["overallSoreness"],
                perMuscleSoreness: perMuscle,
                note: row["note"]
            )
        }
    }

    public func deleteSorenessCheckIn(id: String, at: Int = Int(Date().timeIntervalSince1970))
        async throws {
        try syncWrite { db in
            try db.execute(sql: """
                UPDATE coachSorenessCheckIn SET deletedAt = ? WHERE id = ?
                """, arguments: [at, id])
        }
    }

    public func savePainCheckIn(_ value: PainCheckInRecord) async throws {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO coachPainCheckIn
                  (id, deviceId, recordedAt, painPresent, note, deletedAt)
                VALUES (?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                  deviceId = excluded.deviceId, recordedAt = excluded.recordedAt,
                  painPresent = excluded.painPresent, note = excluded.note, deletedAt = NULL
                """, arguments: [
                    value.id, value.deviceId, value.recordedAt,
                    value.painPresent, value.note,
                ])
        }
    }

    public func latestPainCheckIn(deviceId: String) async throws -> PainCheckInRecord? {
        try syncRead { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT id, deviceId, recordedAt, painPresent, note
                FROM coachPainCheckIn
                WHERE deviceId = ? AND deletedAt IS NULL
                ORDER BY recordedAt DESC LIMIT 1
                """, arguments: [deviceId]) else { return nil }
            return PainCheckInRecord(
                id: row["id"],
                deviceId: row["deviceId"],
                recordedAt: row["recordedAt"],
                painPresent: row["painPresent"],
                note: row["note"]
            )
        }
    }

    public func deletePainCheckIn(id: String, at: Int = Int(Date().timeIntervalSince1970))
        async throws {
        try syncWrite { db in
            try db.execute(sql: """
                UPDATE coachPainCheckIn SET deletedAt = ? WHERE id = ?
                """, arguments: [at, id])
        }
    }

    public func upsertStrengthPlanLink(_ link: StrengthPlanLinkRecord) async throws {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO strengthPlanLink
                  (proposalId, sessionId, canonicalActivityId, templateId, createdAt, completedAt)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(proposalId) DO UPDATE SET
                  sessionId = excluded.sessionId,
                  canonicalActivityId = excluded.canonicalActivityId,
                  templateId = excluded.templateId,
                  completedAt = excluded.completedAt
                """, arguments: [
                    link.proposalId, link.sessionId, link.canonicalActivityId,
                    link.templateId, link.createdAt, link.completedAt,
                ])
        }
    }

    public func strengthPlanLink(proposalId: String) async throws -> StrengthPlanLinkRecord? {
        try syncRead { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT * FROM strengthPlanLink WHERE proposalId = ?
                """, arguments: [proposalId]) else { return nil }
            return StrengthPlanLinkRecord(
                proposalId: row["proposalId"],
                sessionId: row["sessionId"],
                canonicalActivityId: row["canonicalActivityId"],
                templateId: row["templateId"],
                createdAt: row["createdAt"],
                completedAt: row["completedAt"]
            )
        }
    }

    /// The newest explicitly started plan that can own this session. The bounded six-hour window
    /// prevents an abandoned plan from being attached to an unrelated manual workout days later.
    public func pendingStrengthPlanLink(forSessionStartedAt startedAt: Int)
        async throws -> StrengthPlanLinkRecord? {
        try syncRead { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT * FROM strengthPlanLink
                WHERE completedAt IS NULL
                  AND createdAt <= ?
                  AND createdAt >= ?
                ORDER BY createdAt DESC
                LIMIT 1
                """, arguments: [startedAt + 60, startedAt - 6 * 3_600]) else { return nil }
            return StrengthPlanLinkRecord(
                proposalId: row["proposalId"],
                sessionId: row["sessionId"],
                canonicalActivityId: row["canonicalActivityId"],
                templateId: row["templateId"],
                createdAt: row["createdAt"],
                completedAt: row["completedAt"]
            )
        }
    }
}
