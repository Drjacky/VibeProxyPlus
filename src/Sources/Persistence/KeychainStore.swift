import Foundation
import Security
import EngineKit

/// Errors surfaced by `KeychainStore`.
public enum KeychainError: Error, Equatable {
    /// The Security framework returned a non-success status for an operation.
    case unexpectedStatus(OSStatus)
    /// Stored data could not be decoded as UTF-8 text.
    case dataDecodingFailed
}

/// A generic-password Keychain accessor whose service identifier is scoped to one engine.
///
/// Every item is stored under the service `"<servicePrefix>.<engineID>"`, so one engine can
/// never read or overwrite another engine's secrets (see plans/dario-integration-architecture.md,
/// Section 28). The `account` argument distinguishes individual secrets within an engine.
public final class KeychainStore {
    /// The fully-qualified Keychain service string used for every item.
    public let service: String

    /// - Parameters:
    ///   - engineID: The owning engine; its raw value is appended to the prefix.
    ///   - servicePrefix: Reverse-DNS prefix (the app bundle id by convention).
    public init(engineID: EngineID, servicePrefix: String) {
        self.service = "\(servicePrefix).\(engineID.rawValue)"
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Stores or replaces the secret data for `account`.
    public func set(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        // Remove any existing item first so this is an upsert.
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Stores or replaces the secret string for `account`.
    public func setString(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataDecodingFailed
        }
        try set(data, account: account)
    }

    /// Returns the secret data for `account`, or nil if no item exists.
    public func data(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Returns the secret string for `account`, or nil if no item exists.
    public func string(account: String) throws -> String? {
        guard let data = try data(account: account) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataDecodingFailed
        }
        return string
    }

    /// Deletes the secret for `account`. Returns true if an item was removed.
    @discardableResult
    public func delete(account: String) throws -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
