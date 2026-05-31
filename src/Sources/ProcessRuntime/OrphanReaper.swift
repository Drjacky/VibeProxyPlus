import Foundation
import EngineKit

/// Finds and terminates orphaned engine subprocesses left behind by a previous run or crash.
///
/// Unlike the original broad `pkill -f cli-proxy-api-plus`, reaping is scoped per engine via a
/// unique environment marker so one engine never kills another engine's (or an unrelated)
/// process (see plans/dario-integration-architecture.md, Sections 9, 23, 112). The marker is an
/// environment variable name that a managed process sets; `pgrep -f` matches it in the argument
/// and environment listing.
public struct OrphanReaper {
    /// The environment marker substring identifying processes owned by this engine.
    public let marker: String
    private let runProcess: (String, [String]) -> (status: Int32, output: String)

    /// - Parameters:
    ///   - engineID: The owning engine; forms the default marker.
    ///   - markerOverride: Explicit marker substring. Defaults to a per-engine env var name.
    ///   - runProcess: Injectable command runner for tests. Defaults to a real pgrep/kill runner.
    public init(
        engineID: EngineID,
        markerOverride: String? = nil,
        runProcess: ((String, [String]) -> (status: Int32, output: String))? = nil
    ) {
        self.marker = markerOverride ?? "VIBEPROXY_ENGINE=\(engineID.rawValue)"
        self.runProcess = runProcess ?? OrphanReaper.defaultRunProcess
    }

    /// Returns the PIDs of processes whose command line / environment contains the marker.
    public func findOrphans() -> [Int32] {
        let result = runProcess("/usr/bin/pgrep", ["-f", marker])
        guard result.status == 0 else {
            // pgrep exits non-zero when nothing matches; treat as no orphans.
            return []
        }
        return result.output
            .split(whereSeparator: { $0 == "\n" })
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Force-kills any orphaned processes carrying the marker, excluding `excludingPID`
    /// (typically the engine's current live process). Returns the PIDs that were signalled.
    @discardableResult
    public func reap(excluding excludingPID: Int32? = nil) -> [Int32] {
        let orphans = findOrphans().filter { $0 != excludingPID }
        for pid in orphans {
            kill(pid, SIGKILL)
        }
        return orphans
    }

    private static func defaultRunProcess(_ launchPath: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (task.terminationStatus, output)
        } catch {
            return (-1, "")
        }
    }
}
