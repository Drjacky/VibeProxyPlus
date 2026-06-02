import Cocoa

// The application entry point. `main()` is main-actor-isolated, so the
// @MainActor-isolated AppDelegate (which drives the menu bar, windows, and the
// active engine) can be created directly before handing control to AppKit.
@main
enum AppMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Retain the delegate for the process lifetime (NSApplication holds it weakly).
        objc_setAssociatedObject(app, "vibeproxyplus.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
