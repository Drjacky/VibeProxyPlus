import Foundation
import EngineKit
import ProcessRuntime
import Diagnostics

/// Real `DarioHost` backed by the bundled `dario` binary via `ProcessRuntime.ManagedProcess`.
///
/// Runtime facts derived from askalf/dario (see the Phase 5 appendix in
/// plans/dario-integration-architecture.md):
/// - `dario proxy --port <p> --host 127.0.0.1` starts the local proxy.
/// - `GET /health` (unauthenticated) is the readiness probe.
/// - `dario` reads/writes `~/.dario`; we leave HOME intact so it finds its config + credentials.
/// - `dario login` authenticates a Claude Pro/Max subscription via OAuth (the stealth path).
/// - `dario backend add/remove` manages an OpenAI-compatible api-key + base-url upstream (no
///   stealth). The stored key is persisted by `DarioCredentialStore` so the enable/disable toggle
///   can register/unregister the backend without the user re-entering it.
@MainActor
public final class ProcessDarioHost: DarioHost {
    /// Backend name used for the API-key upstream registered via `dario backend add`. A fixed name
    /// so re-saving overwrites the same entry (Dario supports a single OpenAI-compat backend).
    public static let apiBackendName = "claude-api"

    public private(set) var status: DarioStatusSnapshot
    public var onStatusChange: (() -> Void)?

    /// Persists the api-key backend credentials + enabled flag. Set by the engine on activation.
    public var credentialStore: DarioCredentialStore? {
        didSet { refreshAuthStateFromStore() }
    }

    private let binaryPath: String
    private let port: UInt16
    private let endpoint: URL
    private let logStore: LogStore
    private var process: ManagedProcess?
    private var subscriptionLoggedIn = false

    public init(binaryPath: String, port: UInt16 = 3456) {
        self.binaryPath = binaryPath
        self.port = port
        self.endpoint = URL(string: "http://localhost:\(port)")!
        self.logStore = LogStore(scope: "dario")
        self.status = DarioStatusSnapshot(
            state: .stopped,
            endpoint: endpoint,
            isSubscriptionLoggedIn: false,
            apiKeyConfigured: false,
            apiKeyEnabled: false,
            backends: []
        )
    }

    public var savedAPIBaseURL: String? { credentialStore?.baseURL }

    private func refreshAuthStateFromStore() {
        publishStatus(state: status.state)
    }

    public func start(completion: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            publishStatus(state: .failed("Dario binary not found"))
            completion(false)
            return
        }

        publishStatus(state: .starting)
        logStore.append("Starting dario proxy on \(endpoint.absoluteString)")

        var environment = ["VIBEPROXY_ENGINE": "dario", "DARIO_PORT": String(port)]
        // Preserve HOME and PATH so dario locates ~/.dario and any helper binaries.
        if let home = ProcessInfo.processInfo.environment["HOME"] { environment["HOME"] = home }
        if let path = ProcessInfo.processInfo.environment["PATH"] { environment["PATH"] = path }

        let config = ManagedProcessConfiguration(
            executablePath: binaryPath,
            arguments: ["proxy", "--port", String(port), "--host", "127.0.0.1"],
            environment: environment
        )

        let logStore = self.logStore
        let process = ManagedProcess(configuration: config) { @Sendable line in
            logStore.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        self.process = process

        Task {
            do {
                try await process.launch()
            } catch {
                self.publishStatus(state: .failed("Failed to launch dario: \(error)"))
                completion(false)
                return
            }
            await self.pollReadiness(process: process, completion: completion)
        }
    }

