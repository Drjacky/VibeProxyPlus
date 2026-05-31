import Cocoa
import SwiftUI
import WebKit
import UserNotifications
import Sparkle
import EngineKit
import CLIProxyEngine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    weak var settingsWindow: NSWindow?

    /// The registry of known engines. The shell registers engines here at boot.
    private let registry = EngineRegistry()
    /// The single active engine for this process lifetime (one engine per launch).
    private var activeEngine: Engine!

    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationPermissionGranted = false
    private let updaterController: SPUStandardUpdaterController
    private var authFileMonitor: DispatchSourceFileSystemObject?
    private var userConfigFileMonitor: DispatchSourceFileSystemObject?
    private var configInputPoller: DispatchSourceTimer?
    private var pendingAuthRefresh: DispatchWorkItem?
    private var polledConfigInputsFingerprint = ""
    
    override init() {
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup standard Edit menu for keyboard shortcuts (Cmd+C/V/X/A)
        setupMainMenu()
        
        // Setup menu bar
        setupMenuBar()

        // Register the known engines and activate the selected one (cliproxyapiplus by default).
        registerEngines()
        activateSelectedEngine()

        // Warm commonly used icons to avoid first-use disk hits
        preloadIcons()
        
        configureNotifications()

        // Start the engine automatically
        startServer()

        // Register for status changes from the active engine
        activeEngine.onStatusChange = { [weak self] in
            self?.updateMenuBarStatus()
        }

        // Monitor auth directory for credential file changes (app-lifetime scope)
        startMonitoringAuthDirectory()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthDirectoryChanged),
            name: .authDirectoryChanged,
            object: nil
        )
    }

    // MARK: - Engine bootstrap

    private func registerEngines() {
        registry.register(CLIProxyEngineImpl.descriptor) { _ in CLIProxyEngineImpl() }
    }

    private func activateSelectedEngine() {
        // Phase 3: a single engine is registered; selection/persistence arrives in Phase 4.
        let engineID = CLIProxyEngineImpl.descriptor.id
        let context = makeEngineContext(for: engineID)
        guard let engine = registry.make(engineID, context: context) else {
            fatalError("No engine registered for id \(engineID)")
        }
        engine.activate(context: context)
        activeEngine = engine
    }

    /// Builds the per-engine context. CLIProxy keeps its legacy `~/.cli-proxy-api` home for
    /// backward compatibility (its home name does not match its engine id).
    private func makeEngineContext(for engineID: EngineID) -> EngineContext {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api", isDirectory: true)
        return EngineContext(
            engineID: engineID,
            homeDirectory: home,
            defaultsSuiteName: "com.github.drjacky.engine.\(engineID.rawValue)",
            keychainServicePrefix: "com.github.drjacky.\(engineID.rawValue)"
        )
    }

    private func preloadIcons() {
        let statusIconSize = NSSize(width: 18, height: 18)
        let serviceIconSize = NSSize(width: 20, height: 20)
        
        let iconsToPreload = [
            ("icon-active.png", statusIconSize),
            ("icon-inactive.png", statusIconSize),
            ("icon-codex.png", serviceIconSize),
            ("icon-claude.png", serviceIconSize),
            ("icon-gemini.png", serviceIconSize)
        ]
        
        for (name, size) in iconsToPreload {
            if IconCatalog.shared.image(named: name, resizedTo: size, template: true) == nil {
                NSLog("[IconPreload] Warning: Failed to preload icon '%@'", name)
            }
        }
    }
    
    private func configureNotifications() {
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                NSLog("[Notifications] Authorization failed: %@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if !granted {
                    NSLog("[Notifications] Authorization not granted; notifications will be suppressed")
                }
            }
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About VibeProxyPlus", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit VibeProxyPlus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit menu (for Cmd+C/V/X/A to work)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.toolTip = "VibeProxyPlus"
            if let icon = IconCatalog.shared.image(named: "icon-inactive.png", resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
            } else {
                let fallback = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "VibeProxyPlus")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load inactive icon from bundle; using fallback system icon")
            }
        }

        menu = NSMenu()

        // Server Status
        menu.addItem(NSMenuItem(title: "Server: Stopped", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Main Actions
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())

        // Server Control
        let startStopItem = NSMenuItem(title: "Start Server", action: #selector(toggleServer), keyEquivalent: "")
        startStopItem.tag = 100
        menu.addItem(startStopItem)

        menu.addItem(NSMenuItem.separator())

        // Copy URL
        let copyURLItem = NSMenuItem(title: "Copy Server URL", action: #selector(copyServerURL), keyEquivalent: "c")
        copyURLItem.isEnabled = false
        copyURLItem.tag = 102
        menu.addItem(copyURLItem)

        // Open Dashboard
        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashboardItem.isEnabled = false
        dashboardItem.tag = 103
        menu.addItem(dashboardItem)

        menu.addItem(NSMenuItem.separator())

        // Check for Updates
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "u")
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }



    @objc func openSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeProxyPlus"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        let contentView = activeEngine.makeSettingsView()
        window.contentView = NSHostingView(rootView: contentView)

        settingsWindow = window
    }
    
    func windowDidClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }

    @objc func toggleServer() {
        if activeEngine.isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    func startServer() {
        activeEngine.start { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.updateMenuBarStatus()
                    self?.showNotification(title: "Server Started", body: "VibeProxyPlus is now running")
                } else {
                    self?.showNotification(title: "Server Failed", body: "Could not start the engine")
                }
            }
        }
    }

    func stopServer() {
        activeEngine.shutdown { [weak self] in
            self?.updateMenuBarStatus()
        }
    }

    @objc func copyServerURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(activeEngine.userVisibleURL.absoluteString, forType: .string)
        showNotification(title: "Copied", body: "Server URL copied to clipboard")
    }

    @objc func openDashboard() {
        if let url = activeEngine.dashboardURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func handleAuthDirectoryChanged() {
        NSLog("[AppDelegate] Auth directory changed notification received — refreshing settings")
        // Re-open settings window if it exists so the user sees the new account
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func updateMenuBarStatus() {
        let isRunning = activeEngine.isRunning

        // Update status items
        if let serverStatus = menu.item(at: 0) {
            serverStatus.title = isRunning ? "Server: Running" : "Server: Stopped"
        }

        // Update button states
        if let startStopItem = menu.item(withTag: 100) {
            startStopItem.title = isRunning ? "Stop Server" : "Start Server"
        }

        if let copyURLItem = menu.item(withTag: 102) {
            copyURLItem.isEnabled = isRunning
        }

        if let dashboardItem = menu.item(withTag: 103) {
            dashboardItem.isEnabled = isRunning
        }

        // Update icon based on server status
        if let button = statusItem.button {
            let iconName = isRunning ? "icon-active.png" : "icon-inactive.png"
            let fallbackSymbol = isRunning ? "network" : "network.slash"
            
            if let icon = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
                NSLog("[MenuBar] Loaded %@ icon from cache", isRunning ? "active" : "inactive")
            } else {
                let fallback = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: isRunning ? "Running" : "Stopped")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load %@ icon; using fallback", isRunning ? "active" : "inactive")
            }
        }
    }

    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "com.github.drjacky.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                NSLog("[Notifications] Failed to deliver notification '%@': %@", title, error.localizedDescription)
            }
        }
    }

    @objc func quit() {
        // Stop engine and wait for cleanup before quitting
        if activeEngine.isRunning {
            activeEngine.shutdown { }
        }
        // Give a moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: .authDirectoryChanged, object: nil)
        pendingAuthRefresh?.cancel()
        authFileMonitor?.cancel()
        authFileMonitor = nil
        // Final cleanup - stop engine if still running
        if activeEngine.isRunning {
            activeEngine.shutdown { }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If engine is running, stop it first
        if activeEngine.isRunning {
            activeEngine.shutdown { }
        }
        return .terminateNow
    }
    
    // MARK: - Auth Directory Monitoring

    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)

        let fileDescriptor = open(authDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.refreshUserConfigFileMonitor()
            self?.pendingAuthRefresh?.cancel()
            let workItem = DispatchWorkItem {
                self?.postObservedConfigInputsChanged(reason: "Auth directory changed")
            }
            self?.pendingAuthRefresh = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        authFileMonitor = source
        refreshUserConfigFileMonitor()
        startPollingConfigInputs()
    }

    private func refreshUserConfigFileMonitor() {
        userConfigFileMonitor?.cancel()
        userConfigFileMonitor = nil

        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")
            .appendingPathComponent("config.yaml")

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return
        }

        let fileDescriptor = open(configURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            if source.data.contains(.delete) || source.data.contains(.rename) {
                self?.refreshUserConfigFileMonitor()
            }
            self?.pendingAuthRefresh?.cancel()
            let workItem = DispatchWorkItem {
                self?.postObservedConfigInputsChanged(reason: "User config changed")
            }
            self?.pendingAuthRefresh = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        userConfigFileMonitor = source
    }

    private func startPollingConfigInputs() {
        configInputPoller?.cancel()
        polledConfigInputsFingerprint = currentConfigInputsFingerprint()

        let poller = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        poller.schedule(deadline: .now() + 1, repeating: 1)
        poller.setEventHandler { [weak self] in
            guard let self else { return }
            let currentFingerprint = self.currentConfigInputsFingerprint()
            guard currentFingerprint != self.polledConfigInputsFingerprint else {
                return
            }
            self.polledConfigInputsFingerprint = currentFingerprint
            self.postObservedConfigInputsChanged(reason: "Config input fingerprint changed during poll")
        }
        poller.resume()
        configInputPoller = poller
    }

    private func postObservedConfigInputsChanged(reason: String) {
        polledConfigInputsFingerprint = currentConfigInputsFingerprint()
        NSLog("[AppDelegate] %@ — posting notification", reason)
        NotificationCenter.default.post(name: .authDirectoryChanged, object: nil)
    }

    private func currentConfigInputsFingerprint() -> String {
        ConfigInputFingerprint.compute(
            in: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api"),
            userConfigFilename: "config.yaml"
        )
    }

    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
