import Foundation

public protocol AntigravityProcessRunning {
    func runPsList() throws -> String
}

public protocol AntigravityLsofRunning {
    func runLsofListen(pid: Int) throws -> String
}

public protocol AntigravityHTTPClient {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
}

public struct AntigravityModelsSnapshot: Codable, Equatable, Sendable {
    public struct ModelQuota: Codable, Equatable, Sendable, Identifiable {
        public let label: String
        public let remainingFraction: Double?
        public let resetDate: Date?
        public let isRecommended: Bool
        public let tagTitle: String?

        public var id: String { label }

        public var remainingPercent: Int {
            guard let remainingFraction else { return 0 }
            return Int(round(min(100, max(0, remainingFraction * 100))))
        }
    }

    public struct Credits: Codable, Equatable, Sendable {
        public let availablePromptCredits: Int?
        public let monthlyPromptCredits: Int?
        public let availableFlowCredits: Int?
        public let monthlyFlowCredits: Int?
        public let monthlyFlexCreditPurchaseAmount: Int?
        public let canBuyMoreCredits: Bool?
    }

    public enum OverageState: String, Codable, Equatable, Sendable {
        case enabled
        case disabled
        case unknown
    }

    public let status: QuotaStatus
    public let refreshedAt: Date?
    public let sourceLabel: String
    public let confidence: QuotaConfidence
    public let warnings: [String]
    public let errorDescription: String?
    public let accountName: String?
    public let accountEmail: String?
    public let planName: String?
    public let modelQuotas: [ModelQuota]
    public let credits: Credits?
    public let overageState: OverageState

    public init(
        status: QuotaStatus,
        refreshedAt: Date?,
        sourceLabel: String,
        confidence: QuotaConfidence,
        warnings: [String] = [],
        errorDescription: String? = nil,
        accountName: String? = nil,
        accountEmail: String? = nil,
        planName: String? = nil,
        modelQuotas: [ModelQuota] = [],
        credits: Credits? = nil,
        overageState: OverageState = .unknown
    ) {
        self.status = status
        self.refreshedAt = refreshedAt
        self.sourceLabel = sourceLabel
        self.confidence = confidence
        self.warnings = warnings
        self.errorDescription = errorDescription
        self.accountName = accountName
        self.accountEmail = accountEmail
        self.planName = planName
        self.modelQuotas = modelQuotas
        self.credits = credits
        self.overageState = overageState
    }
}

public struct AntigravityQuotaProvider: QuotaProviding {
    private let processRunner: any AntigravityProcessRunning
    private let lsofRunner: any AntigravityLsofRunning
    private let httpClient: any AntigravityHTTPClient

    public init(
        processRunner: (any AntigravityProcessRunning)? = nil,
        lsofRunner: (any AntigravityLsofRunning)? = nil,
        httpClient: (any AntigravityHTTPClient)? = nil
    ) {
        self.processRunner = processRunner ?? DefaultAntigravityProcessRunner()
        self.lsofRunner = lsofRunner ?? DefaultAntigravityLsofRunner()
        self.httpClient = httpClient ?? DefaultAntigravityHTTPClient()
    }

    public func snapshot(for account: CodexAccount) async -> QuotaSnapshot {
        let detailedSnapshot = await modelsSnapshot(for: account)
        return Self.summarySnapshot(from: detailedSnapshot)
    }

