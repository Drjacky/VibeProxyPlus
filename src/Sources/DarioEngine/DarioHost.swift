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

/// A snapshot of Dario's runtime + authentication state for the settings UI.
///
/// Authentication has two independent dimensions:
/// - `isSubscriptionLoggedIn`: a Claude Pro/Max OAuth session (set by `login`). This is the only
///   path that uses Dario's Claude-Code stealth/fingerprint upstream.
/// - `apiKeyConfigured` / `apiKeyEnabled`: a custom base URL + API key registered as an
///   OpenAI-compatible backend. `configured` means a key is stored; `enabled` means the toggle is
///   on and the backend is active. This path is a plain pass-through (no stealth).
public struct DarioStatusSnapshot: Equatable, Sendable {
    public let state: DarioConnectionState
    /// The local endpoint clients point at (for example http://localhost:3456).
    public let endpoint: URL
    /// Whether a Claude Pro/Max subscription is authenticated via OAuth (`dario login`).
    public let isSubscriptionLoggedIn: Bool
    /// Whether an API key + base URL have been saved (key held in Keychain).
    public let apiKeyConfigured: Bool
    /// Whether the API-key backend toggle is on (the backend is registered with Dario).
    public let apiKeyEnabled: Bool
    /// Configured OpenAI-compatible backend names (from `dario backend list`).
    public let backends: [String]

    public init(
        state: DarioConnectionState,
        endpoint: URL,
        isSubscriptionLoggedIn: Bool,
        apiKeyConfigured: Bool,
        apiKeyEnabled: Bool,
        backends: [String]
    ) {
        self.state = state
        self.endpoint = endpoint
        self.isSubscriptionLoggedIn = isSubscriptionLoggedIn
        self.apiKeyConfigured = apiKeyConfigured
        self.apiKeyEnabled = apiKeyEnabled
        self.backends = backends
    }
}

/// Abstraction over the Dario proxy lifecycle and status.
///
/// A `ProcessRuntime`-backed implementation launches `dario proxy`, probes `GET /health`, runs
/// `dario login` / `dario backend add|remove`, and persists the API-key config. A mock drives the
/// UI and engine-switch flow without the binary. The protocol is intentionally small so both
/// implementations satisfy the same contract.
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

    /// Runs `dario login` to authenticate a Claude Pro/Max subscription via OAuth. This is the
    /// stealth path. Calls completion with success + a user-facing message.
    func login(completion: @escaping (Bool, String) -> Void)

    /// Saves a custom base URL + API key (key stored in Keychain). Does not require a subscription.
    /// If the API-key toggle is currently enabled, the backend is (re)registered immediately.
    /// This path is a plain pass-through and does NOT use the Claude-Code stealth/fingerprint.
    func setAPIKey(baseURL: String, apiKey: String, completion: @escaping (Bool, String) -> Void)

    /// Enables or disables the API-key backend. Enabling registers the stored credentials with
    /// Dario (`dario backend add`); disabling removes it (`dario backend remove`). Requires a key
    /// to have been saved via `setAPIKey` first when enabling.
    func setAPIKeyEnabled(_ enabled: Bool, completion: @escaping (Bool, String) -> Void)

    /// The saved API base URL (for display/prefill), or nil if none is stored.
    var savedAPIBaseURL: String? { get }

    /// Recent log lines for the diagnostics view (most recent last).
    func recentLogLines() -> [String]
}
