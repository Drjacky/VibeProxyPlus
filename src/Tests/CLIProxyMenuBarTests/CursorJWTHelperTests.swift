import XCTest
@testable import CLIProxyMenuBar

final class CursorJWTHelperTests: XCTestCase {
    func testSubjectAndExpiryFromJWT() {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJhdXRoMHx1c2VyX3Rlc3QxMjMiLCJleHAiOjQxMDI0NDQ4MDB9"
        let token = "\(header).\(payload).signature"

        XCTAssertEqual(CursorJWTHelper.subject(token), "auth0|user_test123")
        XCTAssertEqual(CursorJWTHelper.subjectFileHash(token).count, 8)

        let expiry = CursorJWTHelper.expiryDate(accessToken: token, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(expiry.timeIntervalSince1970, 4_102_444_800 - 300, accuracy: 1)
    }

    func testCredentialFileNameUsesSubHash() {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJhdXRoMHx1c2VyX3Rlc3QxMjMiLCJleHAiOjQxMDI0NDQ4MDB9"
        let token = "\(header).\(payload).signature"

        let fileName = CursorJWTHelper.credentialFileName(accessToken: token)
        XCTAssertTrue(fileName.hasPrefix("cursor."))
        XCTAssertTrue(fileName.hasSuffix(".json"))
        XCTAssertNotEqual(fileName, "cursor.json")
    }

    func testCredentialFileNameFallback() {
        XCTAssertEqual(CursorJWTHelper.credentialFileName(accessToken: "not-a-jwt"), "cursor.json")
    }
}
