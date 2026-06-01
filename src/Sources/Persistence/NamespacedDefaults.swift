import Foundation
import EngineKit

/// A `UserDefaults` wrapper that scopes all keys to a single engine (or the shell).
///
/// Engine preferences live in a dedicated suite (`suiteName`) so keys from different engines
/// can never collide or be read across boundaries. The shell uses the standard domain with a
/// `shell.` key prefix. Reads and writes go through this type so scoping is enforced in one
/// place.
public final class NamespacedDefaults {
    private let defaults: UserDefaults
    private let keyPrefix: String

    /// Creates a namespaced view over an explicit defaults store.
    ///
    /// - Parameters:
    ///   - defaults: Backing store. For engines this is a per-suite `UserDefaults`.
    ///   - keyPrefix: Optional prefix applied to every key (used by the shell).
    public init(defaults: UserDefaults, keyPrefix: String = "") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    /// Creates a per-engine namespaced store backed by a dedicated suite.
    ///
    /// - Parameters:
    ///   - engineID: The owning engine; its raw value forms the suite name.
    ///   - suitePrefix: Reverse-DNS prefix for the suite (the app bundle id by convention).
    public convenience init?(engineID: EngineID, suitePrefix: String) {
        let suiteName = "\(suitePrefix).engine.\(engineID.rawValue)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.init(defaults: suite, keyPrefix: "")
    }

    private func namespaced(_ key: String) -> String {
        keyPrefix.isEmpty ? key : "\(keyPrefix)\(key)"
    }

    public func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: namespaced(key))
    }

    public func object(forKey key: String) -> Any? {
        defaults.object(forKey: namespaced(key))
    }

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: namespaced(key))
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: namespaced(key))
    }

    public func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: namespaced(key))
    }

    public func integer(forKey key: String) -> Int {
        defaults.integer(forKey: namespaced(key))
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        defaults.dictionary(forKey: namespaced(key))
    }

    public func array(forKey key: String) -> [Any]? {
        defaults.array(forKey: namespaced(key))
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: namespaced(key))
    }
}
