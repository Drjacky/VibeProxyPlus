import AppKit

/// Relaunches the application as a fresh process, then terminates the current one.
///
/// A full relaunch is the engine-switch mechanism: it guarantees no engine-specific runtime
/// state survives the transition. The new instance is launched detached so it outlives
/// the terminating process.
@MainActor
enum RelaunchService {
    /// Launches a new instance of this app bundle and terminates the current process.
    ///
    /// - Parameter delay: Grace period before terminating, allowing the new instance to spawn.
    static func relaunch(afterTermination delay: TimeInterval = 0.3) {
        let bundleURL = Bundle.main.bundleURL

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("[RelaunchService] Failed to launch new instance: %@", error.localizedDescription)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.terminate(nil)
            }
        }
    }
}
