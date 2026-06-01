import Foundation
import EngineKit

/// In-memory `DarioHost` used when the bundled binary is absent (for example `swift run`/tests).
/// It simulates start/stop, subscription login, and the API-key backend toggle so the settings
/// surface and lifecycle are fully exercisable without the binary.
@MainActor
public final class MockDarioHost: DarioHost {
    public private(set) var status: DarioStatusSnapshot
    public var onStatusChange: (() -> Void)?

    private var logLines: [String] = []
    private let endpoint: URL
    private var subscriptionLoggedIn = false
    private var apiKeyConfigured = false
    private var apiKeyEnabled = false
    private var savedBaseURL: String?

    public init(endpoint: URL) {
        self.endpoint = endpoint
        self.status = DarioStatusSnapshot(
            state: .stopped,
            endpoint: endpoint,
            isSubscriptionLoggedIn: false,
            apiKeyConfigured: false,
            apiKeyEnabled: false,
            backends: []
        )
    }

    public var savedAPIBaseURL: String? { savedBaseURL }

    public func start(completion: @escaping (Bool) -> Void) {
        publishStatus(state: .starting)
        appendLog("dario proxy starting on \(endpoint.absoluteString) (mock)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.publishStatus(state: .running)
            self.appendLog("dario proxy ready (mock) - /health OK")
            completion(true)
        }
    }

    public func stop(completion: @escaping () -> Void) {
        appendLog("dario proxy stopping (mock)")
        publishStatus(state: .stopped)
        completion()
    }

    public func login(completion: @escaping (Bool, String) -> Void) {
        appendLog("dario login (mock) - simulating successful subscription authentication")
        subscriptionLoggedIn = true
        publishStatus(state: status.state)
        completion(true, "Logged in (mock).")
    }

    public func setAPIKey(baseURL: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            completion(false, "Base URL is required.")
            return
        }
        // Blank key with an existing key keeps the old one (edit-URL-only flow).
        guard !trimmedKey.isEmpty || apiKeyConfigured else {
            completion(false, "An API key is required.")
            return
        }
        appendLog("dario backend add (mock) - saved API key for \(trimmedURL)")
        savedBaseURL = trimmedURL
        apiKeyConfigured = true
        publishStatus(state: status.state)
        completion(true, "API key saved (mock).")
    }

    public func setAPIKeyEnabled(_ enabled: Bool, completion: @escaping (Bool, String) -> Void) {
        if enabled && !apiKeyConfigured {
            completion(false, "Save an API key and base URL first.")
            return
        }
        apiKeyEnabled = enabled
        appendLog("dario backend \(enabled ? "enabled" : "disabled") (mock)")
        publishStatus(state: status.state)
        completion(true, enabled ? "API key backend enabled (mock)." : "API key backend disabled (mock).")
    }

    public func recentLogLines() -> [String] {
        logLines
    }

    private func publishStatus(state: DarioConnectionState) {
        status = DarioStatusSnapshot(
            state: state,
            endpoint: endpoint,
            isSubscriptionLoggedIn: subscriptionLoggedIn,
            apiKeyConfigured: apiKeyConfigured,
            apiKeyEnabled: apiKeyEnabled,
            backends: apiKeyEnabled ? ["claude-api"] : []
        )
        onStatusChange?()
    }

    private func appendLog(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logLines.append("[\(timestamp)] \(line)")
        if logLines.count > 200 {
            logLines.removeFirst(logLines.count - 200)
        }
    }
}
