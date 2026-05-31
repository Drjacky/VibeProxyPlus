import XCTest
@testable import EngineKit

final class EngineSelectionStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "test.selection.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func testDefaultsToProvidedEngineWhenUnset() {
        let store = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        XCTAssertEqual(store.selectedEngineID, "cliproxyapiplus")
        XCTAssertFalse(store.isSwitchPending)
    }

    func testBeginSwitchPersistsSelectionAndPending() {
        let store = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        store.beginSwitch(to: "dario")

        XCTAssertEqual(store.selectedEngineID, "dario")
        XCTAssertTrue(store.isSwitchPending)
        XCTAssertEqual(store.relaunchGeneration, 1)
    }

    func testCompleteSwitchClearsPending() {
        let store = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        store.beginSwitch(to: "dario")
        store.completeSwitch()

        XCTAssertEqual(store.selectedEngineID, "dario")
        XCTAssertFalse(store.isSwitchPending)
    }

    func testSelectionPersistsAcrossStoreInstances() {
        let first = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        first.beginSwitch(to: "dario")

        // Simulate a relaunch: a fresh store over the same backing defaults.
        let second = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        XCTAssertEqual(second.selectedEngineID, "dario")
        XCTAssertTrue(second.isSwitchPending)
    }

    func testRelaunchGenerationIncrementsPerSwitch() {
        let store = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        store.beginSwitch(to: "dario")
        store.beginSwitch(to: "cliproxyapiplus")
        XCTAssertEqual(store.relaunchGeneration, 2)
    }

    func testDidRelaunchRecently() {
        let store = EngineSelectionStore(defaults: defaults, defaultEngineID: "cliproxyapiplus")
        let now = Date()
        store.beginSwitch(to: "dario", now: now)

        XCTAssertTrue(store.didRelaunchRecently(within: 10, now: now.addingTimeInterval(2)))
        XCTAssertFalse(store.didRelaunchRecently(within: 10, now: now.addingTimeInterval(20)))
    }
}
