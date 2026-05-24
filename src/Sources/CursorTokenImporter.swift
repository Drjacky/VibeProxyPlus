import CryptoKit
import Foundation
import SQLite3

enum CursorTokenImporterError: LocalizedError {
    case cursorNotInstalled
    case databaseUnavailable(String)
    case tokensNotFound
    case missingRefreshToken
    case failedToWrite(String)

    var errorDescription: String? {
        switch self {
        case .cursorNotInstalled:
            return "Cursor IDE is not installed or has no saved login on this Mac."
        case .databaseUnavailable(let message):
            return message
        case .tokensNotFound:
            return "No Cursor access token found. Open Cursor IDE and sign in, then try again."
        case .missingRefreshToken:
            return "Cursor refresh token is missing. Sign out and sign in again in Cursor IDE."
        case .failedToWrite(let message):
            return message
        }
    }
}

struct CursorTokenImportResult: Equatable {
    let fileURL: URL
    let email: String?
    let skippedUnchanged: Bool
}

/// Reads Cursor IDE auth from `state.vscdb` and writes `cursor.json` for CLIProxyAPIPlus.
final class CursorTokenImporter {
    static let shared = CursorTokenImporter()
    static let authType = "cursor"

    private let fileManager: FileManager
    private let authDirectoryURL: URL
    private let queue: DispatchQueue
    private var vscdbMonitor: DispatchSourceFileSystemObject?
    private var pendingDebounce: DispatchWorkItem?
    private var onTokensChanged: (() -> Void)?

    init(
        fileManager: FileManager = .default,
        authDirectoryURL: URL? = nil,
        queue: DispatchQueue = DispatchQueue(label: "io.automaze.vibeproxy.cursor-importer", qos: .userInitiated)
    ) {
        self.fileManager = fileManager
        self.authDirectoryURL = authDirectoryURL
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        self.queue = queue
    }

