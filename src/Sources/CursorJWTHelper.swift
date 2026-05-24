import CryptoKit
import Foundation

enum CursorJWTHelper {
    /// Parses JWT `exp` and returns expiry with a 5-minute safety margin (matches CLIProxyAPIPlus).
    static func expiryDate(accessToken: String, now: Date = Date()) -> Date {
        guard let exp = expirationTimestamp(accessToken) else {
            return now.addingTimeInterval(3600)
        }
        let seconds = exp >= 1_000_000_000_000 ? exp / 1000 : exp
        let expiry = Date(timeIntervalSince1970: seconds)
        return expiry.addingTimeInterval(-5 * 60)
    }

    static func expirationTimestamp(_ token: String) -> Double? {
        guard let payload = decodePayload(token),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return nil
        }
        if let exp = json["exp"] as? Double {
            return exp
        }
        if let exp = json["exp"] as? Int {
            return Double(exp)
        }
        return nil
    }

    static func subject(_ token: String) -> String? {
        guard let payload = decodePayload(token),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let sub = json["sub"] as? String,
              !sub.isEmpty else {
            return nil
        }
        return sub
    }

    /// Short hex hash from JWT `sub` for multi-account filenames (8 hex chars).
    static func subjectFileHash(_ token: String) -> String {
        guard let sub = subject(token) else {
            return ""
        }
        let digest = SHA256.hash(data: Data(sub.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    static func credentialFileName(accessToken: String) -> String {
        let hash = subjectFileHash(accessToken)
        if hash.isEmpty {
            return "cursor.json"
        }
        return "cursor.\(hash).json"
    }

    static func decodePayload(_ token: String) -> Data? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return nil
        }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 2:
            base64 += "=="
        case 3:
            base64 += "="
        default:
            break
        }
        return Data(base64Encoded: base64)
    }
}