    private func pollReadiness(process: ManagedProcess, completion: @escaping (Bool) -> Void) async {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            // If the process already exited, classify why from the captured log.
            if await process.isRunning == false {
                let log = logStore.snapshot().joined(separator: "\n")
                if log.contains("Not authenticated") {
                    subscriptionLoggedIn = false
                    publishStatus(state: .failed(notAuthenticatedReason))
                    logStore.append(notAuthenticatedReason)
                    completion(false)
                    return
                }
                publishStatus(state: .failed("dario exited before becoming ready"))
                completion(false)
                return
            }
            if await probeHealth() {
                publishStatus(state: .running)
                logStore.append("dario proxy ready - /health OK")
                completion(true)
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        await process.terminate()
        publishStatus(state: .failed("dario did not become ready within timeout"))
        completion(false)
    }

    private func probeHealth() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func stop(completion: @escaping () -> Void) {
        logStore.append("Stopping dario proxy")
        let process = self.process
        Task {
            await process?.terminate()
            self.process = nil
            self.publishStatus(state: .stopped)
            completion()
        }
    }

    public func login(completion: @escaping (Bool, String) -> Void) {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            completion(false, "Dario binary not found")
            return
        }
        logStore.append("Running dario login - complete the browser flow to authenticate")

        let process = makeProcess(arguments: ["login"])
        Task {
            do {
                try await process.launch()
            } catch {
                completion(false, "Failed to start dario login: \(error)")
                return
            }
            let deadline = Date().addingTimeInterval(180)
            while Date() < deadline {
                if await process.isRunning == false {
                    let exit = await process.terminationStatus() ?? -1
                    if exit == 0 {
                        self.subscriptionLoggedIn = true
                        self.publishStatus(state: self.status.state)
                        completion(true, "Logged in to your Claude subscription.")
                    } else {
                        completion(false, "dario login exited with status \(exit). Check the logs.")
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await process.terminate()
            completion(false, "dario login timed out. Try again.")
        }
    }

    public func setAPIKey(baseURL: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            completion(false, "Base URL is required.")
            return
        }
        guard let scheme = URL(string: trimmedURL)?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            completion(false, "Base URL must start with http:// or https://")
            return
        }
        // When the key field is left blank, keep the previously-stored key (so editing just the
        // base URL doesn't require re-entering the secret).
        let effectiveKey = trimmedKey.isEmpty ? (credentialStore?.apiKey ?? "") : trimmedKey
        guard !effectiveKey.isEmpty else {
            completion(false, "An API key is required.")
            return
        }

        // The store writes Dario's own backend file (~/.dario/backends/claude-api.json) directly,
        // so no `dario backend add` subprocess is needed. A restart of the proxy is required for
        // Dario to pick up the change while running.
        credentialStore?.save(baseURL: trimmedURL, apiKey: effectiveKey)
        logStore.append("Saved Dario API backend for \(trimmedURL) (key redacted)")
        publishStatus(state: status.state)

        if credentialStore?.isEnabled == true {
            completion(true, "API key saved. Restart the server to apply the change.")
        } else {
            completion(true, "API key saved. Enable \"Use API key\" to route through it.")
        }
    }

    public func setAPIKeyEnabled(_ enabled: Bool, completion: @escaping (Bool, String) -> Void) {
        guard let store = credentialStore else {
            completion(false, "Credential storage unavailable.")
            return
        }
        if enabled {
            guard store.hasAPIKey else {
                completion(false, "Save an API key and base URL first.")
                return
            }
        }
        // Enabling/disabling just moves Dario's backend file in/out of the active slot. A running
        // proxy needs a restart to observe the change.
        store.setEnabled(enabled)
        publishStatus(state: status.state)
        let restartHint = status.state.isRunning ? " Restart the server to apply." : ""
        completion(true, (enabled ? "API key backend enabled." : "API key backend disabled.") + restartHint)
    }

    private func makeProcess(arguments: [String]) -> ManagedProcess {
        var environment: [String: String] = ["VIBEPROXY_ENGINE": "dario"]
        if let home = ProcessInfo.processInfo.environment["HOME"] { environment["HOME"] = home }
        if let path = ProcessInfo.processInfo.environment["PATH"] { environment["PATH"] = path }
        let logStore = self.logStore
        let config = ManagedProcessConfiguration(
            executablePath: binaryPath,
            arguments: arguments,
            environment: environment
        )
        return ManagedProcess(configuration: config) { @Sendable line in
            logStore.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public func recentLogLines() -> [String] {
        logStore.snapshot()
    }

    /// User-facing reason shown when `dario proxy` refuses to serve because no usable auth exists.
    private var notAuthenticatedReason: String {
        if credentialStore?.isEnabled == true {
            return "Dario could not authenticate with the configured API key. Check the base URL and key in Settings."
        }
        return "Dario is not authenticated. In Settings, log in with your Claude subscription or save and enable an API key, then start the server."
    }

    private func publishStatus(state: DarioConnectionState) {
        status = DarioStatusSnapshot(
            state: state,
            endpoint: endpoint,
            isSubscriptionLoggedIn: subscriptionLoggedIn,
            apiKeyConfigured: credentialStore?.hasAPIKey ?? false,
            apiKeyEnabled: credentialStore?.isEnabled ?? false,
            backends: (credentialStore?.isEnabled ?? false) ? [Self.apiBackendName] : []
        )
        onStatusChange?()
    }
}
