import XCTest
@testable import Strand

final class UnifiedBackupV2Tests: XCTestCase {
    func testCoachSnapshotWhitelistsStateAndExcludesSecretsAndVectors() throws {
        let suite = "UnifiedBackupV2Tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(Data("facts".utf8), forKey: "ai.memory.facts")
        defaults.set(Data("goals".utf8), forKey: "ai.goals")
        defaults.set(true, forKey: "ai.dataConsent")
        defaults.set("th", forKey: "ai.preferredLanguage")
        defaults.set("sk-secret", forKey: "ai.apiKey")
        defaults.set(Data("vectors".utf8), forKey: "semantic.vectors")

        let state = UnifiedBackupV2.currentCoachState(defaults: defaults)
        XCTAssertNotNil(state.data["ai.memory.facts"])
        XCTAssertEqual(state.booleans["ai.dataConsent"], true)
        XCTAssertEqual(state.strings["ai.preferredLanguage"], "th")
        XCTAssertNil(state.strings["ai.apiKey"])
        XCTAssertNil(state.data["semantic.vectors"])
        XCTAssertNil(try JSONEncoder().encode(state).range(of: Data("sk-secret".utf8)))
    }

    func testManifestChecksumValidationAcceptsExactBytesAndRejectsTampering() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("unified-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = Data("database".utf8)
        let coach = Data(#"{"schema":1,"data":{},"booleans":{},"strings":{},"documents":{}}"#.utf8)
        try db.write(to: directory.appendingPathComponent("noop-backup.sqlite"))
        try coach.write(to: directory.appendingPathComponent(UnifiedBackupV2.coachStateEntry))
        let manifest = UnifiedBackupV2.Manifest(
            schema: 2, app: "NOOP AI Full Beta", appVersion: "test", source: "ios",
            createdAt: Date(timeIntervalSince1970: 0),
            checksums: [
                "noop-backup.sqlite": UnifiedBackupV2.sha256(db),
                UnifiedBackupV2.coachStateEntry: UnifiedBackupV2.sha256(coach),
            ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent(UnifiedBackupV2.manifestEntry))

        XCTAssertEqual(UnifiedBackupV2.validateExtracted(directory: directory), true)
        try Data("tampered".utf8).write(
            to: directory.appendingPathComponent(UnifiedBackupV2.coachStateEntry))
        XCTAssertEqual(UnifiedBackupV2.validateExtracted(directory: directory), false)
    }
}
