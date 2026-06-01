import Foundation
import EngineKit

#if canImport(Darwin)
import Darwin
#endif

/// Checks availability of localhost TCP ports for engine subprocesses.
///
/// Engines bind to `127.0.0.1` only. Before launching, an engine asks the allocator whether its
/// declared port is free; if a foreign
/// process holds it, startup fails loudly rather than silently colliding.
public enum PortAllocator {
    /// Returns true if the given TCP port can currently be bound on 127.0.0.1.
    ///
    /// Works by attempting to bind a transient socket to the loopback address. The probe socket
    /// is always closed before returning, so this does not leak descriptors or hold the port.
    public static func isAvailable(_ port: UInt16) -> Bool {
        #if canImport(Darwin)
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Do NOT set SO_REUSEADDR: we want the bind to fail if the port is genuinely in use.
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
        #else
        return true
        #endif
    }
}
