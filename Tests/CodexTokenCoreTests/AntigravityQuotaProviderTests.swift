import XCTest
@testable import CodexTokenCore

final class AntigravityQuotaProviderTests: XCTestCase {
    func testMapsPriorityModelsToWindows() async throws {
        let processRunner = StubProcessRunner(
            psOutput: " 1234 /usr/bin/language_server_macos --app_data_dir antigravity --csrf_token tok123 --extension_server_port 4321",
            lsofOutput: ":2025 (LISTEN)"
        )
        let httpClient = StubHTTPClient(responses: [
            "/exa.language_server_pb.LanguageServerService/GetUnleashData": "{}",
            "/exa.language_server_pb.LanguageServerService/GetUserStatus": "{\n  \"modelQuotas\": [\n    {\"label\": \"Claude\", \"remainingFraction\": 0.68, \"resetTime\": \"2026-03-17T12:00:00Z\"},\n    {\"label\": \"Gemini Pro Low\", \"remainingFraction\": 0.32, \"resetTime\": \"2026-03-18T08:00:00Z\"},\n    {\"label\": \"Other\", \"remainingFraction\": 0.9, \"resetTime\": \"2026-03-19T07:00:00Z\"}\n  ],\n  \"plan\": \"Pro\"\n}"
        ])
        let provider = AntigravityQuotaProvider(
            processRunner: processRunner,
            lsofRunner: processRunner,
            httpClient: httpClient
        )

        let account = CodexAccount(
            id: "acct",
            storageKey: "acct",
            sourceFile: nil,
            accountID: "acct",
            displayName: "acct",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )

        let snapshot = await provider.snapshot(for: account)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 32)
        XCTAssertEqual(snapshot.secondaryWindow?.usedPercent, 68)
        XCTAssertTrue(snapshot.warnings.contains("Plan: Pro"))
    }

    func testFallsBackToCommandModelConfigs() async throws {
        let processRunner = StubProcessRunner(
            psOutput: " 4321 /usr/bin/language_server_macos --csrf_token tk --extension_server_port 1111",
            lsofOutput: ":3030 (LISTEN)"
        )
        let httpClient = StubHTTPClient(responses: [
            "/exa.language_server_pb.LanguageServerService/GetUnleashData": "{}",
            "/exa.language_server_pb.LanguageServerService/GetUserStatus": nil,
            "/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs": "{\n  \"modelQuotas\": [\n    {\"label\": \"Gemini Flash\", \"remainingFraction\": 0.5, \"resetTime\": \"2026-03-20T05:00:00Z\"}\n  ]\n}"
        ])
        let provider = AntigravityQuotaProvider(
            processRunner: processRunner,
            lsofRunner: processRunner,
            httpClient: httpClient
        )

        let account = CodexAccount(
            id: "other",
            storageKey: "other",
            sourceFile: nil,
            accountID: "other",
            displayName: "other",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )

        let snapshot = await provider.snapshot(for: account)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 50)
        XCTAssertNil(snapshot.secondaryWindow)
    }

    func testModelsSnapshotExposesOrderedModelsAndCreditsFromUserStatus() async throws {
        let processRunner = StubProcessRunner(
            psOutput: " 4444 /usr/bin/language_server_macos --app_data_dir antigravity --csrf_token tok456 --extension_server_port 6000",
            lsofOutput: ":4040 (LISTEN)"
        )
        let httpClient = StubHTTPClient(responses: [
            "/exa.language_server_pb.LanguageServerService/GetUnleashData": "{}",
            "/exa.language_server_pb.LanguageServerService/GetUserStatus": """
            {
              "userStatus": {
                "name": "Jane",
                "email": "jane@example.com",
                "planStatus": {
                  "planInfo": {
                    "planName": "Pro",
                    "monthlyPromptCredits": 50000,
                    "monthlyFlowCredits": "150000",
                    "monthlyFlexCreditPurchaseAmount": "25000",
                    "canBuyMoreCredits": true
                  },
                  "availablePromptCredits": 500,
                  "availableFlowCredits": "100"
                },
                "cascadeModelConfigData": {
                  "clientModelConfigs": [
                    {
                      "label": "Claude Sonnet 4.6 (Thinking)",
                      "isRecommended": true,
                      "quotaInfo": {
                        "remainingFraction": 0.75,
                        "resetTime": "2026-03-17T16:24:42Z"
                      }
                    },
                    {
                      "label": "Gemini 3.1 Pro (High)",
                      "isRecommended": true,
                      "tagTitle": "New",
                      "quotaInfo": {
                        "remainingFraction": 0.5,
                        "resetTime": "1742230800"
                      }
                    },
                    {
                      "label": "GPT-OSS 120B (Medium)",
                      "quotaInfo": {
                        "remainingFraction": 0.95,
                        "resetTime": "2026-03-17T16:24:42Z"
                      }
                    }
                  ],
                  "clientModelSorts": [
                    {
                      "name": "Recommended",
                      "groups": [
                        {
                          "modelLabels": [
                            "Gemini 3.1 Pro (High)",
                            "Claude Sonnet 4.6 (Thinking)",
                            "GPT-OSS 120B (Medium)"
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            }
            """
        ])
        let provider = AntigravityQuotaProvider(
            processRunner: processRunner,
            lsofRunner: processRunner,
            httpClient: httpClient
        )

        let account = CodexAccount(
            id: "detail",
            storageKey: "detail",
            sourceFile: nil,
            accountID: "detail",
            displayName: "detail",
            remark: nil,
            authMode: .chatGPT,
            lastRefreshAt: nil,
            isActiveCLI: false,
            isImportedFromActiveSession: false
        )

        let snapshot = await provider.modelsSnapshot(for: account)
        XCTAssertEqual(snapshot.planName, "Pro")
        XCTAssertEqual(snapshot.accountEmail, "jane@example.com")
        XCTAssertEqual(snapshot.modelQuotas.map(\.label), [
            "Gemini 3.1 Pro (High)",
            "Claude Sonnet 4.6 (Thinking)",
            "GPT-OSS 120B (Medium)"
        ])
        XCTAssertEqual(snapshot.modelQuotas.first?.remainingPercent, 50)
        XCTAssertEqual(snapshot.modelQuotas.first?.tagTitle, "New")
        XCTAssertEqual(snapshot.credits?.availablePromptCredits, 500)
        XCTAssertEqual(snapshot.credits?.availableFlowCredits, 100)
        XCTAssertEqual(snapshot.credits?.monthlyPromptCredits, 50000)
        XCTAssertEqual(snapshot.credits?.monthlyFlowCredits, 150000)
        XCTAssertEqual(snapshot.credits?.monthlyFlexCreditPurchaseAmount, 25000)
        XCTAssertEqual(snapshot.credits?.canBuyMoreCredits, true)
    }
}

private final class StubProcessRunner: AntigravityProcessRunning, AntigravityLsofRunning {
    let psOutput: String
    let lsofOutput: String

    init(psOutput: String, lsofOutput: String) {
        self.psOutput = psOutput
        self.lsofOutput = lsofOutput
    }

    func runPsList() throws -> String {
        psOutput
    }

    func runLsofListen(pid: Int) throws -> String {
        lsofOutput
    }
}

private final class StubHTTPClient: AntigravityHTTPClient {
    var responses: [String: String?]

    init(responses: [String: String?]) {
        self.responses = responses
    }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        let key = url.path
        guard let value = responses[key] else {
            throw URLError(.badServerResponse)
        }
        if let string = value {
            return Data(string.utf8)
        }
        throw URLError(.init(rawValue: -1))
    }
}