    public func modelsSnapshot(for account: CodexAccount) async -> AntigravityModelsSnapshot {
        do {
            let info = try detectProcess()
            let ports = try parseListeningPorts(from: lsofRunner.runLsofListen(pid: info.pid))
            guard !ports.isEmpty else {
                throw AntigravityQuotaError.portDetectionFailed("no listening ports")
            }
            let context = try await findWorkingPort(ports: ports, csrfToken: info.csrfToken, httpPort: info.extensionPort)
            let statusData: Data
            do {
                statusData = try await fetchStatus(path: AntigravityQuotaProvider.getUserStatusPath, context: context)
            } catch {
                statusData = try await fetchStatus(path: AntigravityQuotaProvider.commandModelPath, context: context)
            }
            let payload = try JSONDecoder().decode(AntigravityQuotaPayload.self, from: statusData)
            let ordered = Self.orderedModels(from: payload)
            guard !ordered.isEmpty else {
                throw AntigravityQuotaError.emptyQuota
            }
            var warnings: [String] = []
            if let plan = payload.planName?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty {
                warnings.append("Plan: " + plan)
            }
            warnings.append("Primary label: " + ordered[0].label)
            if ordered.count > 1 {
                warnings.append("Secondary label: " + ordered[1].label)
            }
            if !info.matchesAntigravity {
                warnings.append("Account: Local language server")
            }
            return AntigravityModelsSnapshot(
                status: .experimental,
                refreshedAt: Date(),
                sourceLabel: "Antigravity",
                confidence: .medium,
                warnings: warnings,
                accountName: payload.accountName,
                accountEmail: payload.accountEmail,
                planName: payload.planName,
                modelQuotas: ordered.map(Self.makeModelQuota),
                credits: payload.credits,
                overageState: payload.overageState
            )
        } catch {
            return AntigravityModelsSnapshot(
                status: .error,
                refreshedAt: account.lastRefreshAt,
                sourceLabel: "Antigravity",
                confidence: .low,
                warnings: [error.localizedDescription],
                errorDescription: error.localizedDescription
            )
        }
    }

