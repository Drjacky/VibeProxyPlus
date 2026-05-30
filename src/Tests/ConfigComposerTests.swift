import XCTest
@testable import CLIProxyMenuBar

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
}
