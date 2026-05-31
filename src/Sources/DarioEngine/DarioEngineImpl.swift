import Foundation
import SwiftUI
import EngineKit

/// The Dario engine, conforming to the shared `Engine` contract.
///
/// Phase 5 Split A: lifecycle and UI are driven by a `DarioHost` abstraction with a mock
/// implementation, so the full Dario settings surface and the engine-switch flow are reviewable
/// before the real `dario proxy` subprocess integration (Split B). The contract surface and UI do
/// not change when the real host is swapped in. On-disk home is ~/.dario; default endpoint
/// http://localhost:3456 (see the Phase 5 appendix in plans/dario-integration-architecture.md).
@MainActor
public final class DarioEngineImpl: Engine {
    public static let descriptor = EngineDescriptor(
        id: "dario",
        displayName: "Dario"
    )

    private let host: DarioHost
    private let endpoint: URL

    public var onStatusChange: (() -> Void)?

    /// - Parameter host: Injectable for tests / Split B. Defaults to the mock host.
    public init(host: DarioHost? = nil) {
        let endpoint = URL(string: "http://localhost:3456")!
        self.endpoint = endpoint
        self.host = host ?? MockDarioHost(endpoint: endpoint)
    }

    public var isRunning: Bool { host.status.state.isRunning }

    public var userVisibleURL: URL { endpoint }

    // Dario's "dashboard" is a terminal TUI, not a web page, so there is no web dashboard to open.
    public var dashboardURL: URL? { nil }

    public func activate(context: EngineContext) {
        host.onStatusChange = { [weak self] in
            self?.onStatusChange?()
        }
    }

    public func start(completion: @escaping (Bool) -> Void) {
        host.start { [weak self] success in
            self?.onStatusChange?()
            completion(success)
        }
    }

    public func shutdown(completion: @escaping () -> Void) {
        host.stop { [weak self] in
            self?.onStatusChange?()
            completion()
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(DarioSettingsView(host: host))
    }
}
