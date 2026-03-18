import XCTest
@testable import CodexTokenCore

final class LocalStateQuotaProviderTests: XCTestCase {
    func testExperimentalQuotaProviderUsesStandardErrorPayloadWhenStandardOutputIsEmpty() async throws {
        let account = CodexAccount(
            id: "acct-experimental",
            storageKey: "acct-experimental",
            sourceFile: nil,
            accountID: "acct-experimental",
            displayName: "Experimental",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )

        let provider = ExperimentalQuotaProvider(
            configuration: ExperimentalQuotaConfiguration(shellCommand: "mock"),
            commandRunner: StubShellCommandRunner(
                result: ShellCommandResult(
                    standardOutput: "",
                    standardError: """
                    {
                      "status": "available",
                      "value": 73,
                      "unit": "percent",
                      "sourceLabel": "stderr payload",
                      "confidence": "medium",
                      "warnings": []
                    }
                    """,
                    exitCode: 0
                )
            )
        )

        let snapshot = await provider.snapshot(for: account)

        XCTAssertEqual(snapshot.status, .available)
        XCTAssertEqual(snapshot.value, 73)
        XCTAssertEqual(snapshot.unit, "percent")
        XCTAssertEqual(snapshot.sourceLabel, "stderr payload")
        XCTAssertEqual(snapshot.confidence, .medium)
        XCTAssertNil(snapshot.errorDescription)
    }

    func testLocalStateProviderReturnsUnknownQuotaWithStableMetadata() async throws {
        let account = CodexAccount(
            id: "acct-main",
            storageKey: "acct-main",
            sourceFile: URL(fileURLWithPath: "/mock/.codex/accounts/acct-main.json"),
            accountID: "acct-main",
            displayName: "Main",
            remark: "Personal",
            authMode: .chatGPT,
            lastRefreshAt: ISO8601DateFormatter().date(from: "2026-03-09T10:00:00Z"),
            isActiveCLI: true,
            isImportedFromActiveSession: false
        )

        let snapshot = await LocalStateQuotaProvider().snapshot(for: account)

        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.sourceLabel, "Local Codex state")
        XCTAssertEqual(snapshot.confidence, .high)
        XCTAssertEqual(snapshot.refreshedAt, account.lastRefreshAt)
        XCTAssertTrue(snapshot.warnings.contains("No official quota source configured."))
    }

    func testCompositeQuotaProviderFallsBackToLocalProvider() async throws {
        let account = CodexAccount(
            id: "acct-main",
            storageKey: "acct-main",
            sourceFile: nil,
            accountID: "acct-main",
            displayName: "Main",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )

        let composite = CompositeQuotaProvider(
            primary: ExperimentalQuotaProvider(configuration: .disabled),
            fallback: LocalStateQuotaProvider()
        )

        let snapshot = await composite.snapshot(for: account)

        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.sourceLabel, "Local Codex state")
    }
}

private struct StubShellCommandRunner: ShellCommandRunning {
    let result: ShellCommandResult

    func run(shellCommand: String) throws -> ShellCommandResult {
        result
    }
}
