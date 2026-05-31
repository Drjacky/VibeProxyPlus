import Cocoa

// main.swift runs on the main thread. AppDelegate is @MainActor-isolated (it drives the
// menu bar, windows, and the active engine), so create it inside an asserted main-actor
// context before handing control to AppKit.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Retain the delegate for the process lifetime (NSApplication holds it weakly).
    objc_setAssociatedObject(app, "vibeproxyplus.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
