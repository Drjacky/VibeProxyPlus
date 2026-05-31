import XCTest
@testable import EngineKit

final class EngineIDTests: XCTestCase {
    func testRawValueRoundTrip() {
        let id = EngineID(rawValue: "dario")
        XCTAssertEqual(id.rawValue, "dario")
        XCTAssertEqual(id.description, "dario")
    }

    func testStringLiteralInitialization() {
        let id: EngineID = "cliproxyapiplus"
        XCTAssertEqual(id.rawValue, "cliproxyapiplus")
    }

    func testEquatableAndHashable() {
        let a: EngineID = "dario"
        let b = EngineID("dario")
        let c: EngineID = "cliproxyapiplus"

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(Set([a, b, c]).count, 2)
    }

    func testCodableRoundTrip() throws {
        let id: EngineID = "dario"
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(EngineID.self, from: data)
        XCTAssertEqual(decoded, id)
    }
}
