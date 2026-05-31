import XCTest
@testable import ProcessRuntime

#if canImport(Darwin)
import Darwin
#endif

final class PortAllocatorTests: XCTestCase {
    func testReportsAvailableForLikelyFreePort() {
        // High ephemeral-range ports are normally free; isAvailable should return true.
        XCTAssertTrue(PortAllocator.isAvailable(54321))
    }

    func testReportsUnavailableWhenPortIsHeld() throws {
        #if canImport(Darwin)
        // Bind a listener on an OS-assigned port, then assert the allocator sees it as taken.
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        try XCTSkipIf(fd < 0, "Could not open socket")
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // let the OS choose a free port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        try XCTSkipIf(bindResult != 0, "Could not bind probe socket")
        try XCTSkipIf(listen(fd, 1) != 0, "Could not listen on probe socket")

        // Read back the chosen port.
        var boundAddr = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getResult = withUnsafeMutablePointer(to: &boundAddr) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(fd, sockaddrPointer, &length)
            }
        }
        try XCTSkipIf(getResult != 0, "Could not read bound port")
        let port = UInt16(bigEndian: boundAddr.sin_port)

        XCTAssertFalse(PortAllocator.isAvailable(port), "Port \(port) should be reported as in use")
        #else
        throw XCTSkip("Port checks only validated on Darwin")
        #endif
    }
}
