import CodexTokenCore
import Foundation

enum ProviderKind: String, CaseIterable, Identifiable {
    case codex
    case claude
    case antigravity

    var id: String { rawValue }
}

struct ProviderSurfaceSummary: Identifiable {
    let provider: ProviderKind
    let title: String
    let accountLabel: String?
    let planLabel: String?
    let snapshot: QuotaSnapshot
    let primaryTitle: String
    let secondaryTitle: String?
    let tertiaryTitle: String?

    var id: String { provider.rawValue }
}

struct ProviderChartPoint: Identifiable {
    let timestamp: Date
    let usedPercent: Int
    let secondaryUsedPercent: Int?

    var id: TimeInterval { timestamp.timeIntervalSince1970 }
}
