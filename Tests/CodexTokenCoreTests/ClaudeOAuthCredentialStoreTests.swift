import XCTest
@testable import CodexTokenCore

final class ClaudeOAuthCredentialStoreTests: XCTestCase {
    func testLoadCredentialsFromJson() throws {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "sk-test",
            "refreshToken": "rt-test",
            "expiresAt": 1710000000000,
            "scopes": ["user:profile", "user:inference"],
            "rateLimitTier": "max"
          }
        }
        """
        let reader = ClaudeOAuthCredentialStore.StaticReader(data: Data(json.utf8))
        let store = ClaudeOAuthCredentialStore(reader: reader)

        let credentials = try store.load()

        XCTAssertEqual(credentials.accessToken, "sk-test")
        XCTAssertEqual(credentials.refreshToken, "rt-test")
        XCTAssertEqual(credentials.scopes, ["user:profile", "user:inference"])
        XCTAssertEqual(credentials.rateLimitTier, "max")
        XCTAssertEqual(credentials.expiresAt?.timeIntervalSince1970, 1710000000)
    }

    func testLoadCredentialsThrowsWhenDataMissing() {
        let reader = ClaudeOAuthCredentialStore.StaticReader(error: NSError(domain: "test", code: 1, userInfo: nil))
        let store = ClaudeOAuthCredentialStore(reader: reader)

        XCTAssertThrowsError(try store.load())
    }

    func testStaticStoreHelper() throws {
        let credentials = ClaudeOAuthCredentials(
            accessToken: "sk-test",
            refreshToken: nil,
            expiresAt: nil,
            scopes: [],
            rateLimitTier: "pro"
        )
        let store = ClaudeOAuthCredentialStore.staticStore(credentials: credentials)
        let loaded = try store.load()
        XCTAssertEqual(loaded.accessToken, "sk-test")
        XCTAssertEqual(loaded.rateLimitTier, "pro")
    }
}
