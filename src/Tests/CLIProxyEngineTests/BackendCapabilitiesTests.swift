import XCTest
@testable import CLIProxyEngine

final class BackendCapabilitiesTests: XCTestCase {
    /// Trimmed from the real `cli-proxy-api-plus --help` output of the bundled
    /// CLIProxyAPIPlus 7.3.12-1 backend, which has no `-qwen-login` flag.
    private static let plusHelpFixture = """
        CLIProxyAPI Version: 7.3.12-1-plus, Commit: 04048d86, BuiltAt: 2026-09-23T00:19:28Z
        Usage of /Applications/VibeProxyPlus.app/Contents/Resources/cli-proxy-api-plus
          -antigravity-login
            Login to Antigravity using OAuth
          -claude-login
            Login to Claude using OAuth
          -codex-login
            Login to Codex using OAuth
          -config string
            Configure File Path
          -cursor-login
            Login to Cursor using OAuth
          -github-copilot-login
            Login to GitHub Copilot using device flow
          -kimi-login
            Login to Kimi (.com) using OAuth
          -login
            Login Google Account
        """

    func testParsesFlagsFromBundledHelpOutput() {
        let capabilities = BackendCapabilities(helpOutput: Self.plusHelpFixture)

        XCTAssertEqual(capabilities.definedFlags, [
            "antigravity-login", "claude-login", "codex-login", "config", "cursor-login",
            "github-copilot-login", "kimi-login", "login"
        ])
    }

    func testBundledBackendLacksQwenLogin() {
        let capabilities = BackendCapabilities(helpOutput: Self.plusHelpFixture)

        XCTAssertTrue(capabilities.defines(flag: AuthCommand.geminiLogin.requiredBackendFlag))
        XCTAssertTrue(capabilities.defines(flag: AuthCommand.cursorLogin.requiredBackendFlag))
        XCTAssertFalse(capabilities.defines(flag: AuthCommand.qwenLogin(email: "user@example.com").requiredBackendFlag))
    }

    func testIgnoresProseLinesInHelpOutput() {
        let capabilities = BackendCapabilities(
            helpOutput: "CLIProxyAPI Version: 7.3.12-1-plus\nUsage of /tmp/cli-proxy-api-plus"
        )

        XCTAssertTrue(capabilities.definedFlags.isEmpty)
    }

    func testEmptyHelpYieldsNoFlags() {
        XCTAssertTrue(BackendCapabilities(helpOutput: "").definedFlags.isEmpty)
    }
}

final class AuthCommandFlagMappingTests: XCTestCase {
    func testRequiredBackendFlags() {
        XCTAssertEqual(AuthCommand.claudeLogin.requiredBackendFlag, "claude-login")
        XCTAssertEqual(AuthCommand.codexLogin.requiredBackendFlag, "codex-login")
        XCTAssertEqual(AuthCommand.copilotLogin.requiredBackendFlag, "github-copilot-login")
        XCTAssertEqual(AuthCommand.geminiLogin.requiredBackendFlag, "login")
        XCTAssertEqual(AuthCommand.kimiLogin.requiredBackendFlag, "kimi-login")
        XCTAssertEqual(AuthCommand.qwenLogin(email: "user@example.com").requiredBackendFlag, "qwen-login")
        XCTAssertEqual(AuthCommand.antigravityLogin.requiredBackendFlag, "antigravity-login")
        XCTAssertEqual(AuthCommand.cursorLogin.requiredBackendFlag, "cursor-login")
    }

    func testDisplayNames() {
        XCTAssertEqual(AuthCommand.copilotLogin.displayName, "GitHub Copilot")
        XCTAssertEqual(AuthCommand.qwenLogin(email: "user@example.com").displayName, "Qwen")
    }
}
