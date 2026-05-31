import XCTest
import EngineKit
@testable import Persistence

final class KeychainStoreTests: XCTestCase {
    func testServiceIsScopedToEngine() {
        let cliproxy = KeychainStore(engineID: "cliproxyapiplus", servicePrefix: "com.example.app")
        let dario = KeychainStore(engineID: "dario", servicePrefix: "com.example.app")

        XCTAssertEqual(cliproxy.service, "com.example.app.cliproxyapiplus")
        XCTAssertEqual(dario.service, "com.example.app.dario")
        // The isolation guarantee: distinct engines never share a Keychain service.
        XCTAssertNotEqual(cliproxy.service, dario.service)
    }

    func testRoundTripWhenKeychainAvailable() throws {
        // The Keychain may be unavailable in headless CI (no entitled keychain). Treat a
        // status error as an environment limitation rather than a logic failure, but assert
        // correctness wherever the Keychain is usable.
        let store = KeychainStore(engineID: EngineID("test-\(UUID().uuidString)"), servicePrefix: "com.example.test")
        let account = "api-key"
        let secret = "s3cr3t-value"

        do {
            try store.setString(secret, account: account)
        } catch KeychainError.unexpectedStatus(let status) {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }

        defer { try? store.delete(account: account) }

        XCTAssertEqual(try store.string(account: account), secret)
        XCTAssertTrue(try store.delete(account: account))
        XCTAssertNil(try store.string(account: account))
    }
}
