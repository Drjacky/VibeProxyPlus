import Foundation

/// Stable, persisted identifier for an engine (for example "cliproxyapiplus" or "dario").
///
/// The raw value is used as the persisted engine selection, as the suffix for per-engine
/// `UserDefaults` suites and Keychain service prefixes, and to scope on-disk directories.
/// It must be stable across releases; changing it would orphan a user's stored selection
/// and engine-scoped data.
public struct EngineID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

extension EngineID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}
