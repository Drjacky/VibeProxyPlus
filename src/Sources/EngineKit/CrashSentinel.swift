import Foundation

/// Detects whether the previous application run terminated abnormally (a crash, force-quit, or
/// power loss) so the shell can offer a "safe mode" boot with the engine left stopped.
///
/// The mechanism is a persisted "clean-shutdown" flag. At boot the shell calls
/// `markBootStarted()` which records that a run is in progress. On a clean termination the shell
/// calls `markCleanShutdown()`. If, at the next boot, the in-progress flag is still set, the
/// previous run never reached its clean-shutdown path and is treated as a crash.
public final class CrashSentinel {
    private enum Key {
        static let runInProgress = "shell.runInProgress"
        static let consecutiveCrashes = "shell.consecutiveCrashes"
    }

    private let defaults: UserDefaults

    /// - Parameter defaults: Backing store (standard domain for the shell). Injectable for tests.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Number of consecutive boots that detected an unclean prior shutdown. Reset to zero on the
    /// first clean shutdown. Lets the caller escalate (for example force safe mode) after repeats.
    public var consecutiveCrashCount: Int {
        defaults.integer(forKey: Key.consecutiveCrashes)
    }

    /// Inspects the prior run's state and records that a new run has started.
    ///
    /// Returns `true` when the previous run did not shut down cleanly (the caller should consider
    /// booting into safe mode). Must be called exactly once early in `applicationDidFinishLaunching`.
    @discardableResult
    public func markBootStarted() -> Bool {
        let priorRunCrashed = defaults.bool(forKey: Key.runInProgress)
        if priorRunCrashed {
            defaults.set(consecutiveCrashCount + 1, forKey: Key.consecutiveCrashes)
        }
        defaults.set(true, forKey: Key.runInProgress)
        return priorRunCrashed
    }

    /// Records that the application is shutting down cleanly. Must be called on the normal
    /// termination path so the next boot is not misclassified as a crash.
    public func markCleanShutdown() {
        defaults.set(false, forKey: Key.runInProgress)
        defaults.set(0, forKey: Key.consecutiveCrashes)
    }
}
