import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case spanish
    case brazilianPortuguese

    var id: String { rawValue }

    fileprivate var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .spanish:
            return "es"
        case .brazilianPortuguese:
            return "pt-BR"
        }
    }
}

enum StartupMenuTab: String, CaseIterable, Identifiable {
    case overview
    case codex
    case claude
    case antigravity

    var id: String { rawValue }
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var experimentalQuotaEnabled: Bool {
        didSet { defaults.set(experimentalQuotaEnabled, forKey: Keys.experimentalQuotaEnabled) }
    }

    @Published var experimentalQuotaCommand: String {
        didSet { defaults.set(experimentalQuotaCommand, forKey: Keys.experimentalQuotaCommand) }
    }

    @Published var autoRefreshEnabled: Bool {
        didSet { defaults.set(autoRefreshEnabled, forKey: Keys.autoRefreshEnabled) }
    }

    @Published var showRefreshSuccessNotices: Bool {
        didSet { defaults.set(showRefreshSuccessNotices, forKey: Keys.showRefreshSuccessNotices) }
    }

    @Published var startupTab: StartupMenuTab {
        didSet { defaults.set(startupTab.rawValue, forKey: Keys.startupTab) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        if defaults.object(forKey: Keys.experimentalQuotaEnabled) == nil {
            self.experimentalQuotaEnabled = true
        } else {
            self.experimentalQuotaEnabled = defaults.bool(forKey: Keys.experimentalQuotaEnabled)
        }
        self.experimentalQuotaCommand = defaults.string(forKey: Keys.experimentalQuotaCommand) ?? ""
        if defaults.object(forKey: Keys.autoRefreshEnabled) == nil {
            self.autoRefreshEnabled = true
        } else {
            self.autoRefreshEnabled = defaults.bool(forKey: Keys.autoRefreshEnabled)
        }
        if defaults.object(forKey: Keys.showRefreshSuccessNotices) == nil {
            self.showRefreshSuccessNotices = false
        } else {
            self.showRefreshSuccessNotices = defaults.bool(forKey: Keys.showRefreshSuccessNotices)
        }
        self.startupTab = StartupMenuTab(rawValue: defaults.string(forKey: Keys.startupTab) ?? "") ?? .codex
    }

    var locale: Locale {
        switch language {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        case .japanese:
            return Locale(identifier: "ja")
        case .korean:
            return Locale(identifier: "ko")
        case .spanish:
            return Locale(identifier: "es")
        case .brazilianPortuguese:
            return Locale(identifier: "pt-BR")
        }
    }

    func string(_ key: String) -> String {
        let value = resolvedBundle.localizedString(forKey: key, value: key, table: nil)
        if value != key {
            return value
        }
        return englishBundle.localizedString(forKey: key, value: key, table: nil)
    }

    private var resolvedBundle: Bundle {
        if let code = language.localizationCode {
            return bundle(for: code) ?? englishBundle
        }

        let preferred = Bundle.preferredLocalizations(
            from: supportedLocalizationCodes,
            forPreferences: Locale.preferredLanguages
        )
        let systemCode = preferred.first ?? "en"
        return bundle(for: systemCode) ?? englishBundle
    }

    private var englishBundle: Bundle {
        bundle(for: "en") ?? .main
    }

    private func bundle(for code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return nil
        }
        return bundle
    }

    private var supportedLocalizationCodes: [String] {
        AppLanguage.allCases.compactMap(\.localizationCode)
    }
}

private enum Keys {
    static let language = "codextoken.language"
    static let experimentalQuotaEnabled = "codextoken.experimentalQuotaEnabled"
    static let experimentalQuotaCommand = "codextoken.experimentalQuotaCommand"
    static let autoRefreshEnabled = "codextoken.autoRefreshEnabled"
    static let showRefreshSuccessNotices = "codextoken.showRefreshSuccessNotices"
    static let startupTab = "codextoken.startupTab"
}
