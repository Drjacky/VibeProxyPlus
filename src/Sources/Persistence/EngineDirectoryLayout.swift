import Foundation
import EngineKit

/// Resolves the on-disk home and standard subdirectories for a single engine.
///
/// Each engine lives in its own parallel dotfolder in the user's home directory
/// (for example `~/.cli-proxy-api` and `~/.dario`). Config, credentials, logs, cache, and
/// temporary files all live under that home, so engines never share on-disk state.
///
/// The home directory name is provided explicitly rather than derived from the engine id,
/// because the cliproxyapiplus engine must keep its existing `~/.cli-proxy-api` path for
/// backward compatibility (it does not match its engine id).
public struct EngineDirectoryLayout: Sendable {
    /// The engine this layout belongs to.
    public let engineID: EngineID

    /// Absolute path to the engine's home dotfolder (for example `~/.dario`).
    public let home: URL

    private let fileManager: FileManager

    /// - Parameters:
    ///   - engineID: The owning engine.
    ///   - homeDirectoryName: Dotfolder name under the user's home (for example ".dario").
    ///   - baseDirectory: The user's home directory. Overridable for tests.
    ///   - fileManager: Injectable for tests.
    public init(
        engineID: EngineID,
        homeDirectoryName: String,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.engineID = engineID
        self.fileManager = fileManager
        let base = baseDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.home = base.appendingPathComponent(homeDirectoryName, isDirectory: true)
    }

    /// Directory for engine logs (`<home>/logs`).
    public var logs: URL { home.appendingPathComponent("logs", isDirectory: true) }

    /// Directory for engine caches (`<home>/cache`).
    public var cache: URL { home.appendingPathComponent("cache", isDirectory: true) }

    /// Directory for engine temporary files (`<home>/tmp`).
    public var temp: URL { home.appendingPathComponent("tmp", isDirectory: true) }

    /// Creates the home directory if needed. Subdirectories are created lazily via
    /// `ensure(_:)` so an engine only materializes the directories it actually uses.
    @discardableResult
    public func ensureHome() throws -> URL {
        try ensure(home)
    }

    /// Creates the given directory (and intermediates) if it does not already exist and
    /// returns it. The directory must be `home` or one of its subdirectories.
    @discardableResult
    public func ensure(_ directory: URL) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
