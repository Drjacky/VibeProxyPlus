import XCTest
@testable import Diagnostics

final class SecretScrubberTests: XCTestCase {
    func testRedactsAnthropicKey() {
        let input = "using key sk-ant-api03-abc123DEF456_-xyz for request"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("sk-ant-api03-abc123DEF456_-xyz"))
        XCTAssertTrue(output.contains(SecretScrubber.redaction))
        XCTAssertTrue(output.hasPrefix("using key "))
        XCTAssertTrue(output.hasSuffix(" for request"))
    }

    func testRedactsProjAndOrAndGskKeys() {
        XCTAssertFalse(SecretScrubber.scrub("sk-proj-aaaaaaaaaaaa").contains("sk-proj-aaaaaaaaaaaa"))
        XCTAssertFalse(SecretScrubber.scrub("sk-or-bbbbbbbbbbbb").contains("sk-or-bbbbbbbbbbbb"))
        XCTAssertFalse(SecretScrubber.scrub("gsk_cccccccccccc").contains("gsk_cccccccccccc"))
    }

    func testRedactsGenericSkKey() {
        let input = "token=sk-0123456789abcdefABCDEF end"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("sk-0123456789abcdefABCDEF"))
        XCTAssertTrue(output.hasSuffix(" end"))
    }

    func testRedactsBearerTokenButKeepsScheme() {
        let input = "Authorization: Bearer abc.def-123_XYZ"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("abc.def-123_XYZ"))
        XCTAssertTrue(output.lowercased().contains("bearer"))
    }

    func testRedactsApiKeyHeaderValue() {
        let input = "x-api-key: deadbeefcafebabe1234"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("deadbeefcafebabe1234"))
        XCTAssertTrue(output.lowercased().contains("x-api-key"))
    }

    func testRedactsApiKeyJSONField() {
        let input = "{\"api_key\":\"supersecretvalue123\"}"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("supersecretvalue123"))
    }

    func testRedactsJWT() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.SflKxwRJSMeKKF2QT4f"
        let output = SecretScrubber.scrub("token: \(jwt)")
        XCTAssertFalse(output.contains(jwt))
    }

    func testRedactsAccessAndRefreshTokens() {
        let input = "{\"access_token\":\"AAA111bbb\",\"refresh_token\":\"CCC222ddd\"}"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("AAA111bbb"))
        XCTAssertFalse(output.contains("CCC222ddd"))
    }

    func testLeavesPlainTextUntouched() {
        let input = "Server started on port 3456 listening at 127.0.0.1"
        XCTAssertEqual(SecretScrubber.scrub(input), input)
    }

    func testRedactsMultipleSecretsInOneLine() {
        let input = "key1 sk-ant-aaaaaaaaaaaa and key2 sk-or-bbbbbbbbbbbb"
        let output = SecretScrubber.scrub(input)
        XCTAssertFalse(output.contains("sk-ant-aaaaaaaaaaaa"))
        XCTAssertFalse(output.contains("sk-or-bbbbbbbbbbbb"))
    }
}
