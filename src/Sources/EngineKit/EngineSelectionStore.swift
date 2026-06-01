import Foundation

/// Persists which engine the application should boot into, plus switch bookkeeping.
///
/// The selected engine survives launches, upgrades, and reboots. A relaunch generation counter
/// and timestamp guard against relaunch loops when a switch repeatedly fails to come up clean.
public final class EngineSelectionStore {
    private enum Key {
        static let selectedEngine = "shell.selectedEngineID"
        static let switchPending = "shell.switchPending"
        static let lastRelaunchAt = "shell.lastRelaunchAt"
        static let relaunchGeneration = "shell.relaunchGeneration"
    }

    private let defaults: UserDefaults
    private let defaultEngineID: EngineID

    /// - Parameters:
    ///   - defaults: Backing store (standard domain for the shell). Injectable for tests.
    ///   - defaultEngineID: Engine to boot when nothing is persisted yet.
    public init(defaults: UserDefaults = .standard, defaultEngineID: EngineID) {
        self.defaults = defaults
        self.defaultEngineID = defaultEngineID
    }

    /// The engine the app should boot into. Falls back to the default when unset.
    public var selectedEngineID: EngineID {
        guard let raw = defaults.string(forKey: Key.selectedEngine), !raw.isEmpty else {
            return defaultEngineID
        }
        return EngineID(raw)
    }

    /// Whether a switch relaunch is in progress (set just before relaunch, cleared on next boot).
    public var isSwitchPending: Bool {
        defaults.bool(forKey: Key.switchPending)
    }

    /// Monotonic count of relaunches initiated for switching, used for loop detection.
    public var relaunchGeneration: Int {
        defaults.integer(forKey: Key.relaunchGeneration)
    }

    /// Records the target engine and marks a switch as pending. Call immediately before relaunch.
    public func beginSwitch(to engineID: EngineID, now: Date = Date()) {
        defaults.set(engineID.rawValue, forKey: Key.selectedEngine)
        defaults.set(true, forKey: Key.switchPending)
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastRelaunchAt)
        defaults.set(relaunchGeneration + 1, forKey: Key.relaunchGeneration)
    }

    /// Clears the pending flag once the app has booted into the selected engine successfully.
    public func completeSwitch() {
        defaults.set(false, forKey: Key.switchPending)
    }

    /// Returns true if the previous relaunch happened within `window` seconds of `now`, used to
    /// avoid rapid relaunch loops. The caller decides how to respond (for example safe mode).
    public func didRelaunchRecently(within window: TimeInterval, now: Date = Date()) -> Bool {
        let last = defaults.double(forKey: Key.lastRelaunchAt)
        guard last > 0 else { return false }
        return (now.timeIntervalSince1970 - last) < window
    }
}
