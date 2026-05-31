import XCTest
import EngineKit
@testable import ProcessRuntime

final class ManagedProcessTests: XCTestCase {
    func testLaunchAndNaturalExit() async throws {
        let config = ManagedProcessConfiguration(
            executablePath: "/bin/sh",
            arguments: ["-c", "exit 0"]
        )
        let process = ManagedProcess(configuration: config)
        try await process.launch()

        // Allow the short-lived process to finish.
        try await Task.sleep(nanoseconds: 200_000_000)
        let running = await process.isRunning
        XCTAssertFalse(running)
    }

    func testMissingExecutableThrows() async {
        let config = ManagedProcessConfiguration(
            executablePath: "/nonexistent/path/to/binary-\(UUID().uuidString)"
        )
        let process = ManagedProcess(configuration: config)

        do {
            try await process.launch()
            XCTFail("Expected executableNotFound error")
        } catch ProcessError.executableNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTerminateStopsLongRunningProcess() async throws {
        let config = ManagedProcessConfiguration(
            executablePath: "/bin/sh",
            arguments: ["-c", "sleep 30"]
        )
        let process = ManagedProcess(configuration: config)
        try await process.launch()

        let runningBefore = await process.isRunning
        XCTAssertTrue(runningBefore)

        await process.terminate(gracefulTimeout: 1.0)

        let runningAfter = await process.isRunning
        XCTAssertFalse(runningAfter)
    }

    func testTerminateIsIdempotent() async throws {
        let config = ManagedProcessConfiguration(
            executablePath: "/bin/sh",
            arguments: ["-c", "exit 0"]
        )
        let process = ManagedProcess(configuration: config)
        try await process.launch()

        // Terminating twice (and after natural exit) must not crash.
        await process.terminate()
        await process.terminate()

        let running = await process.isRunning
        XCTAssertFalse(running)
    }

    func testCapturesOutputLines() async throws {
        let collected = OutputCollector()
        let config = ManagedProcessConfiguration(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo hello-world"]
        )
        let process = ManagedProcess(configuration: config) { line in
            collected.append(line)
        }
        try await process.launch()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(collected.text().contains("hello-world"))
    }
}

/// Thread-safe accumulator for output captured from a `@Sendable` handler.
private final class OutputCollector: @unchecked Sendable {
    private var buffer = ""
    private let lock = NSLock()

    func append(_ text: String) {
        lock.lock()
        buffer += text
        lock.unlock()
    }

    func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
