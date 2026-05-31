import Foundation
import SwiftUI
import EngineKit

/// The cliproxyapiplus engine, conforming to the shared `Engine` contract.
///
/// Encapsulates the ThinkingProxy + ServerManager orchestration (readiness polling, Vercel
/// config sync, ordered start/stop) that previously lived in the app delegate, so the shell
/// only deals with the engine contract. Behavior is preserved from the original AppDelegate
/// implementation (ports 8317/8318, ordered startup, proxy-first shutdown).
@MainActor
public final class CLIProxyEngineImpl: Engine {
    public static let descriptor = EngineDescriptor(
        id: "cliproxyapiplus",
        displayName: "cliproxyapiplus"
    )

    private let serverManager: ServerManager
    private let thinkingProxy: ThinkingProxy

    public var onStatusChange: (() -> Void)?

    public init() {
        self.serverManager = ServerManager()
        self.thinkingProxy = ThinkingProxy()
    }

    public var isRunning: Bool { serverManager.isRunning }

    public var userVisibleURL: URL {
        URL(string: "http://localhost:\(thinkingProxy.proxyPort)")!
    }

    public var dashboardURL: URL? {
        URL(string: "http://localhost:8318/management.html")
    }

    public func activate(context: EngineContext) {
        // Sync Vercel AI Gateway config from ServerManager to ThinkingProxy and keep it in sync.
        syncVercelConfig()
        serverManager.onVercelConfigChanged = { [weak self] in
            self?.syncVercelConfig()
        }
        // Bridge the server status notification to the shell's status callback.
        NotificationCenter.default.addObserver(
            forName: .serverStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onStatusChange?()
            }
        }
    }

    public func start(completion: @escaping (Bool) -> Void) {
        // Start the thinking proxy first (port 8317), then poll for readiness before the backend.
        thinkingProxy.start()
        pollForProxyReadiness(attempts: 0, maxAttempts: 60, intervalMs: 50, completion: completion)
    }

    private func pollForProxyReadiness(
        attempts: Int,
        maxAttempts: Int,
        intervalMs: Int,
        completion: @escaping (Bool) -> Void
    ) {
        if thinkingProxy.isRunning {
            serverManager.start { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.onStatusChange?()
                        completion(true)
                    } else {
                        // Backend failed - stop the proxy to keep state consistent.
                        self?.thinkingProxy.stop()
                        completion(false)
                    }
                }
            }
            return
        }

        if attempts >= maxAttempts {
            DispatchQueue.main.async { [weak self] in
                self?.thinkingProxy.stop()
                completion(false)
            }
            return
        }

        let interval = Double(intervalMs) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.pollForProxyReadiness(
                attempts: attempts + 1,
                maxAttempts: maxAttempts,
                intervalMs: intervalMs,
                completion: completion
            )
        }
    }

    public func shutdown(completion: @escaping () -> Void) {
        // Stop the thinking proxy first to stop accepting new requests, then the backend.
        thinkingProxy.stop()
        serverManager.stop {
            DispatchQueue.main.async {
                self.onStatusChange?()
                completion()
            }
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(SettingsView(serverManager: serverManager))
    }

    // MARK: - Vercel Config Sync

    private func syncVercelConfig() {
        thinkingProxy.vercelConfig = VercelGatewayConfig(
            enabled: serverManager.vercelGatewayEnabled,
            apiKey: serverManager.vercelApiKey
        )
    }
}
