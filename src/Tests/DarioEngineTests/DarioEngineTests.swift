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

    func testMockSetAPIKeyConfiguresButDoesNotEnable() {
        let host = MockDarioHost(endpoint: URL(string: "http://localhost:3456")!)
        XCTAssertFalse(host.status.apiKeyConfigured)
        XCTAssertFalse(host.status.apiKeyEnabled)

        let done = expectation(description: "set api key")
        host.setAPIKey(baseURL: "https://api.example.com/v1", apiKey: "sk-test-123") { success, _ in
            XCTAssertTrue(success)
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
        XCTAssertTrue(host.status.apiKeyConfigured)
        XCTAssertFalse(host.status.apiKeyEnabled, "Saving a key should not auto-enable the backend")
        XCTAssertFalse(host.status.isSubscriptionLoggedIn)
        XCTAssertEqual(host.savedAPIBaseURL, "https://api.example.com/v1")
    }

    func testMockSetAPIKeyRejectsEmptyInput() {
        let host = MockDarioHost(endpoint: URL(string: "http://localhost:3456")!)

        let done = expectation(description: "set api key rejected")
        host.setAPIKey(baseURL: "  ", apiKey: "") { success, message in
            XCTAssertFalse(success)
            XCTAssertFalse(message.isEmpty)
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
        XCTAssertFalse(host.status.apiKeyConfigured)
    }

    func testCredentialStorePersistsAcrossInstances() {
        // Simulates quit/relaunch: a second store built from the same context must see the saved
        // base URL, key, and enabled flag written by the first.
        let suite = "test.dario.persist.\(UUID().uuidString)"
        let context = EngineContext(
            engineID: DarioEngineImpl.descriptor.id,
            homeDirectory: URL(fileURLWithPath: "/tmp/.dario-persist-test"),
            defaultsSuiteName: suite,
            keychainServicePrefix: "test.dario.persist.\(UUID().uuidString)"
        )
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let first = DarioCredentialStore(context: context)
        first.clear()
        XCTAssertFalse(first.hasAPIKey)
        first.save(baseURL: "https://api.example.com/v1", apiKey: "sk-persist-123")
        first.setEnabled(true)

        let second = DarioCredentialStore(context: context)
        XCTAssertTrue(second.hasAPIKey)
        XCTAssertEqual(second.baseURL, "https://api.example.com/v1")
        XCTAssertEqual(second.apiKey, "sk-persist-123")
        XCTAssertTrue(second.isEnabled)

        second.clear()
        let third = DarioCredentialStore(context: context)
        XCTAssertFalse(third.hasAPIKey)
        XCTAssertNil(third.baseURL)
        XCTAssertFalse(third.isEnabled)
    }

    func testMockEnableAPIKeyRequiresSavedKeyThenActivatesBackend() {
        let host = MockDarioHost(endpoint: URL(string: "http://localhost:3456")!)

        // Enabling before a key is saved must fail.
        let rejected = expectation(description: "enable rejected")
        host.setAPIKeyEnabled(true) { success, _ in
            XCTAssertFalse(success)
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: 2.0)
        XCTAssertFalse(host.status.apiKeyEnabled)

        // Save a key, then enabling succeeds and registers the backend.
        let saved = expectation(description: "saved")
        host.setAPIKey(baseURL: "https://api.example.com/v1", apiKey: "sk-test-123") { _, _ in saved.fulfill() }
        wait(for: [saved], timeout: 2.0)

        let enabled = expectation(description: "enabled")
        host.setAPIKeyEnabled(true) { success, _ in
            XCTAssertTrue(success)
            enabled.fulfill()
        }
        wait(for: [enabled], timeout: 2.0)
        XCTAssertTrue(host.status.apiKeyEnabled)
        XCTAssertEqual(host.status.backends, ["claude-api"])

        // Disabling clears the active backend but keeps the key configured.
        let disabled = expectation(description: "disabled")
        host.setAPIKeyEnabled(false) { success, _ in
            XCTAssertTrue(success)
            disabled.fulfill()
        }
        wait(for: [disabled], timeout: 2.0)
        XCTAssertFalse(host.status.apiKeyEnabled)
        XCTAssertTrue(host.status.apiKeyConfigured)
        XCTAssertTrue(host.status.backends.isEmpty)
    }
}
