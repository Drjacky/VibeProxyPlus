import XCTest
@testable import CLIProxyEngine

final class CursorTokenImporterTests: XCTestCase {
    func testResolveCredentialFileURLPrefersExistingCursorJson() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cursorJSON = directory.appendingPathComponent("cursor.json")
        try Data("{}".utf8).write(to: cursorJSON)

        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJhdXRoMHx1c2VyX3Rlc3QxMjMiLCJleHAiOjQxMDI0NDQ4MDB9"
        let token = "\(header).\(payload).signature"

        let importer = CursorTokenImporter(
            fileManager: .default,
            authDirectoryURL: directory
        )
        XCTAssertEqual(
            importer.resolveCredentialFileURL(accessToken: token).lastPathComponent,
            "cursor.json"
        )
    }

    func testResolveCredentialFileURLMatchesExistingHashedFileBySub() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJhdXRoMHx1c2VyX3Rlc3QxMjMiLCJleHAiOjQxMDI0NDQ4MDB9"
        let token = "\(header).\(payload).signature"
        let hashedName = CursorJWTHelper.credentialFileName(accessToken: token)

        let hashedURL = directory.appendingPathComponent(hashedName)
        let metadata: [String: Any] = [
            "type": "cursor",
            "sub": "auth0|user_test123",
            "access_token": token,
            "refresh_token": "refresh"
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata)
        try data.write(to: hashedURL)

        let importer = CursorTokenImporter(fileManager: .default, authDirectoryURL: directory)
        XCTAssertEqual(
            importer.resolveCredentialFileURL(accessToken: token).lastPathComponent,
            hashedName
        )
    }
}