    private func detectProcess() throws -> AntigravityProcessInfo {
        let output = try processRunner.runPsList()
        for line in output.split(whereSeparator: \.isNewline).map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            let command = String(parts[1])
            let lowerCommand = command.lowercased()
            guard lowerCommand.contains("language_server_macos") else { continue }
            let csrf = Self.extractFlag("--csrf_token", from: command)
            guard let csrf else { continue }
            let extensionPort = Self.extractFlag("--extension_server_port", from: command).flatMap(Int.init)
            let matchesAntigravity = lowerCommand.contains("antigravity")
            return AntigravityProcessInfo(
                pid: pid,
                csrfToken: csrf,
                extensionPort: extensionPort,
                matchesAntigravity: matchesAntigravity
            )
        }
        throw AntigravityQuotaError.processNotFound
    }

    private func parseListeningPorts(from output: String) -> [Int] {
        let regex = try? NSRegularExpression(pattern: ":(\\d+) \\(LISTEN\\)")
        guard let regex else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        var ports: Set<Int> = []
        regex.enumerateMatches(in: output, options: [], range: range) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range(at: 1), in: output),
                  let port = Int(output[matchRange])
            else { return }
            ports.insert(port)
        }
        return Array(ports).sorted()
    }

    private func findWorkingPort(ports: [Int], csrfToken: String, httpPort: Int?) async throws -> RequestContext {
        for port in ports {
            let context = RequestContext(httpsPort: port, httpPort: httpPort, csrfToken: csrfToken)
            do {
                _ = try await sendRequest(path: Self.unleashPath, context: context)
                return context
            } catch {
                continue
            }
        }
        throw AntigravityQuotaError.portDetectionFailed("no working API port")
    }

    private func fetchStatus(path: String, context: RequestContext) async throws -> Data {
        return try await sendRequest(path: path, context: context)
    }

    private func sendRequest(path: String, context: RequestContext) async throws -> Data {
        let payload = Self.requestBody(for: path)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let headers = [
            "Content-Type": "application/json",
            "X-Codeium-Csrf-Token": context.csrfToken,
            "Connect-Protocol-Version": "1"
        ]
        do {
            return try await httpClient.post(
                url: Self.makeURL(scheme: "https", port: context.httpsPort, path: path),
                headers: headers,
                body: data
            )
        } catch {
            if let httpPort = context.httpPort {
                return try await httpClient.post(
                    url: Self.makeURL(scheme: "http", port: httpPort, path: path),
                    headers: headers,
                    body: data
                )
            }
            return try await httpClient.post(
                url: Self.makeURL(scheme: "http", port: context.httpsPort, path: path),
                headers: headers,
                body: data
            )
        }
    }

    private static func makeURL(scheme: String, port: Int, path: String) -> URL {
        return URL(string: "\(scheme)://127.0.0.1:\(port)\(path)")!
    }

    private static func requestBody(for path: String) -> [String: Any] {
        if path == unleashPath {
            return [
                "metadata": [
                    "ideName": "antigravity",
                    "extensionName": "antigravity",
                    "ideVersion": "unknown",
                    "locale": "en"
                ]
            ]
        }
        return [
            "metadata": [
                "ideName": "antigravity",
                "extensionName": "antigravity",
                "ideVersion": "unknown",
                "locale": "en"
            ]
        ]
    }

    private static func rateWindow(for model: AntigravityModelQuota) -> QuotaWindowSnapshot {
        let remaining = model.remainingPercent
        let usedPercent = max(0, min(100, 100 - remaining))
        return QuotaWindowSnapshot(
            usedPercent: Int(round(usedPercent)),
            windowDurationMinutes: nil,
            resetsAt: model.resetDate
        )
    }

    private static func makeModelQuota(from model: AntigravityModelQuota) -> AntigravityModelsSnapshot.ModelQuota {
        AntigravityModelsSnapshot.ModelQuota(
            label: model.label,
            remainingFraction: model.remainingFraction,
            resetDate: model.resetDate,
            isRecommended: model.isRecommended,
            tagTitle: model.tagTitle
        )
    }

    private static func orderedModels(from payload: AntigravityQuotaPayload) -> [AntigravityModelQuota] {
        let models = payload.modelQuotas
        guard !models.isEmpty else { return [] }
        guard !payload.preferredModelOrder.isEmpty else {
            return selectModels(models)
        }

        var ordered: [AntigravityModelQuota] = []
        for preferredLabel in payload.preferredModelOrder {
            guard let match = models.first(where: { $0.label == preferredLabel }),
                  !ordered.contains(where: { $0.label == match.label }) else { continue }
            ordered.append(match)
        }

        let remaining = models.filter { quota in
            !ordered.contains(where: { $0.label == quota.label })
        }

        ordered.append(contentsOf: remaining.sorted { lhs, rhs in
            if lhs.isRecommended != rhs.isRecommended {
                return lhs.isRecommended && !rhs.isRecommended
            }
            return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
        })
        return ordered
    }

    private static func selectModels(_ models: [AntigravityModelQuota]) -> [AntigravityModelQuota] {
        var ordered: [AntigravityModelQuota] = []
        if let claude = models.first(where: { Self.isClaudeLabel($0.label) }) {
            ordered.append(claude)
        }
        if let pro = models.first(where: { Self.isGeminiProLabel($0.label) }), !ordered.contains(where: { $0.label == pro.label }) {
            ordered.append(pro)
        }
        if let flash = models.first(where: { Self.isGeminiFlashLabel($0.label) }), !ordered.contains(where: { $0.label == flash.label }) {
            ordered.append(flash)
        }
        let remaining = models.filter { quota in
            !ordered.contains(where: { $0.label == quota.label })
        }
        ordered.append(contentsOf: remaining.sorted { $0.remainingPercent > $1.remainingPercent })
        return ordered
    }

    private static func summarySnapshot(from detailedSnapshot: AntigravityModelsSnapshot) -> QuotaSnapshot {
        let summaryModels = selectModels(detailedSnapshot.modelQuotas.map(Self.makeInternalModelQuota))
        let primary = summaryModels.first.map(rateWindow)
        let secondary = summaryModels.dropFirst().first.map(rateWindow)
        return QuotaSnapshot(
            status: detailedSnapshot.status,
            refreshedAt: detailedSnapshot.refreshedAt,
            sourceLabel: detailedSnapshot.sourceLabel,
            confidence: detailedSnapshot.confidence,
            warnings: detailedSnapshot.warnings,
            errorDescription: detailedSnapshot.errorDescription,
            primaryWindow: primary,
            secondaryWindow: secondary
        )
    }

    private static func makeInternalModelQuota(from model: AntigravityModelsSnapshot.ModelQuota) -> AntigravityModelQuota {
        AntigravityModelQuota(
            label: model.label,
            remainingFraction: model.remainingFraction,
            resetTime: model.resetDate.map { ISO8601DateFormatter().string(from: $0) },
            isRecommended: model.isRecommended,
            tagTitle: model.tagTitle
        )
    }

    private static func isClaudeLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("claude") && !lower.contains("thinking")
    }

    private static func isGeminiProLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("pro") && lower.contains("low")
    }

    private static func isGeminiFlashLabel(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("gemini") && lower.contains("flash")
    }

    private static func extractFlag(_ flag: String, from command: String) -> String? {
        let pattern = NSRegularExpression.escapedPattern(for: flag) + #"[=\s]+([^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(command.startIndex..<command.endIndex, in: command)
        guard let match = regex.firstMatch(in: command, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: command)
        else {
            return nil
        }
        return String(command[valueRange])
    }

    private struct AntigravityProcessInfo {
        let pid: Int
        let csrfToken: String
        let extensionPort: Int?
        let matchesAntigravity: Bool
    }

    private struct RequestContext {
        let httpsPort: Int
        let httpPort: Int?
        let csrfToken: String
    }

    private enum AntigravityQuotaError: LocalizedError {
        case processNotFound
        case portDetectionFailed(String)
        case emptyQuota

        var errorDescription: String? {
            switch self {
            case .processNotFound:
                return "Antigravity process not found."
            case let .portDetectionFailed(reason):
                return "Port detection failed: \(reason)"
            case .emptyQuota:
                return "Antigravity returned no quota data."
            }
        }
    }

    private static let unleashPath = "/exa.language_server_pb.LanguageServerService/GetUnleashData"
    private static let getUserStatusPath = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
    private static let commandModelPath = "/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs"
}

