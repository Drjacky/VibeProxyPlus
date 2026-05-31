import XCTest
import EngineKit
@testable import Persistence

final class NamespacedDefaultsTests: XCTestCase {
    private var suiteNames: [String] = []

    private func makeSuite() -> (UserDefaults, String) {
        let name = "test.persistence.\(UUID().uuidString)"
        suiteNames.append(name)
        return (UserDefaults(suiteName: name)!, name)
    }

    override func tearDown() {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testRoundTripValues() {
        let (suite, _) = makeSuite()
        let defaults = NamespacedDefaults(defaults: suite)

        defaults.set("hello", forKey: "greeting")
        defaults.set(true, forKey: "flag")
        defaults.set(42, forKey: "count")

        XCTAssertEqual(defaults.string(forKey: "greeting"), "hello")
        XCTAssertTrue(defaults.bool(forKey: "flag"))
        XCTAssertEqual(defaults.integer(forKey: "count"), 42)
    }

    func testKeyPrefixIsApplied() {
        let (suite, _) = makeSuite()
        let prefixed = NamespacedDefaults(defaults: suite, keyPrefix: "shell.")

        prefixed.set("x", forKey: "launchAtLogin")

        // The raw key in the backing store is prefixed.
        XCTAssertEqual(suite.string(forKey: "shell.launchAtLogin"), "x")
        // Reading through the namespaced view returns the value via the prefixed key.
        XCTAssertEqual(prefixed.string(forKey: "launchAtLogin"), "x")
        // The unprefixed key is absent.
        XCTAssertNil(suite.string(forKey: "launchAtLogin"))
    }

    func testEnginesUseSeparateSuites() {
        let cliproxy = NamespacedDefaults(engineID: "cliproxyapiplus", suitePrefix: "test.iso")
        let dario = NamespacedDefaults(engineID: "dario", suitePrefix: "test.iso")
        suiteNames.append("test.iso.engine.cliproxyapiplus")
        suiteNames.append("test.iso.engine.dario")

        XCTAssertNotNil(cliproxy)
        XCTAssertNotNil(dario)

        cliproxy?.set("cli-value", forKey: "sharedKey")
        dario?.set("dario-value", forKey: "sharedKey")

        // Same key name, different suites -> no cross-contamination.
        XCTAssertEqual(cliproxy?.string(forKey: "sharedKey"), "cli-value")
        XCTAssertEqual(dario?.string(forKey: "sharedKey"), "dario-value")
    }

    func testRemoveObject() {
        let (suite, _) = makeSuite()
        let defaults = NamespacedDefaults(defaults: suite)
        defaults.set("temp", forKey: "k")
        defaults.removeObject(forKey: "k")
        XCTAssertNil(defaults.string(forKey: "k"))
    }
}
