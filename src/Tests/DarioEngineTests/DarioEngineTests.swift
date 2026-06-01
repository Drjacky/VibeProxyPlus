import XCTest
import EngineKit
@testable import DarioEngine

@MainActor
final class DarioEngineTests: XCTestCase {
    private func makeContext() -> EngineContext {
        EngineContext(
            engineID: DarioEngineImpl.descriptor.id,
            homeDirectory: URL(fileURLWithPath: "/tmp/.dario-test"),
            defaultsSuiteName: "test.dario",
            keychainServicePrefix: "test.dario"
        )
    }

    func testDescriptorIdentity() {
        XCTAssertEqual(DarioEngineImpl.descriptor.id, "dario")
        XCTAssertEqual(DarioEngineImpl.descriptor.displayName, "Dario")
    }

    func testUserVisibleURLAndNoDashboard() {
        let engine = DarioEngineImpl()
        XCTAssertEqual(engine.userVisibleURL.absoluteString, "http://localhost:3456")
        XCTAssertNil(engine.dashboardURL)
    }

    func testStartMarksRunningAndShutdownStops() {
        let engine = DarioEngineImpl()
        engine.activate(context: makeContext())
        XCTAssertFalse(engine.isRunning)

        let started = expectation(description: "started")
        engine.start { success in
            XCTAssertTrue(success)
            started.fulfill()
        }
        wait(for: [started], timeout: 2.0)
        XCTAssertTrue(engine.isRunning)

        let stopped = expectation(description: "stopped")
        engine.shutdown {
            stopped.fulfill()
        }
        wait(for: [stopped], timeout: 2.0)
        XCTAssertFalse(engine.isRunning)
    }

    func testStatusChangePropagates() {
        let engine = DarioEngineImpl()
        engine.activate(context: makeContext())

        var changeCount = 0
        engine.onStatusChange = { changeCount += 1 }

        let started = expectation(description: "started")
        engine.start { _ in started.fulfill() }
        wait(for: [started], timeout: 2.0)

        XCTAssertGreaterThan(changeCount, 0)
    }

    func testMockHostReportsRunningAfterStart() {
        let endpoint = URL(string: "http://localhost:3456")!
        let host = MockDarioHost(endpoint: endpoint)
        XCTAssertEqual(host.status.state, .stopped)

        let started = expectation(description: "host started")
        host.start { success in
            XCTAssertTrue(success)
            started.fulfill()
        }
        wait(for: [started], timeout: 2.0)
        XCTAssertTrue(host.status.state.isRunning)
        XCTAssertFalse(host.recentLogLines().isEmpty)
    }

    func testMockLoginWithAPIKeyMarksAuthenticatedAndAddsBackend() {
        let host = MockDarioHost(endpoint: URL(string: "http://localhost:3456")!)
        XCTAssertFalse(host.status.isLoggedIn)

        let done = expectation(description: "api login")
        host.loginWithAPIKey(baseURL: "https://api.example.com/v1", apiKey: "sk-test-123") { success, _ in
            XCTAssertTrue(success)
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
        XCTAssertTrue(host.status.isLoggedIn)
        XCTAssertEqual(host.status.backends, ["claude-api"])
    }

    func testMockLoginWithAPIKeyRejectsEmptyInput() {
        let host = MockDarioHost(endpoint: URL(string: "http://localhost:3456")!)

        let done = expectation(description: "api login rejected")
        host.loginWithAPIKey(baseURL: "  ", apiKey: "") { success, message in
            XCTAssertFalse(success)
            XCTAssertFalse(message.isEmpty)
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
        XCTAssertFalse(host.status.isLoggedIn)
    }
}
