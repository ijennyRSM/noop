import Foundation

/// Model-independent constants that both the iOS adapter and deterministic tests use. Keeping the
/// asymmetric retrieval prefixes here prevents a provider refactor from silently indexing documents
/// and queries in the wrong Nomic task space.
public enum NomicEmbeddingContract {
    public static let outputDimensions = 256
    public static let maximumInputTokens = 384
    public static let modelMaximumTokens = 512
    public static let documentPrefix = "search_document: "
    public static let queryPrefix = "search_query: "

    public static func documentText(_ text: String) -> String { documentPrefix + text }
    public static func queryText(_ text: String) -> String { queryPrefix + text }
}

public enum SemanticSourceKind: String, Codable, CaseIterable, Sendable {
    case memoryFact
    case conversationTitle
    case conversationSummary
    case userMessage
    case journalQuestion
    case journalNote
    case recommendationFeedback
    case habitHypothesis
    case strengthSession
}

public enum SemanticConsentScope: String, Codable, CaseIterable, Sendable {
    case memory
    case personalLogs
    case sensitiveLogs
    case patterns
    case strength
}

public struct SemanticDocument: Equatable, Sendable {
    public let sourceKind: SemanticSourceKind
    public let sourceID: String
    public let chunkIndex: Int
    public let text: String
    public let updatedAt: Date
    public let consentScope: SemanticConsentScope
    public let priority: Int

    public init(sourceKind: SemanticSourceKind,
                sourceID: String,
                chunkIndex: Int = 0,
                text: String,
                updatedAt: Date,
                consentScope: SemanticConsentScope,
                priority: Int = 0) {
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.chunkIndex = chunkIndex
        self.text = text
        self.updatedAt = updatedAt
        self.consentScope = consentScope
        self.priority = priority
    }

    public var documentID: String {
        "\(sourceKind.rawValue):\(sourceID):\(chunkIndex)"
    }

    public var contentHash: String {
        SemanticHash.fnv1a64Hex(text)
    }
}

public struct SemanticHit: Equatable, Sendable {
    public let documentID: String
    public let sourceKind: SemanticSourceKind
    public let sourceID: String
    public let chunkIndex: Int
    public let score: Double
    public let consentScope: SemanticConsentScope

    public init(documentID: String,
                sourceKind: SemanticSourceKind,
                sourceID: String,
                chunkIndex: Int,
                score: Double,
                consentScope: SemanticConsentScope) {
        self.documentID = documentID
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.chunkIndex = chunkIndex
        self.score = score
        self.consentScope = consentScope
    }
}

public struct SemanticIndexStatus: Equatable, Sendable {
    public let modelID: String
    public let indexedDocuments: Int
    public let pendingDocuments: Int
    public let byteSize: Int64
    public let lastRunAt: Date?
    public let lastError: String?
    public let isModelLoaded: Bool

    public init(modelID: String,
                indexedDocuments: Int,
                pendingDocuments: Int,
                byteSize: Int64,
                lastRunAt: Date?,
                lastError: String?,
                isModelLoaded: Bool) {
        self.modelID = modelID
        self.indexedDocuments = indexedDocuments
        self.pendingDocuments = pendingDocuments
        self.byteSize = byteSize
        self.lastRunAt = lastRunAt
        self.lastError = lastError
        self.isModelLoaded = isModelLoaded
    }

    public var totalDocuments: Int {
        indexedDocuments + pendingDocuments
    }

    /// Rebuildable indexing progress for UI surfaces. An empty index has no work left and therefore
    /// reports completion rather than showing an indeterminate zero-percent state forever.
    public var completionFraction: Double {
        guard totalDocuments > 0 else { return 1 }
        return min(1, max(0, Double(indexedDocuments) / Double(totalDocuments)))
    }

    public var completionPercentage: Int {
        Int((completionFraction * 100).rounded(.down))
    }
}

public protocol TextEmbeddingProvider: AnyObject, Sendable {
    var modelID: String { get }
    var dimensions: Int { get }
    func prepare() async throws
    func embedDocuments(_ texts: [String]) async throws -> [[Float]]
    func embedQuery(_ text: String) async throws -> [Float]
    func unload() async
}

/// Platform-neutral orchestration boundary. Apple currently supplies the first implementation; Android
/// can adopt the same document/scope/status contract without sharing its runtime implementation.
@MainActor
public protocol SemanticMemoryCoordinator: AnyObject {
    var semanticIndexStatus: SemanticIndexStatus { get }
    func enqueueSemanticDocuments(_ documents: [SemanticDocument]) async
    func purgeSemanticScopes(_ scopes: Set<SemanticConsentScope>) async
}

public enum SemanticMemoryError: LocalizedError, Equatable {
    case invalidDimensions(expected: Int, actual: Int)
    case invalidVector
    case modelUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidDimensions(expected, actual):
            return "Expected a \(expected)-dimensional embedding, received \(actual)."
        case .invalidVector:
            return "The embedding model returned an invalid vector."
        case let .modelUnavailable(reason):
            return reason
        }
    }
}

