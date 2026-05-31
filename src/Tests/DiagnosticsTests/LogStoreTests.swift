import XCTest
@testable import Diagnostics

final class LogStoreTests: XCTestCase {
    func testAppendRetainsLinesInOrder() {
        let store = LogStore(scope: "test", capacity: 10)
        store.append("first")
        store.append("second")

        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertTrue(snapshot[0].hasSuffix("first"))
        XCTAssertTrue(snapshot[1].hasSuffix("second"))
    }

    func testCapacityEvictsOldestLines() {
        let store = LogStore(scope: "test", capacity: 3)
        for index in 1...5 {
            store.append("line\(index)")
        }

        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertTrue(snapshot[0].hasSuffix("line3"))
        XCTAssertTrue(snapshot[1].hasSuffix("line4"))
        XCTAssertTrue(snapshot[2].hasSuffix("line5"))
    }

    func testClearEmptiesBuffer() {
        let store = LogStore(scope: "test", capacity: 5)
        store.append("a")
        store.append("b")
        store.clear()

        XCTAssertEqual(store.snapshot().count, 0)
    }

    func testLineIncludesScopedTimestampPrefix() {
        let store = LogStore(scope: "engineX", capacity: 5)
        store.append("hello")

        let line = store.snapshot().first ?? ""
        // Line format is "[<timestamp>] <message>".
        XCTAssertTrue(line.hasPrefix("["))
        XCTAssertTrue(line.contains("] hello"))
    }

    func testOnUpdateFiresWithSnapshot() {
        let store = LogStore(scope: "test", capacity: 5)
        let expectation = expectation(description: "onUpdate called")
        var received: [String] = []
        store.onUpdate = { lines in
            received = lines
            expectation.fulfill()
        }

        store.append("notify")
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received[0].hasSuffix("notify"))
    }
}
