import XCTest
import EngineKit
@testable import ProcessRuntime

final class OrphanReaperTests: XCTestCase {
    func testMarkerDerivedFromEngineID() {
        let reaper = OrphanReaper(engineID: "dario")
        XCTAssertEqual(reaper.marker, "VIBEPROXY_ENGINE=dario")
    }

    func testEnginesHaveDistinctMarkers() {
        let cliproxy = OrphanReaper(engineID: "cliproxyapiplus")
        let dario = OrphanReaper(engineID: "dario")
        XCTAssertNotEqual(cliproxy.marker, dario.marker)
    }

    func testFindOrphansParsesPgrepOutput() {
        let reaper = OrphanReaper(engineID: "dario") { _, _ in
            (status: 0, output: "1234\n5678\n")
        }
        XCTAssertEqual(reaper.findOrphans(), [1234, 5678])
    }

    func testFindOrphansEmptyWhenPgrepFails() {
        // pgrep exits non-zero when no process matches.
        let reaper = OrphanReaper(engineID: "dario") { _, _ in
            (status: 1, output: "")
        }
        XCTAssertEqual(reaper.findOrphans(), [])
    }

    func testFindOrphansIgnoresMalformedLines() {
        let reaper = OrphanReaper(engineID: "dario") { _, _ in
            (status: 0, output: "1234\nnot-a-pid\n  5678  \n")
        }
        XCTAssertEqual(reaper.findOrphans(), [1234, 5678])
    }

    func testReapExcludesLivePID() {
        // reap() must never signal the engine's current process. Use an unused-but-valid PID
        // value for the orphan and verify the live PID is excluded from the returned set.
        // We avoid actually killing a real process by checking exclusion logic via findOrphans.
        let reaper = OrphanReaper(engineID: "dario") { _, _ in
            (status: 0, output: "99999999\n") // implausible PID; kill is a no-op
        }
        let reaped = reaper.reap(excluding: 99999999)
        XCTAssertTrue(reaped.isEmpty, "The excluded PID must not be reaped")
    }
}
