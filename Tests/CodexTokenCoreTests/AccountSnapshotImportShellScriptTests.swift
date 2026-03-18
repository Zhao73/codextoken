import XCTest
@testable import CodexTokenCore

final class AccountSnapshotImportShellScriptTests: XCTestCase {
    func testCurrentSessionImportShellScriptCopiesActiveAuthIntoAccountsDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let codexDirectory = root.appendingPathComponent(".codex", isDirectory: true)
        try fileManager.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let authFile = codexDirectory.appendingPathComponent("auth.json")
        try authFixture(accountID: "acct-login").data(using: .utf8)?.write(to: authFile)

        let service = AccountSnapshotImportService(paths: CodexPaths(baseDirectory: codexDirectory))
        let shellScript = service.makeCurrentSessionImportShellScript()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", shellScript]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(
            process.terminationStatus,
            0,
            String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )

        let snapshotURL = codexDirectory
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent("acct-login.json")
        XCTAssertTrue(fileManager.fileExists(atPath: snapshotURL.path))

        let copied = try Data(contentsOf: snapshotURL)
        XCTAssertTrue(String(decoding: copied, as: UTF8.self).contains("\"account_id\": \"acct-login\""))
    }
}

private func authFixture(accountID: String) -> String {
    """
    {
      "OPENAI_API_KEY": null,
      "auth_mode": "chatgpt",
      "last_refresh": "2026-03-09T08:00:00Z",
      "tokens": {
        "access_token": "access-\(accountID)",
        "account_id": "\(accountID)",
        "id_token": "id-\(accountID)",
        "refresh_token": "refresh-\(accountID)"
      }
    }
    """
}
