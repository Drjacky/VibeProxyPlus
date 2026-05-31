import XCTest
import EngineKit
@testable import Persistence

final class EngineDirectoryLayoutTests: XCTestCase {
    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("layout-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempBase)
    }

    func testHomeUsesProvidedDotfolderName() {
        let layout = EngineDirectoryLayout(
            engineID: "dario",
            homeDirectoryName: ".dario",
            baseDirectory: tempBase
        )
        XCTAssertEqual(layout.home.lastPathComponent, ".dario")
        XCTAssertEqual(layout.home.deletingLastPathComponent().path, tempBase.path)
    }

    func testCliproxyKeepsLegacyDotfolderIndependentOfEngineID() {
        // The cliproxy engine id does not match its legacy directory; the layout honors the
        // explicit name so backward compatibility with ~/.cli-proxy-api is preserved.
        let layout = EngineDirectoryLayout(
            engineID: "cliproxyapiplus",
            homeDirectoryName: ".cli-proxy-api",
            baseDirectory: tempBase
        )
        XCTAssertEqual(layout.home.lastPathComponent, ".cli-proxy-api")
    }

    func testStandardSubdirectories() {
        let layout = EngineDirectoryLayout(
            engineID: "dario",
            homeDirectoryName: ".dario",
            baseDirectory: tempBase
        )
        XCTAssertEqual(layout.logs.lastPathComponent, "logs")
        XCTAssertEqual(layout.cache.lastPathComponent, "cache")
        XCTAssertEqual(layout.temp.lastPathComponent, "tmp")
        XCTAssertEqual(layout.logs.deletingLastPathComponent().path, layout.home.path)
    }

    func testEnsureCreatesDirectories() throws {
        let layout = EngineDirectoryLayout(
            engineID: "dario",
            homeDirectoryName: ".dario",
            baseDirectory: tempBase
        )
        try layout.ensureHome()
        try layout.ensure(layout.logs)

        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.home.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.logs.path))
    }

    func testTwoEnginesGetDistinctHomes() {
        let cliproxy = EngineDirectoryLayout(
            engineID: "cliproxyapiplus",
            homeDirectoryName: ".cli-proxy-api",
            baseDirectory: tempBase
        )
        let dario = EngineDirectoryLayout(
            engineID: "dario",
            homeDirectoryName: ".dario",
            baseDirectory: tempBase
        )
        XCTAssertNotEqual(cliproxy.home.path, dario.home.path)
    }
}
