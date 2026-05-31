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
/// - IMPORTANT: `dario proxy` refuses to serve and exits with "Not authenticated" until the user
///   has run `dario login`. The host treats that as a distinct, user-actionable state (notLoggedIn)
///   rather than a crash, so the UI can prompt the user to log in.
@MainActor
public final class ProcessDarioHost: DarioHost {
    public private(set) var status: DarioStatusSnapshot
    public var onStatusChange: (() -> Void)?

    private let binaryPath: String
    private let port: UInt16
    private let endpoint: URL
    private let logStore: LogStore
    private var process: ManagedProcess?
    /// Env marker so OrphanReaper can target only this engine's stray processes.
    private let engineMarker = "VIBEPROXY_ENGINE=dario"

    public init(binaryPath: String, port: UInt16 = 3456) {
        self.binaryPath = binaryPath
        self.port = port
        self.endpoint = URL(string: "http://localhost:\(port)")!
        self.logStore = LogStore(scope: "dario")
        self.status = DarioStatusSnapshot(
            state: .stopped,
            endpoint: endpoint,
            isLoggedIn: false,
            backends: []
        )
    }

    public func start(completion: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            update(state: .failed("Dario binary not found"))
            completion(false)
            return
        }

        update(state: .starting)
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
                self.update(state: .failed("Failed to launch dario: \(error)"))
                completion(false)
                return
            }
            // Poll /health for readiness. If the process exits early with "Not authenticated",
            // surface notLoggedIn instead of a generic failure.
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
                    update(state: .stopped)
                    status = DarioStatusSnapshot(state: .stopped, endpoint: endpoint, isLoggedIn: false, backends: status.backends)
                    logStore.append("dario is not logged in. Run Login from Dario settings.")
                    completion(false)
                    return
                }
                update(state: .failed("dario exited before becoming ready"))
                completion(false)
                return
            }
            if await probeHealth() {
                update(state: .running)
                status = DarioStatusSnapshot(state: .running, endpoint: endpoint, isLoggedIn: true, backends: status.backends)
                logStore.append("dario proxy ready - /health OK")
                completion(true)
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        // Timed out waiting for readiness; stop the process to keep state consistent.
        await process.terminate()
        update(state: .failed("dario did not become ready within timeout"))
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
            self.update(state: .stopped)
            completion()
        }
    }

    public func recentLogLines() -> [String] {
        logStore.snapshot()
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
}
