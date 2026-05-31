import Foundation
import SwiftUI

/// Primitives the shell hands an engine at activation.
///
/// EngineKit is the contract sink (Foundation only), so the context carries plain values
/// rather than concrete Persistence/Diagnostics types. The shell derives those primitives
/// (per-engine dotfolder, defaults suite name, Keychain service prefix) from the engine id and
/// the engine builds its own storage objects from them. See plans/dario-integration-architecture.md
/// Sections 4, 26-28.
public struct EngineContext: Sendable {
    /// The engine this context belongs to.
    public let engineID: EngineID
    /// Absolute path to the engine's on-disk home dotfolder (for example `~/.cli-proxy-api`).
    public let homeDirectory: URL
    /// Suite name for the engine's dedicated `UserDefaults`.
    public let defaultsSuiteName: String
    /// Keychain service prefix scoped to this engine.
    public let keychainServicePrefix: String

    public init(
        engineID: EngineID,
        homeDirectory: URL,
        defaultsSuiteName: String,
        keychainServicePrefix: String
    ) {
        self.engineID = engineID
        self.homeDirectory = homeDirectory
        self.defaultsSuiteName = defaultsSuiteName
        self.keychainServicePrefix = keychainServicePrefix
    }
}

/// The contract every engine implements. The shell interacts with the active engine only
/// through this protocol, never through concrete engine types.
///
/// Lifecycle methods are callback-based and `@MainActor` to match the existing UI-driven code;
/// a later phase may migrate to async/await. The shell owns menu/window chrome and asks the
/// engine for its settings surface, status, and lifecycle transitions.
@MainActor
public protocol Engine: AnyObject {
    /// Static metadata describing this engine type.
    static var descriptor: EngineDescriptor { get }

    /// Whether the engine's services are currently running.
    var isRunning: Bool { get }

    /// The URL a user points their client at (for example `http://localhost:8317`).
    var userVisibleURL: URL { get }

    /// An optional management/dashboard URL, or nil if the engine has none.
    var dashboardURL: URL? { get }

    /// Invoked on the main actor whenever running status changes, so the shell can refresh
    /// menu bar state. The shell sets this after activation.
    var onStatusChange: (() -> Void)? { get set }

    /// Binds engine resources from the context. Called once before `start`. No network yet.
    func activate(context: EngineContext)

    /// Starts the engine's services. Calls `completion(true)` once ready, `false` on failure.
    func start(completion: @escaping (Bool) -> Void)

    /// Stops the engine's services cleanly. Calls `completion()` once fully stopped.
    func shutdown(completion: @escaping () -> Void)

    /// The engine-specific settings/UI surface the shell hosts in its window.
    func makeSettingsView() -> AnyView
}

public extension Engine {
    /// Instance access to the static descriptor.
    var descriptor: EngineDescriptor { Self.descriptor }
}
