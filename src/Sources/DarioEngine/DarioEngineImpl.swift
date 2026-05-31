import Foundation
import SwiftUI
import EngineKit

/// Phase 4 stub of the Dario engine, conforming to the shared `Engine` contract.
///
/// This exists so the engine-switch flow (confirm -> shutdown -> persist -> relaunch -> boot
/// into target) can be exercised end to end before the real Dario subprocess integration lands
/// in Phase 5. It does not start any process yet; it only reports a stable identity and a
/// placeholder settings surface. On-disk home will be ~/.dario (see architecture Section 24).
@MainActor
public final class DarioEngineImpl: Engine {
    public static let descriptor = EngineDescriptor(
        id: "dario",
        displayName: "Dario"
    )

    private var running = false

    public var onStatusChange: (() -> Void)?

    public init() {}

    public var isRunning: Bool { running }

    public var userVisibleURL: URL {
        URL(string: "http://localhost:3456")!
    }

    public var dashboardURL: URL? { nil }

    public func activate(context: EngineContext) {
        // Phase 5 will bind the Dario subprocess, config resolver, and health monitor here.
    }

    public func start(completion: @escaping (Bool) -> Void) {
        running = true
        onStatusChange?()
        completion(true)
    }

    public func shutdown(completion: @escaping () -> Void) {
        running = false
        onStatusChange?()
        completion()
    }

    public func makeSettingsView() -> AnyView {
        AnyView(DarioPlaceholderView())
    }
}

/// Placeholder settings surface shown while the full Dario UI is implemented in Phase 5.
private struct DarioPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Dario Engine")
                .font(.headline)
            Text("The Dario client experience is under construction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 480, height: 740)
        .padding()
    }
}
