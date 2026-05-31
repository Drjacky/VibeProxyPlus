import XCTest
@testable import EngineKit

final class CrashSentinelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CrashSentinelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstBootIsNotACrash() {
        let sentinel = CrashSentinel(defaults: defaults)
        XCTAssertFalse(sentinel.markBootStarted())
        XCTAssertEqual(sentinel.consecutiveCrashCount, 0)
    }

    func testBootWithoutCleanShutdownIsDetectedAsCrash() {
        // First run starts but never marks a clean shutdown.
        CrashSentinel(defaults: defaults).markBootStarted()
        // Next run should observe the in-progress flag and report a crash.
        let secondRun = CrashSentinel(defaults: defaults)
        XCTAssertTrue(secondRun.markBootStarted())
        XCTAssertEqual(secondRun.consecutiveCrashCount, 1)
    }

    func testCleanShutdownClearsCrashState() {
        let first = CrashSentinel(defaults: defaults)
        first.markBootStarted()
        first.markCleanShutdown()
        let second = CrashSentinel(defaults: defaults)
        XCTAssertFalse(second.markBootStarted())
        XCTAssertEqual(second.consecutiveCrashCount, 0)
    }

    func testConsecutiveCrashesAccumulate() {
        CrashSentinel(defaults: defaults).markBootStarted() // run 1: starts, crashes
        let run2 = CrashSentinel(defaults: defaults)
        XCTAssertTrue(run2.markBootStarted())               // detects crash 1, marks started, crashes
        XCTAssertEqual(run2.consecutiveCrashCount, 1)
        let run3 = CrashSentinel(defaults: defaults)
        XCTAssertTrue(run3.markBootStarted())               // detects crash 2
        XCTAssertEqual(run3.consecutiveCrashCount, 2)
    }

    func testCleanShutdownResetsConsecutiveCount() {
        CrashSentinel(defaults: defaults).markBootStarted()
        let run2 = CrashSentinel(defaults: defaults)
        run2.markBootStarted()
        XCTAssertEqual(run2.consecutiveCrashCount, 1)
        run2.markCleanShutdown()
        let run3 = CrashSentinel(defaults: defaults)
        XCTAssertFalse(run3.markBootStarted())
        XCTAssertEqual(run3.consecutiveCrashCount, 0)
    }
}
