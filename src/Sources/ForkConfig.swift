import Foundation

/// Fork-specific URLs. Upstream sync should not overwrite this file.
/// See README.md (Maintaining this fork) at the repository root.
enum ForkConfig {
    static let upstreamOwner = "automazeio"
    static let upstreamRepo = "vibeproxy"
    static let forkOwner = "Drjacky"
    static let forkRepo = "vibeproxy"

    static var upstreamRepositoryURL: URL {
        URL(string: "https://github.com/\(upstreamOwner)/\(upstreamRepo)")!
    }

    static var forkRepositoryURL: URL {
        URL(string: "https://github.com/\(forkOwner)/\(forkRepo)")!
    }

    /// Issues for bugs in this fork (e.g. Cursor provider). Upstream bugs: upstream repo issues.
    static var forkIssuesURL: URL {
        forkRepositoryURL.appendingPathComponent("issues")
    }
}
