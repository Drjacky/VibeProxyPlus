import XCTest
@testable import CLIProxyEngine

final class ConfigComposerTests: XCTestCase {
    func testOverlayPreservesUserAuthoredContent() {
        let runtimeRoot: [String: Any] = [
            "port": 9000,
            "api-keys": ["local-key"],
            "my-secret": "value",
            "custom-section": ["nested": true]
        ]
        let composedRoot: [String: Any] = [
            "port": 8318,
            "oauth-excluded-models": ["claude": ["*"]]
        ]

        let result = ConfigComposer.overlayManagedKeys(onto: runtimeRoot, from: composedRoot)

        // User-authored / hand-edited values are kept verbatim.
        XCTAssertEqual(result["port"] as? Int, 9000)
        XCTAssertEqual(result["api-keys"] as? [String], ["local-key"])
        XCTAssertEqual(result["my-secret"] as? String, "value")
        XCTAssertEqual((result["custom-section"] as? [String: Any])?["nested"] as? Bool, true)
    }

    func testOverlayReplacesComposerManagedKeys() {
        let runtimeRoot: [String: Any] = [
            "oauth-excluded-models": ["gemini": ["*"]],
            "openai-compatibility": [["name": "old"]]
        ]
        let composedRoot: [String: Any] = [
            "oauth-excluded-models": ["claude": ["*"]],
            "openai-compatibility": [["name": "new"]]
        ]

        let result = ConfigComposer.overlayManagedKeys(onto: runtimeRoot, from: composedRoot)

        let exclusions = result["oauth-excluded-models"] as? [String: Any]
        XCTAssertNotNil(exclusions?["claude"])
        XCTAssertNil(exclusions?["gemini"])

        let providers = result["openai-compatibility"] as? [[String: Any]]
        XCTAssertEqual(providers?.first?["name"] as? String, "new")
    }

    func testOverlayRemovesManagedKeyWhenComposerOmitsIt() {
        let runtimeRoot: [String: Any] = [
            "oauth-excluded-models": ["gemini": ["*"]],
            "openai-compatibility": [["name": "old"]],
            "keep-me": true
        ]
        let composedRoot: [String: Any] = ["keep-me": true]

        let result = ConfigComposer.overlayManagedKeys(onto: runtimeRoot, from: composedRoot)

        XCTAssertNil(result["oauth-excluded-models"])
        XCTAssertNil(result["openai-compatibility"])
        XCTAssertEqual(result["keep-me"] as? Bool, true)
    }

    private let bundledClaudeHeaders: [String: Any] = [
        "claude-header-defaults": [
            "user-agent": "claude-cli/2.1.280 (external, cli)",
            "package-version": "0.112.1",
            "runtime-version": "v26.3.0"
        ]
    ]

    func testClaudeHeaderBaselineCopiedWhenMissing() {
        let result = ConfigComposer.raiseClaudeHeaderBaseline(onto: ["port": 8318], from: bundledClaudeHeaders)
        let headers = result["claude-header-defaults"] as? [String: Any]
        XCTAssertEqual(headers?["user-agent"] as? String, "claude-cli/2.1.280 (external, cli)")
        XCTAssertEqual(headers?["package-version"] as? String, "0.112.1")
        XCTAssertEqual(result["port"] as? Int, 8318)
    }

    func testClaudeHeaderBaselineRaisesOlderUserAgentAndKeepsOtherKeys() {
        let runtimeRoot: [String: Any] = [
            "claude-header-defaults": [
                "user-agent": "claude-cli/2.1.258 (external, cli)",
                "timezone": "Europe/London"
            ]
        ]
        let result = ConfigComposer.raiseClaudeHeaderBaseline(onto: runtimeRoot, from: bundledClaudeHeaders)
        let headers = result["claude-header-defaults"] as? [String: Any]
        XCTAssertEqual(headers?["user-agent"] as? String, "claude-cli/2.1.280 (external, cli)")
        XCTAssertEqual(headers?["timezone"] as? String, "Europe/London")
        XCTAssertEqual(headers?["runtime-version"] as? String, "v26.3.0")
    }

    func testClaudeHeaderBaselineKeepsNewerUserAgent() {
        let runtimeRoot: [String: Any] = [
            "claude-header-defaults": ["user-agent": "claude-cli/2.1.300 (external, cli)"]
        ]
        let result = ConfigComposer.raiseClaudeHeaderBaseline(onto: runtimeRoot, from: bundledClaudeHeaders)
        let headers = result["claude-header-defaults"] as? [String: Any]
        XCTAssertEqual(headers?["user-agent"] as? String, "claude-cli/2.1.300 (external, cli)")
        XCTAssertNil(headers?["package-version"])
    }

    func testClaudeCLIVersionParsing() {
        XCTAssertEqual(ConfigComposer.claudeCLIVersion(from: "claude-cli/2.1.280 (external, cli)"), [2, 1, 280])
        XCTAssertNil(ConfigComposer.claudeCLIVersion(from: "curl/8.0"))
        XCTAssertNil(ConfigComposer.claudeCLIVersion(from: "claude-cli/2.1"))
    }
}
