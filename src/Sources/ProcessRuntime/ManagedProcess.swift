import Foundation
import EngineKit

/// Errors surfaced by `ManagedProcess`.
public enum ProcessError: Error {
    /// The executable does not exist at the configured path.
    case executableNotFound(String)
    /// The process is already running and cannot be launched again.
    case alreadyRunning
    /// Launching the underlying `Process` failed.
    case launchFailed(String)
}

/// Configuration for launching a managed subprocess.
public struct ManagedProcessConfiguration: Sendable {
    /// Absolute path to the executable.
    public var executablePath: String
    /// Command-line arguments.
    public var arguments: [String]
    /// Environment for the child. Defaults to an empty environment; callers opt in to what
    /// the child needs rather than inheriting the full parent environment.
    public var environment: [String: String]
    /// Optional working directory.
    public var currentDirectoryPath: String?

    public init(
        executablePath: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryPath: String? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryPath = currentDirectoryPath
    }
}

/// A hardened wrapper around `Process` with single-owner semantics, async lifecycle, and
/// deterministic teardown.
///
/// Extracted and generalized from the original ServerManager subprocess handling
/// (see plans/dario-integration-architecture.md, Sections 9, 48, 51). Output pipe handlers are
/// always cleared on termination to avoid the readability-handler leak the original code guarded
/// against, and stop uses SIGTERM with a timeout before falling back to SIGKILL.
public actor ManagedProcess {
    private let configuration: ManagedProcessConfiguration
    private let onOutputLine: (@Sendable (String) -> Void)?

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    public init(
        configuration: ManagedProcessConfiguration,
        onOutputLine: (@Sendable (String) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.onOutputLine = onOutputLine
    }

    /// Whether the managed process is currently running.
    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// The OS process identifier, or nil if not running.
    public var processIdentifier: Int32? {
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    /// Launches the subprocess. Throws if the executable is missing or already running.
    public func launch() throws {
        guard process == nil || !(process?.isRunning ?? false) else {
            throw ProcessError.alreadyRunning
        }
        guard FileManager.default.fileExists(atPath: configuration.executablePath) else {
            throw ProcessError.executableNotFound(configuration.executablePath)
        }

        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: configuration.executablePath)
        newProcess.arguments = configuration.arguments
        newProcess.environment = configuration.environment
        if let cwd = configuration.currentDirectoryPath {
            newProcess.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        newProcess.standardOutput = stdoutPipe
        newProcess.standardError = stderrPipe

        if let onOutputLine {
            let handler: @Sendable (FileHandle) -> Void = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                onOutputLine(text)
            }
            stdoutPipe.fileHandleForReading.readabilityHandler = handler
            stderrPipe.fileHandleForReading.readabilityHandler = handler
        }

        do {
            try newProcess.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ProcessError.launchFailed(error.localizedDescription)
        }

        self.process = newProcess
        self.outputPipe = stdoutPipe
        self.errorPipe = stderrPipe
    }

    /// Stops the subprocess: SIGTERM, wait up to `gracefulTimeout`, then SIGKILL if needed.
    /// Always clears pipe handlers and releases the process reference. Idempotent.
    public func terminate(gracefulTimeout: TimeInterval = 2.0, pollInterval: TimeInterval = 0.05) {
        guard let process else {
            clearPipes()
            return
        }

        if process.isRunning {
            let pid = process.processIdentifier
            process.terminate()

            let deadline = Date().addingTimeInterval(gracefulTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: pollInterval)
            }

            if process.isRunning {
                kill(pid, SIGKILL)
            }
            process.waitUntilExit()
        }

        clearPipes()
        self.process = nil
    }

    /// The exit status of the most recent run, or nil while running or before first launch.
    public func terminationStatus() -> Int32? {
        guard let process, !process.isRunning else { return nil }
        return process.terminationStatus
    }

    private func clearPipes() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
    }
}