extension AntigravityQuotaProvider: @unchecked Sendable {}

private struct AntigravityQuotaPayload: Decodable {
    let modelQuotas: [AntigravityModelQuota]
    let planName: String?
    let accountName: String?
    let accountEmail: String?
    let credits: AntigravityModelsSnapshot.Credits?
    let overageState: AntigravityModelsSnapshot.OverageState
    let preferredModelOrder: [String]

    enum CodingKeys: String, CodingKey {
        case modelQuotas
        case plan
        case userStatus
        case cascadeModelConfigData
        case clientModelConfigs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var quotas: [AntigravityModelQuota] = []
        var preferredModelOrder: [String] = []
        var accountName: String?
        var accountEmail: String?
        var planName = try container.decodeIfPresent(String.self, forKey: .plan)
        var credits: AntigravityModelsSnapshot.Credits?
        var overageState: AntigravityModelsSnapshot.OverageState = .unknown
        if let direct = try container.decodeIfPresent([AntigravityModelQuota].self, forKey: .modelQuotas) {
            quotas = direct
        } else if let userStatus = try container.decodeIfPresent(UserStatusPayload.self, forKey: .userStatus) {
            quotas = userStatus.allQuotas
            preferredModelOrder = userStatus.preferredModelOrder
            accountName = userStatus.name
            accountEmail = userStatus.email
            planName = planName ?? userStatus.planStatus?.planInfo?.planName
            credits = userStatus.planStatus?.credits
            overageState = userStatus.overageState
        } else if let cascade = try container.decodeIfPresent(CascadeModelConfigPayload.self, forKey: .cascadeModelConfigData) {
            quotas = cascade.allQuotas
            preferredModelOrder = cascade.preferredModelOrder
        } else if let configs = try container.decodeIfPresent([ClientModelConfigPayload].self, forKey: .clientModelConfigs) {
            quotas = configs.compactMap(\.modelQuota)
        }
        self.modelQuotas = quotas
        self.planName = planName
        self.accountName = accountName
        self.accountEmail = accountEmail
        self.credits = credits
        self.overageState = overageState
        self.preferredModelOrder = preferredModelOrder
    }
}