    static func cursorGlobalStorageURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage")
    }

    static func cursorStateDatabaseURL(fileManager: FileManager = .default) -> URL {
        cursorGlobalStorageURL(fileManager: fileManager).appendingPathComponent("state.vscdb")
    }

    // MARK: - Monitoring

    func startMonitoring(onTokensChanged: @escaping () -> Void) {
        queue.async {
            self.onTokensChanged = onTokensChanged
            self.installVSCDBMonitor()
        }
    }

    func stopMonitoring() {
        queue.async {
            self.pendingDebounce?.cancel()
            self.pendingDebounce = nil
            self.vscdbMonitor?.cancel()
            self.vscdbMonitor = nil
            self.onTokensChanged = nil
        }
    }

    private func installVSCDBMonitor() {
        vscdbMonitor?.cancel()
        vscdbMonitor = nil

        let dbURL = Self.cursorStateDatabaseURL(fileManager: fileManager)
        let watchURL = dbURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: dbURL.path) else {
            NSLog("[CursorTokenImporter] state.vscdb not found at %@", dbURL.path)
            return
        }

        let descriptor = open(watchURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("[CursorTokenImporter] Could not watch %@", watchURL.path)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedImport()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        vscdbMonitor = source
        NSLog("[CursorTokenImporter] Watching %@", watchURL.path)
    }

    private func scheduleDebouncedImport() {
        pendingDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                if try self.importTokens(force: false) != nil {
                    DispatchQueue.main.async {
                        self.onTokensChanged?()
                    }
                }
            } catch {
                NSLog("[CursorTokenImporter] Auto-import failed: %@", error.localizedDescription)
            }
        }
        pendingDebounce = work
        queue.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // MARK: - Import

    @discardableResult
    func importTokens(force: Bool) throws -> CursorTokenImportResult? {
        try queue.sync {
            try performImport(force: force)
        }
    }

    private func performImport(force: Bool) throws -> CursorTokenImportResult? {
        let dbURL = Self.cursorStateDatabaseURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: dbURL.path) else {
            throw CursorTokenImporterError.cursorNotInstalled
        }

        let storage = try readAuthStorage(from: dbURL)
        guard let accessToken = storage["cursorAuth/accessToken"] as? String,
              !accessToken.isEmpty else {
            throw CursorTokenImporterError.tokensNotFound
        }
        guard let refreshToken = storage["cursorAuth/refreshToken"] as? String,
              !refreshToken.isEmpty else {
            throw CursorTokenImporterError.missingRefreshToken
        }

        let email = (storage["cursorAuth/cachedEmail"] as? String)
            ?? (storage["cursorAuth/email"] as? String)

        let fingerprint = tokenFingerprint(accessToken: accessToken, refreshToken: refreshToken)
        let targetFile = authDirectoryURL.appendingPathComponent(
            CursorJWTHelper.credentialFileName(accessToken: accessToken)
        )

        if !force,
           let existing = try? Data(contentsOf: targetFile),
           let existingJSON = try? JSONSerialization.jsonObject(with: existing) as? [String: Any],
           let existingAccess = existingJSON["access_token"] as? String,
           let existingRefresh = existingJSON["refresh_token"] as? String,
           tokenFingerprint(accessToken: existingAccess, refreshToken: existingRefresh) == fingerprint {
            return CursorTokenImportResult(fileURL: targetFile, email: email, skippedUnchanged: true)
        }

        try fileManager.createDirectory(at: authDirectoryURL, withIntermediateDirectories: true)

        let expiresAt = CursorJWTHelper.expiryDate(accessToken: accessToken)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var metadata: [String: Any] = [
            "type": Self.authType,
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "expires_at": formatter.string(from: expiresAt),
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let sub = CursorJWTHelper.subject(accessToken) {
            metadata["sub"] = sub
        }
        if let email, !email.isEmpty {
            metadata["email"] = email
        }

        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        do {
            try data.write(to: targetFile, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: targetFile.path)
        } catch {
            throw CursorTokenImporterError.failedToWrite(
                "Failed to write \(targetFile.path): \(error.localizedDescription)"
            )
        }

        NSLog("[CursorTokenImporter] Wrote %@", targetFile.lastPathComponent)
        return CursorTokenImportResult(fileURL: targetFile, email: email, skippedUnchanged: false)
    }

    // MARK: - SQLite

    private func readAuthStorage(from databaseURL: URL) throws -> [String: Any] {
        var database: OpaquePointer?
        let path = databaseURL.path
        let uri = "file:\(path)?mode=ro&immutable=1"
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        let status = sqlite3_open_v2(uri, &database, openFlags, nil)
        guard status == SQLITE_OK, let database else {
            let message = String(cString: sqlite3_errstr(status))
            throw CursorTokenImporterError.databaseUnavailable("Could not open Cursor database: \(message)")
        }
        defer { sqlite3_close(database) }

        var merged: [String: Any] = [:]
        for table in ["ItemTable", "cursorDiskKV"] {
            let query = "SELECT key, value FROM \(table) WHERE key LIKE 'cursorAuth/%'"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                continue
            }
            defer { sqlite3_finalize(statement) }

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyCString = sqlite3_column_text(statement, 0) else {
                    continue
                }
                let key = String(cString: keyCString)
                guard key.hasPrefix("cursorAuth/") else {
                    continue
                }
                if let value = columnString(statement, column: 1) {
                    merged[key] = parseStorageValue(value)
                }
            }
        }
        return merged
    }

    private func columnString(_ statement: OpaquePointer?, column: Int32) -> String? {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_TEXT:
            guard let cString = sqlite3_column_text(statement, column) else {
                return nil
            }
            return String(cString: cString)
        case SQLITE_BLOB:
            guard let bytes = sqlite3_column_blob(statement, column) else {
                return nil
            }
            let length = Int(sqlite3_column_bytes(statement, column))
            return String(data: Data(bytes: bytes, count: length), encoding: .utf8)
        default:
            return nil
        }
    }

    private func parseStorageValue(_ raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""),
           let data = trimmed.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            return decoded
        }
        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            return decoded
        }
        return trimmed
    }

    private func tokenFingerprint(accessToken: String, refreshToken: String) -> String {
        let digest = SHA256.hash(data: Data("\(accessToken)\n\(refreshToken)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
