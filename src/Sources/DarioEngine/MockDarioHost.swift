import Foundation
import EngineKit

/// In-memory `DarioHost` used in Split A to drive the UI and engine-switch flow before the real
/// Dario subprocess integration (Split B) lands. It simulates start/stop and a small status model
/// so the settings surface and lifecycle are fully reviewable without the binary.
@MainActor
public final class MockDarioHost: DarioHost {
    public private(set) var status: DarioStatusSnapshot
    public var onStatusChange: (() -> Void)?

    private var logLines: [String] = []
    private let endpoint: URL

    public init(endpoint: URL) {
        self.endpoint = endpoint
        self.status = DarioStatusSnapshot(
            state: .stopped,
            endpoint: endpoint,
            isLoggedIn: false,
            backends: []
        )
    }

    public func start(completion: @escaping (Bool) -> Void) {
        update(state: .starting)
        appendLog("dario proxy starting on \(endpoint.absoluteString) (mock)")
        // Simulate a brief readiness delay, then report running.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.status = DarioStatusSnapshot(
                state: .running,
                endpoint: self.endpoint,
                isLoggedIn: false,
                backends: []
            )
            self.appendLog("dario proxy ready (mock) - /health OK")
            self.onStatusChange?()
            completion(true)
        }
    }

    public func stop(completion: @escaping () -> Void) {
        appendLog("dario proxy stopping (mock)")
        update(state: .stopped)
        completion()
    }

    public func login(completion: @escaping (Bool, String) -> Void) {
        appendLog("dario login (mock) - simulating successful authentication")
        status = DarioStatusSnapshot(
            state: status.state,
            endpoint: endpoint,
            isLoggedIn: true,
            backends: status.backends
        )
        onStatusChange?()
        completion(true, "Logged in (mock).")
    }

    public func loginWithAPIKey(baseURL: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty else {
            completion(false, "Base URL and API key are required.")
            return
        }
        appendLog("dario backend add (mock) - configured API backend at \(trimmedURL)")
        status = DarioStatusSnapshot(
            state: status.state,
            endpoint: endpoint,
            isLoggedIn: true,
            backends: ["claude-api"]
        )
        onStatusChange?()
        completion(true, "API backend configured (mock).")
    }

    public func recentLogLines() -> [String] {
        logLines
    }

    private func update(state: DarioConnectionState) {
        status = DarioStatusSnapshot(
            state: state,
            endpoint: endpoint,
            isLoggedIn: status.isLoggedIn,
            backends: status.backends
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
