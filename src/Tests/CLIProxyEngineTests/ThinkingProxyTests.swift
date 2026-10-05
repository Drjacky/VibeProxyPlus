import XCTest
import Network
@testable import CLIProxyEngine

final class ThinkingProxyTests: XCTestCase {
    func testLoopbackListenerParametersBindIPv4Loopback() throws {
        let parameters = try XCTUnwrap(ThinkingProxy.loopbackListenerParameters(port: 8317))
        let port = try XCTUnwrap(NWEndpoint.Port(rawValue: 8317))
        XCTAssertEqual(parameters.requiredLocalEndpoint, NWEndpoint.hostPort(host: "127.0.0.1", port: port))
        XCTAssertTrue(parameters.allowLocalEndpointReuse)
    }

    func testLANAccessIsOffByDefault() {
        XCTAssertFalse(ThinkingProxy().allowsLANConnections)
    }
}
