// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLIProxyMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CLIProxyMenuBar",
            targets: ["CLIProxyMenuBar"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.3")
    ],
    targets: [
        // MARK: - Shared foundation (engine-agnostic)

        // Engine contracts and lifecycle abstractions. Foundation only.
        .target(
            name: "EngineKit",
            path: "Sources/EngineKit"
        ),
        // Engine-neutral UI (theme, chrome, switch dialog, generic controls).
        .target(
            name: "SharedUI",
            dependencies: ["EngineKit"],
            path: "Sources/SharedUI"
        ),
        // Namespaced storage (defaults suites, Keychain, per-engine dotfolders).
        .target(
            name: "Persistence",
            dependencies: ["EngineKit"],
            path: "Sources/Persistence"
        ),
        // Subprocess lifecycle primitives (ManagedProcess, ports, orphan reaping).
        .target(
            name: "ProcessRuntime",
            dependencies: ["EngineKit"],
            path: "Sources/ProcessRuntime"
        ),
        // Observability (logs, health, crash, telemetry, diagnostics bundles).
        .target(
            name: "Diagnostics",
            dependencies: ["EngineKit"],
            path: "Sources/Diagnostics"
        ),

        // MARK: - Engine modules (mutually isolated)

        // cliproxyapiplus engine. Must never import DarioEngine.
        .target(
            name: "CLIProxyEngine",
            dependencies: ["EngineKit", "SharedUI", "Persistence", "ProcessRuntime", "Diagnostics"],
            path: "Sources/CLIProxyEngine"
        ),
        // Dario engine. Must never import CLIProxyEngine.
        .target(
            name: "DarioEngine",
            dependencies: ["EngineKit", "SharedUI", "Persistence", "ProcessRuntime", "Diagnostics"],
            path: "Sources/DarioEngine"
        ),

        // MARK: - Application executable

        // Existing menu bar app. In Phase 0 this remains the monolith that owns all
        // current behavior; later phases migrate its code into the modules above and
        // turn this into the thin AppShell that registers both engines.
        .executableTarget(
            name: "CLIProxyMenuBar",
            dependencies: ["Sparkle", "Yams"],
            path: "Sources/CLIProxyMenuBar",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "CLIProxyMenuBarTests",
            dependencies: ["CLIProxyMenuBar"],
            path: "Tests"
        )
    ]
)