public enum SemanticHash {
    /// Platform-neutral FNV-1a over UTF-16 code units. Swift's `hashValue` is randomized and Kotlin's
    /// `hashCode` has different semantics, so neither may identify a cross-platform source revision.
    public static func fnv1a64Hex(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for unit in text.utf16 {
            hash ^= UInt64(unit)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

public enum SemanticVector {
    public static func normalizedTruncated(_ values: [Float], dimensions: Int) throws -> [Float] {
        guard values.count >= dimensions else {
            throw SemanticMemoryError.invalidDimensions(expected: dimensions, actual: values.count)
        }
        let truncated = Array(values.prefix(dimensions))
        let squared = truncated.reduce(Float.zero) { $0 + ($1 * $1) }
        guard squared.isFinite, squared > 0 else { throw SemanticMemoryError.invalidVector }
        let norm = sqrt(squared)
        return truncated.map { $0 / norm }
    }

    public static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return -.infinity }
        var dot: Float = 0
        var leftNorm: Float = 0
        var rightNorm: Float = 0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            leftNorm += lhs[index] * lhs[index]
            rightNorm += rhs[index] * rhs[index]
        }
        guard leftNorm > 0, rightNorm > 0 else { return -.infinity }
        return Double(dot / sqrt(leftNorm * rightNorm))
    }

    public static func encodeFloat16(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * MemoryLayout<UInt16>.size)
        for value in values {
            var littleEndian = float16BitPattern(value).littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    public static func decodeFloat16(_ data: Data) -> [Float]? {
        guard data.count.isMultiple(of: MemoryLayout<UInt16>.size) else { return nil }
        var result: [Float] = []
        result.reserveCapacity(data.count / MemoryLayout<UInt16>.size)
        var index = data.startIndex
        while index < data.endIndex {
            let next = data.index(index, offsetBy: 2)
            let raw = data[index..<next].withUnsafeBytes { bytes in
                UInt16(littleEndian: bytes.loadUnaligned(as: UInt16.self))
            }
            result.append(float32(fromFloat16BitPattern: raw))
            index = next
        }
        return result
    }

    /// IEEE-754 binary32 -> binary16, including subnormals and ties-to-even rounding.
    ///
    /// This is intentionally implemented in integer space. Swift's native `Float16`
    /// conversion is unavailable when the macOS target is compiled for x86_64 with
    /// Xcode 16, while the app's universal macOS CI still has to read the same vector
    /// format written by arm64/iOS builds.
    private static func float16BitPattern(_ value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = UInt16((bits >> 16) & 0x8000)
        let exponent = Int((bits >> 23) & 0xff)
        let fraction = bits & 0x007f_ffff

        if exponent == 0xff {
            if fraction == 0 { return sign | 0x7c00 }
            return sign | 0x7e00 | UInt16((fraction >> 13) & 0x01ff)
        }

        let unbiased = exponent - 127
        if unbiased > 15 { return sign | 0x7c00 }
        if unbiased < -24 { return sign }

        if unbiased < -14 {
            let significand = fraction | 0x0080_0000
            let shift = 13 + (-14 - unbiased)
            return sign | UInt16(roundToNearestEven(significand, shiftingRight: shift))
        }

        var halfExponent = UInt32(unbiased + 15)
        var halfFraction = roundToNearestEven(fraction, shiftingRight: 13)
        if halfFraction == 0x0400 {
            halfExponent += 1
            halfFraction = 0
        }
        if halfExponent >= 0x1f { return sign | 0x7c00 }
        return sign | UInt16((halfExponent << 10) | halfFraction)
    }

    private static func roundToNearestEven(
        _ value: UInt32,
        shiftingRight shift: Int
    ) -> UInt32 {
        let truncated = value >> UInt32(shift)
        let mask = (UInt32(1) << UInt32(shift)) - 1
        let remainder = value & mask
        let halfway = UInt32(1) << UInt32(shift - 1)
        if remainder > halfway || (remainder == halfway && truncated & 1 == 1) {
            return truncated + 1
        }
        return truncated
    }

    private static func float32(fromFloat16BitPattern bits: UInt16) -> Float {
        let sign = UInt32(bits & 0x8000) << 16
        let exponent = UInt32((bits >> 10) & 0x1f)
        var fraction = UInt32(bits & 0x03ff)
        let result: UInt32

        switch exponent {
        case 0 where fraction == 0:
            result = sign
        case 0:
            var unbiased = -14
            while fraction & 0x0400 == 0 {
                fraction <<= 1
                unbiased -= 1
            }
            fraction &= 0x03ff
            result = sign
                | (UInt32(unbiased + 127) << 23)
                | (fraction << 13)
        case 0x1f:
            result = sign | 0x7f80_0000 | (fraction << 13)
        default:
            result = sign
                | (UInt32(Int(exponent) - 15 + 127) << 23)
                | (fraction << 13)
        }
        return Float(bitPattern: result)
    }
}
