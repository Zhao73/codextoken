import XCTest
@testable import CodexTokenCore

final class ClaudeOAuthQuotaProviderTests: XCTestCase {
    func testSnapshotUsesPrimaryAndSecondaryWindows() async throws {
        let credentials = ClaudeOAuthCredentials(accessToken: "sk-test", refreshToken: nil, expiresAt: nil, scopes: [], rateLimitTier: "pro")
        let store = ClaudeOAuthCredentialStore.staticStore(credentials: credentials)

        let response = ClaudeOAuthUsageResponse(
            fiveHour: ClaudeOAuthUsageWindow(utilization: 0.25, resetsAt: "2026-03-18T04:00:00Z"),
            sevenDay: ClaudeOAuthUsageWindow(utilization: 0.60, resetsAt: "2026-03-20T00:00:00Z"),
            sevenDayOpus: nil,
            sevenDaySonnet: nil,
            iguanaNecktie: nil,
            extraUsage: nil
        )
        let fetcher = ClaudeOAuthQuotaProvider.StaticFetcher(response: response)
        let provider = ClaudeOAuthQuotaProvider(credentialStore: store, usageFetcher: fetcher)

        let snapshot = await provider.snapshot(for: makeAccount())

        XCTAssertEqual(snapshot.primaryWindow?.windowDurationMinutes, 300)
        XCTAssertEqual(snapshot.secondaryWindow?.windowDurationMinutes, 10_080)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 25)
        XCTAssertEqual(snapshot.secondaryWindow?.usedPercent, 60)
        XCTAssertTrue(snapshot.warnings.contains("Plan: pro"))
    }

    func testSnapshotUnavailableWhenCredentialsMissing() async throws {
        let store = ClaudeOAuthCredentialStore.staticStore(error: NSError(domain: "missing", code: 1, userInfo: nil))
        let fetcher = ClaudeOAuthQuotaProvider.StaticFetcher(error: NSError(domain: "missing", code: 1, userInfo: nil))
        let provider = ClaudeOAuthQuotaProvider(credentialStore: store, usageFetcher: fetcher)

        let snapshot = await provider.snapshot(for: makeAccount())

        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.sourceLabel, "Claude OAuth")
    }

    private func makeAccount() -> CodexAccount {
        CodexAccount(
            id: "acct",
            storageKey: "acct",
            sourceFile: nil,
            accountID: "acct",
            email: "claude@example.com",
            displayName: "Claude",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )
    }
}
