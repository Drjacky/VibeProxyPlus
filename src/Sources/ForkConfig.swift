import Foundation

/// Project URLs for this fork. Upstream sync should not overwrite this file.
enum ForkConfig {
    static let owner = "Drjacky"
    static let repo = "vibeproxyplus"

    static var repositoryURL: URL {
        URL(string: "https://github.com/\(owner)/\(repo)")!
    }

    static var issuesURL: URL {
        repositoryURL.appendingPathComponent("issues")
    }

    static var releasesURL: URL {
        repositoryURL.appendingPathComponent("releases")
    }

    static var appcastURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/main/appcast.xml")!
    }

    static var appcastX86URL: URL {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/main/appcast-x86_64.xml")!
    }
}