private struct AntigravityModelQuota: Decodable, Hashable {
    let label: String
    let remainingFraction: Double?
    let resetTime: String?
    let isRecommended: Bool
    let tagTitle: String?

    enum CodingKeys: String, CodingKey {
        case label
        case remainingFraction
        case resetTime
        case isRecommended
        case tagTitle
    }

    var remainingPercent: Double {
        guard let fraction = remainingFraction else { return 0 }
        return min(100, max(0, fraction * 100))
    }

    var resetDate: Date? {
        guard let value = resetTime else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        if let timeInterval = Double(value) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return nil
    }

    init(
        label: String,
        remainingFraction: Double?,
        resetTime: String?,
        isRecommended: Bool = false,
        tagTitle: String? = nil
    ) {
        self.label = label
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
        self.isRecommended = isRecommended
        self.tagTitle = tagTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decode(String.self, forKey: .label)
        self.remainingFraction = try container.decodeIfPresent(Double.self, forKey: .remainingFraction)
        self.resetTime = try container.decodeIfPresent(String.self, forKey: .resetTime)
        self.isRecommended = try container.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        self.tagTitle = try container.decodeIfPresent(String.self, forKey: .tagTitle)
    }
}

private struct UserStatusPayload: Decodable {
    let name: String?
    let email: String?
    let planStatus: PlanStatusPayload?
    let cascadeModelConfigData: CascadeModelConfigPayload?
    let clientModelConfigs: [ClientModelConfigPayload]?
    let acceptedLatestTermsOfService: Bool?
    let userTier: UserTierPayload?

    var allQuotas: [AntigravityModelQuota] {
        if let cascadeModelConfigData {
            return cascadeModelConfigData.allQuotas
        }
        return clientModelConfigs?.compactMap(\.modelQuota) ?? []
    }

    var preferredModelOrder: [String] {
        if let cascadeModelConfigData {
            return cascadeModelConfigData.preferredModelOrder
        }
        return []
    }

    var overageState: AntigravityModelsSnapshot.OverageState {
        .unknown
    }
}

private struct CascadeModelConfigPayload: Decodable {
    let clientModelConfigs: [ClientModelConfigPayload]?
    let clientModelSorts: [ClientModelSortPayload]?

    var allQuotas: [AntigravityModelQuota] {
        clientModelConfigs?.compactMap(\.modelQuota) ?? []
    }

    var preferredModelOrder: [String] {
        clientModelSorts?
            .flatMap(\.groups)
            .flatMap(\.modelLabels) ?? []
    }
}

private struct ClientModelConfigPayload: Decodable {
    let label: String?
    let modelID: String?
    let humanName: String?
    let isRecommended: Bool?
    let tagTitle: String?
    let quotaInfo: QuotaInfoPayload?

    enum CodingKeys: String, CodingKey {
        case label
        case modelID = "modelId"
        case humanName
        case isRecommended
        case tagTitle
        case quotaInfo
    }

    var modelQuota: AntigravityModelQuota? {
        quotaInfo?.asQuota(
            label: label ?? humanName ?? modelID ?? "Unknown",
            isRecommended: isRecommended ?? false,
            tagTitle: tagTitle
        )
    }
}

private struct QuotaInfoPayload: Decodable {
    let remainingFraction: Double?
    let resetTime: String?

    func asQuota(label: String, isRecommended: Bool = false, tagTitle: String? = nil) -> AntigravityModelQuota {
        AntigravityModelQuota(
            label: label,
            remainingFraction: remainingFraction,
            resetTime: resetTime,
            isRecommended: isRecommended,
            tagTitle: tagTitle
        )
    }
}

