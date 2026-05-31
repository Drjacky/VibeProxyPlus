import Foundation

/// Health/connection status of the Dario proxy, surfaced to the UI.
public enum DarioConnectionState: Equatable, Sendable {
    case stopped
    case starting
    case running
    case failed(String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// A snapshot of Dario's runtime state for the settings UI.
public struct DarioStatusSnapshot: Equatable, Sendable {
    public let state: DarioConnectionState
    /// The local endpoint clients point at (for example http://localhost:3456).
    public let endpoint: URL
    /// Whether a Claude account is logged in (from `dario status` / `/status`).
    public let isLoggedIn: Bool
    /// Configured OpenAI-compatible backend names (from `dario backend list`).
    public let backends: [String]

    public init(state: DarioConnectionState, endpoint: URL, isLoggedIn: Bool, backends: [String]) {
        self.state = state
        self.endpoint = endpoint
        self.isLoggedIn = isLoggedIn
        self.backends = backends
    }
}

/// Abstraction over the Dario proxy lifecycle and status.
///
/// Split A (current): a mock implementation drives the UI and the engine-switch flow without the
/// real binary. Split B will provide a `ProcessRuntime`-backed implementation that launches
/// `dario proxy`, probes `GET /health`, and reads `~/.dario/config.json` (see the Phase 5
/// appendix in plans/dario-integration-architecture.md). The protocol is intentionally small so
/// both implementations satisfy the same contract.
@MainActor
public protocol DarioHost: AnyObject {
    /// Current status snapshot.
    var status: DarioStatusSnapshot { get }

    /// Invoked on the main actor whenever `status` changes.
    var onStatusChange: (() -> Void)? { get set }

    /// Starts the Dario proxy. Calls completion(true) once `/health` reports ready.
    func start(completion: @escaping (Bool) -> Void)

    /// Stops the Dario proxy cleanly.
    func stop(completion: @escaping () -> Void)

    /// Runs `dario login` to authenticate the Claude subscription. `dario proxy` is auth-gated,
    /// so this is required before the proxy will serve. Calls completion with success + a message.
    func login(completion: @escaping (Bool, String) -> Void)

    /// Recent log lines for the diagnostics view (most recent last).
    func recentLogLines() -> [String]
}
