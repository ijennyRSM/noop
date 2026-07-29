import CryptoKit
import Foundation
import ZIPFoundation

enum UnifiedBackupV2 {
    static let manifestEntry = "manifest.json"
    static let coachStateEntry = "coach-state.json"
    static let schemaVersion = 2
    static let maxJSONBytes: Int64 = 8 * 1_024 * 1_024

    struct Manifest: Codable, Equatable {
        var schema: Int
        var app: String
        var appVersion: String
        var source: String
        var createdAt: Date
        var checksums: [String: String]
    }

    struct CoachState: Codable, Equatable {
        var schema: Int
        /// Data-valued, explicitly whitelisted UserDefaults entries encoded as Base64.
        var data: [String: String]
        var booleans: [String: Bool]
        var strings: [String: String]
        /// Versioned JSON documents. No vectors, model binaries, secrets or tokens are eligible.
        var documents: [String: String]
    }

    private static let dataKeys = ["ai.memory.facts", "ai.goals", "ai.toolConsent"]
    private static let boolKeys = ["ai.dataConsent", "ai.includeOnDeviceSignals"]
    private static let stringKeys = ["ai.preferredLanguage"]
    private static let documentFiles = [
        "plans": "coach-plans.json",
        "conversations": "coach-conversations.json",
    ]

    static func currentCoachState(defaults: UserDefaults = .standard) -> CoachState {
        let data = Dictionary(uniqueKeysWithValues: dataKeys.compactMap { key in
            defaults.data(forKey: key).map { (key, $0.base64EncodedString()) }
        })
        let booleans = Dictionary(uniqueKeysWithValues: boolKeys.compactMap { key in
            defaults.object(forKey: key).map { (key, defaults.bool(forKey: key)) }
        })
        let strings = Dictionary(uniqueKeysWithValues: stringKeys.compactMap { key in
            defaults.string(forKey: key).map { (key, $0) }
        })
        let documents = Dictionary(uniqueKeysWithValues: documentFiles.compactMap { name, file in
            guard let bytes = try? Data(contentsOf: coachDirectory().appendingPathComponent(file)),
                  bytes.count <= maxJSONBytes,
                  let text = String(data: bytes, encoding: .utf8) else { return nil }
            return (name, text)
        })
        return CoachState(schema: 1, data: data, booleans: booleans,
                          strings: strings, documents: documents)
    }

    static func addEntries(to archive: Archive,
                           databaseURL: URL,
                           settingsJSON: Data?,
                           defaults: UserDefaults = .standard) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let coachData = try encoder.encode(currentCoachState(defaults: defaults))
        let coachURL = try stage(coachData, prefix: "noop-coach-state")
        defer { try? FileManager.default.removeItem(at: coachURL) }
        try archive.addEntry(with: coachStateEntry, fileURL: coachURL, compressionMethod: .deflate)

        var checksums = ["noop-backup.sqlite": try sha256(databaseURL)]
        if let settingsJSON {
            checksums["settings.json"] = sha256(settingsJSON)
        }
        checksums[coachStateEntry] = sha256(coachData)
        let manifest = Manifest(
            schema: schemaVersion,
            app: "NOOP AI Full Beta",
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            source: "ios",
            createdAt: Date(),
            checksums: checksums
        )
        let manifestData = try encoder.encode(manifest)
        let manifestURL = try stage(manifestData, prefix: "noop-manifest")
        defer { try? FileManager.default.removeItem(at: manifestURL) }
        try archive.addEntry(with: manifestEntry, fileURL: manifestURL, compressionMethod: .deflate)
    }

    /// nil means legacy archive; false means a V2 archive failed validation.
    static func validateExtracted(directory: URL) -> Bool? {
        let manifestURL = directory.appendingPathComponent(manifestEntry)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let bytes = try? Data(contentsOf: manifestURL),
              bytes.count <= maxJSONBytes,
              let manifest = try? decoder.decode(Manifest.self, from: bytes),
              manifest.schema == schemaVersion else { return false }
        for (entry, expected) in manifest.checksums {
            let url = directory.appendingPathComponent(entry)
            guard FileManager.default.fileExists(atPath: url.path),
                  let actual = try? sha256(url),
                  actual == expected else { return false }
        }
        return true
    }

    /// Applies only whitelisted Coach state, with rollback of both defaults and documents on failure.
    static func restoreCoachState(from directory: URL,
                                  defaults: UserDefaults = .standard) -> Bool {
        let url = directory.appendingPathComponent(coachStateEntry)
        guard let data = try? Data(contentsOf: url), data.count <= maxJSONBytes,
              let state = try? JSONDecoder().decode(CoachState.self, from: data),
              state.schema == 1 else { return false }
        let oldData = Dictionary(uniqueKeysWithValues: dataKeys.map { ($0, defaults.data(forKey: $0)) })
        let oldBool = Dictionary(uniqueKeysWithValues: boolKeys.map { ($0, defaults.object(forKey: $0)) })
        let oldStrings = Dictionary(uniqueKeysWithValues: stringKeys.map { ($0, defaults.string(forKey: $0)) })
        let directoryURL = coachDirectory()
        let oldDocuments = Dictionary(uniqueKeysWithValues: documentFiles.map { name, file in
            (name, try? Data(contentsOf: directoryURL.appendingPathComponent(file)))
        })
        do {
            for (key, encoded) in state.data {
                guard dataKeys.contains(key), let decoded = Data(base64Encoded: encoded) else { continue }
                defaults.set(decoded, forKey: key)
            }
            for (key, value) in state.booleans where boolKeys.contains(key) {
                defaults.set(value, forKey: key)
            }
            for (key, value) in state.strings where stringKeys.contains(key) {
                defaults.set(value, forKey: key)
            }
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            for (name, text) in state.documents {
                guard let file = documentFiles[name],
                      let bytes = text.data(using: .utf8),
                      bytes.count <= maxJSONBytes else { continue }
                try bytes.write(to: directoryURL.appendingPathComponent(file), options: .atomic)
            }
            return true
        } catch {
            for (key, value) in oldData {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            for (key, value) in oldBool {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            for (key, value) in oldStrings {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            for (name, old) in oldDocuments {
                guard let file = documentFiles[name] else { continue }
                let target = directoryURL.appendingPathComponent(file)
                if let old { try? old.write(to: target, options: .atomic) }
                else { try? FileManager.default.removeItem(at: target) }
            }
            return false
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func coachDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("com.noopapp.noop", isDirectory: true)
    }

    private static func stage(_ data: Data, prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