private struct PlanStatusPayload: Decodable {
    let planInfo: PlanInfoPayload?
    let availablePromptCredits: LossyInt?
    let availableFlowCredits: LossyInt?

    var credits: AntigravityModelsSnapshot.Credits? {
        guard let planInfo
        else { return nil }
        return AntigravityModelsSnapshot.Credits(
            availablePromptCredits: availablePromptCredits?.value,
            monthlyPromptCredits: planInfo.monthlyPromptCredits?.value,
            availableFlowCredits: availableFlowCredits?.value,
            monthlyFlowCredits: planInfo.monthlyFlowCredits?.value,
            monthlyFlexCreditPurchaseAmount: planInfo.monthlyFlexCreditPurchaseAmount?.value,
            canBuyMoreCredits: planInfo.canBuyMoreCredits
        )
    }
}

private struct PlanInfoPayload: Decodable {
    let planName: String?
    let monthlyPromptCredits: LossyInt?
    let monthlyFlowCredits: LossyInt?
    let monthlyFlexCreditPurchaseAmount: LossyInt?
    let canBuyMoreCredits: Bool?
}

private struct UserTierPayload: Decodable {
    let id: String?
    let name: String?
    let description: String?
}

private struct ClientModelSortPayload: Decodable {
    let name: String?
    let groups: [ClientModelSortGroupPayload]
}

private struct ClientModelSortGroupPayload: Decodable {
    let modelLabels: [String]
}

private struct LossyInt: Decodable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            value = Int(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            value = Int(stringValue)
            return
        }
        value = nil
    }
}

private final class LockedProcessDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func replace(with data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class DefaultAntigravityProcessRunner: AntigravityProcessRunning {
    func runPsList() throws -> String {
        try runProcess(binary: "/bin/ps", arguments: ["-ax", "-o", "pid=,command="])
    }

    private func runProcess(binary: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let group = DispatchGroup()
        let outputBuffer = LockedProcessDataBuffer()
        let errorBuffer = LockedProcessDataBuffer()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            outputBuffer.replace(with: data)
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            errorBuffer.replace(with: data)
            group.leave()
        }

        try process.run()
        process.waitUntilExit()
        group.wait()

        let output = String(decoding: outputBuffer.data, as: UTF8.self)
        let error = String(decoding: errorBuffer.data, as: UTF8.self)
        let mergedOutput = [output, error]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AntigravityProcessRunner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: mergedOutput.isEmpty ? "ps command failed." : mergedOutput]
            )
        }
        return output
    }
}

final class DefaultAntigravityLsofRunner: AntigravityLsofRunning {
    func runLsofListen(pid: Int) throws -> String {
        try runProcess(binary: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-p", String(pid)])
    }

    private func runProcess(binary: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let group = DispatchGroup()
        let outputBuffer = LockedProcessDataBuffer()
        let errorBuffer = LockedProcessDataBuffer()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            outputBuffer.replace(with: data)
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            errorBuffer.replace(with: data)
            group.leave()
        }

        try process.run()
        process.waitUntilExit()
        group.wait()

        let output = String(decoding: outputBuffer.data, as: UTF8.self)
        let error = String(decoding: errorBuffer.data, as: UTF8.self)
        let mergedOutput = [output, error]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AntigravityLsofRunner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: mergedOutput.isEmpty ? "lsof command failed." : mergedOutput]
            )
        }
        return output
    }
}

final class DefaultAntigravityHTTPClient: AntigravityHTTPClient {
    private let session: URLSession

    init(session: URLSession = DefaultAntigravityHTTPClient.makeSession()) {
        self.session = session
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        let delegate = InsecureLocalhostSessionDelegate()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 8
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private final class InsecureLocalhostSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String?,
              host == "127.0.0.1" || host == "localhost"
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
