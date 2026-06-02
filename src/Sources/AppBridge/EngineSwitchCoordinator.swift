import AppKit
import EngineKit

/// Orchestrates a full-relaunch engine switch from the shell.
///
/// Flow: present a detailed confirmation dialog -> on confirm, shut the active engine down
/// cleanly -> persist the new
/// selection and mark the switch pending -> relaunch the app, which boots into the new engine.
/// The coordinator lives in the shell and never inside an engine.
@MainActor
final class EngineSwitchCoordinator {
    private let selectionStore: EngineSelectionStore
    private let registry: EngineRegistry

    init(selectionStore: EngineSelectionStore, registry: EngineRegistry) {
        self.selectionStore = selectionStore
        self.registry = registry
    }

    /// Requests a switch from `currentEngine` to the engine identified by `targetID`.
    /// Shows a confirmation dialog; only proceeds if the user confirms.
    func requestSwitch(to targetID: EngineID, from currentEngine: Engine) {
        guard let target = registry.descriptor(for: targetID) else {
            NSLog("[EngineSwitch] No engine registered for id %@", targetID.rawValue)
            return
        }
        let current = currentEngine.descriptor

        let alert = NSAlert()
        alert.messageText = "Switch to \(target.displayName)?"
        alert.informativeText = """
        VibeProxyPlus will switch from \(current.displayName) to \(target.displayName).

        What happens next:
        - The running \(current.displayName) services, proxy, and background processes are stopped cleanly.
        - Pending configuration is flushed and \(current.displayName) state is preserved on disk.
        - VibeProxyPlus relaunches and starts \(target.displayName).
        - \(target.displayName) becomes the engine used on every future launch until you switch back.

        Your \(current.displayName) accounts and settings are kept and will be restored if you switch back.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Switch and Relaunch")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return // user cancelled; engine keeps running untouched
        }

        performSwitch(to: targetID, from: currentEngine)
    }

    /// Shuts the current engine down, persists the selection, and relaunches.
    private func performSwitch(to targetID: EngineID, from currentEngine: Engine) {
        currentEngine.shutdown { [weak self] in
            guard let self else { return }
            // Persist the target selection and mark the switch pending just before relaunch,
            // so the new instance boots into the target and can clear the pending flag.
            self.selectionStore.beginSwitch(to: targetID)
            RelaunchService.relaunch()
        }
    }
}
