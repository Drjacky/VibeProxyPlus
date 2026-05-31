import XCTest
import SwiftUI
@testable import EngineKit

@MainActor
final class EngineRegistryTests: XCTestCase {
    /// Minimal test engine used to exercise the registry without a concrete engine module.
    private final class StubEngine: Engine {
        static let descriptor = EngineDescriptor(id: "stub", displayName: "Stub Engine")
        var isRunning = false
        var userVisibleURL = URL(string: "http://localhost:1234")!
        var dashboardURL: URL? = nil
        var onStatusChange: (() -> Void)?
        let context: EngineContext
        init(context: EngineContext) { self.context = context }
        func activate(context: EngineContext) {}
        func start(completion: @escaping (Bool) -> Void) { completion(true) }
        func shutdown(completion: @escaping () -> Void) { completion() }
        func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
    }

    private func makeContext(_ id: EngineID) -> EngineContext {
        EngineContext(
            engineID: id,
            homeDirectory: URL(fileURLWithPath: "/tmp/\(id.rawValue)"),
            defaultsSuiteName: "test.\(id.rawValue)",
            keychainServicePrefix: "test.\(id.rawValue)"
        )
    }

    func testRegisterAndMake() {
        let registry = EngineRegistry()
        registry.register(StubEngine.descriptor) { StubEngine(context: $0) }

        XCTAssertTrue(registry.contains("stub"))
        XCTAssertEqual(registry.descriptor(for: "stub")?.displayName, "Stub Engine")

        let engine = registry.make("stub", context: makeContext("stub"))
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine?.descriptor.id, "stub")
    }

    func testMakeUnknownReturnsNil() {
        let registry = EngineRegistry()
        XCTAssertNil(registry.make("missing", context: makeContext("missing")))
        XCTAssertFalse(registry.contains("missing"))
    }

    func testDescriptorsPreserveRegistrationOrder() {
        let registry = EngineRegistry()
        registry.register(EngineDescriptor(id: "a", displayName: "A")) { StubEngine(context: $0) }
        registry.register(EngineDescriptor(id: "b", displayName: "B")) { StubEngine(context: $0) }

        XCTAssertEqual(registry.descriptors.map { $0.id }, ["a", "b"])
    }

    func testReRegisterReplacesWithoutDuplicatingOrder() {
        let registry = EngineRegistry()
        registry.register(EngineDescriptor(id: "a", displayName: "A")) { StubEngine(context: $0) }
        registry.register(EngineDescriptor(id: "a", displayName: "A v2")) { StubEngine(context: $0) }

        XCTAssertEqual(registry.descriptors.count, 1)
        XCTAssertEqual(registry.descriptor(for: "a")?.displayName, "A v2")
    }
}
