import AppKit
import CodexTokenCore
import SwiftUI

private enum SettingsRoute: String, CaseIterable, Identifiable {
    case general
    case accounts
    case advanced

    var id: String { rawValue }
}

struct CodexTokenSettingsView: View {
    @ObservedObject var viewModel: CodexTokenMenuViewModel
    @ObservedObject var preferences: AppPreferences
    @State private var pendingDeletion: CodexAccount?
    @State private var selectedRoute: SettingsRoute = .general
    @State private var remarkDrafts: [String: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 960, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.refresh(showSuccessNotice: false)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SettingsRoute.allCases) { route in
                    sidebarButton(for: route)
                }
            }

            Spacer()

            Button(action: openFeedback) {
                Text(preferences.string("settings.nav.feedback"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedRoute {
        case .general:
            settingsForm {
                languageSection
                behaviorSection
                providersSection
            }
        case .accounts:
            settingsForm {
                accountsSection
                actionsSection
            }
        case .advanced:
            settingsForm {
                localFilesSection
                experimentalSection
            }
        }
    }

    private func sidebarButton(for route: SettingsRoute) -> some View {
        Button {
            selectedRoute = route
        } label: {
            HStack(spacing: 12) {
                Text(title(for: route))
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .foregroundStyle(selectedRoute == route ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedRoute == route ? Color.primary.opacity(0.09) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func title(for route: SettingsRoute) -> String {
        switch route {
        case .general:
            return preferences.string("settings.nav.general")
        case .accounts:
            return preferences.string("settings.nav.account")
        case .advanced:
            return preferences.string("settings.nav.advanced")
        }
    }

    private func openFeedback() {
        guard let url = URL(string: "https://github.com/Zhao73/quotabar/issues/new") else { return }
        NSWorkspace.shared.open(url)
    }

    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var languageSection: some View {
        Section {
            Picker(
                preferences.string("settings.language.label"),
                selection: $preferences.language
            ) {
                Text(preferences.string("settings.language.system")).tag(AppLanguage.system)
                Text(preferences.string("settings.language.english")).tag(AppLanguage.english)
                Text(preferences.string("settings.language.simplifiedChinese")).tag(AppLanguage.simplifiedChinese)
                Text(preferences.string("settings.language.traditionalChinese")).tag(AppLanguage.traditionalChinese)
                Text(preferences.string("settings.language.japanese")).tag(AppLanguage.japanese)
                Text(preferences.string("settings.language.korean")).tag(AppLanguage.korean)
                Text(preferences.string("settings.language.spanish")).tag(AppLanguage.spanish)
                Text(preferences.string("settings.language.brazilianPortuguese")).tag(AppLanguage.brazilianPortuguese)
            }
            Text(preferences.string("settings.language.help"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(preferences.string("settings.language.section"))
        }
    }

    private var behaviorSection: some View {
        Section {
            Picker(
                preferences.string("settings.tab.startup"),
                selection: $preferences.startupTab
            ) {
                Text(preferences.string("tab.overview")).tag(StartupMenuTab.overview)
                Text("Codex").tag(StartupMenuTab.codex)
                Text(preferences.string("tab.claude")).tag(StartupMenuTab.claude)
                Text(preferences.string("tab.antigravity")).tag(StartupMenuTab.antigravity)
            }

            Toggle(
                preferences.string("settings.notifications.autoRefresh"),
                isOn: $preferences.autoRefreshEnabled
            )

            Toggle(
                preferences.string("settings.notifications.successNotice"),
                isOn: $preferences.showRefreshSuccessNotices
            )

            Text(preferences.string("settings.tab.contextMenuHelp"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(preferences.string("settings.behavior.section"))
        } footer: {
            Text(preferences.string("settings.notifications.help"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var providersSection: some View {
        Section {
            ForEach(viewModel.settingsProviderDiagnostics) { diagnostic in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(diagnosticColor(for: diagnostic.state))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(diagnostic.title)
                                .font(.headline)

                            Spacer()

                            Text(diagnostic.statusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(diagnosticColor(for: diagnostic.state))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(diagnosticColor(for: diagnostic.state).opacity(0.12), in: Capsule())
                        }

                        Text(diagnostic.detailText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(preferences.string("settings.providers.section"))
        } footer: {
            Text(preferences.string("settings.providers.help"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accountsSection: some View {
        Section {
            ForEach(viewModel.accountRows) { row in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(row.account.email ?? row.account.displayName)
                                    .font(.headline)

                                if row.account.isActiveCLI {
                                    Text(preferences.string("menu.account.currentCLI"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.12), in: Capsule())
                                }

                                if let provider = row.account.loginProvider {
                                    Text(provider)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.08), in: Capsule())
                                }
                            }

                            Text("\(row.account.accountID ?? preferences.string("menu.account.identifierMissing")) • \(viewModel.localizedAuthMode(row.account.authMode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                viewModel.moveAccount(storageKey: row.account.storageKey, direction: .up)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!viewModel.canMoveAccount(storageKey: row.account.storageKey, direction: .up))
                            .help(preferences.string("settings.accounts.moveUp"))

                            Button {
                                viewModel.moveAccount(storageKey: row.account.storageKey, direction: .down)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!viewModel.canMoveAccount(storageKey: row.account.storageKey, direction: .down))
                            .help(preferences.string("settings.accounts.moveDown"))

                            Button(role: .destructive) {
                                pendingDeletion = row.account
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help(preferences.string("settings.accounts.delete"))
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(
                            preferences.string("settings.accounts.remarkPlaceholder"),
                            text: remarkBinding(for: row.account)
                        )
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveRemarkDraft(for: row.account)
                        }

                        Button(preferences.string("settings.accounts.remarkSave")) {
                            saveRemarkDraft(for: row.account)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveRemark(for: row.account))
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            HStack {
                Text(preferences.string("settings.accounts.section"))
                Spacer()
                Button(action: viewModel.addAccount) {
                    Label(
                        preferences.string("settings.accounts.add"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .help(preferences.string("settings.accounts.addHelp"))
            }
        } footer: {
            Text(preferences.string("settings.accounts.remarkHelp"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .alert(item: $pendingDeletion) { account in
            Alert(
                title: Text(preferences.string("settings.accounts.deleteConfirmTitle")),
                message: Text(
                    String(
                        format: preferences.string("settings.accounts.deleteConfirmMessage"),
                        account.email ?? account.displayName
                    )
                ),
                primaryButton: .destructive(Text(preferences.string("settings.accounts.delete"))) {
                    viewModel.deleteAccount(account)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var actionsSection: some View {
        Section {
            Button(preferences.string("settings.actions.refresh")) {
                viewModel.refresh()
            }

            Button(preferences.string("settings.actions.relogin")) {
                viewModel.reloginCurrentCLI()
            }

            Button(preferences.string("settings.actions.importSession")) {
                viewModel.importCurrentSession()
            }
            .disabled(!viewModel.liveSessionNeedsImport && !FileManager.default.fileExists(atPath: viewModel.paths.activeAuthFile.path))
        } header: {
            Text(preferences.string("settings.actions.section"))
        }
    }

    private var localFilesSection: some View {
        Section {
            pathRow(
                label: preferences.string("settings.browser.activeAuth"),
                value: viewModel.paths.activeAuthFile.path
            ) {
                viewModel.revealAuthFile()
            }

            pathRow(
                label: preferences.string("settings.browser.configFile"),
                value: viewModel.paths.configFile.path
            ) {
                viewModel.revealConfigFile()
            }

            pathRow(
                label: preferences.string("settings.storage.codexDirectory"),
                value: viewModel.paths.codexDirectory.path
            ) {
                viewModel.revealCodexDirectory()
            }

            pathRow(
                label: preferences.string("settings.storage.accountsDirectory"),
                value: viewModel.paths.accountsDirectory.path
            ) {
                viewModel.revealAccountsDirectory()
            }

            pathRow(
                label: preferences.string("settings.storage.metadataFile"),
                value: viewModel.metadataURL.path
            ) {
                NSWorkspace.shared.activateFileViewerSelecting([viewModel.metadataURL])
            }
        } header: {
            Text(preferences.string("settings.storage.section"))
        } footer: {
            Text(preferences.string("settings.storage.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var experimentalSection: some View {
        Section {
            Toggle(
                preferences.string("settings.experimental.quotaToggle"),
                isOn: $preferences.experimentalQuotaEnabled
            )
            TextField(
                preferences.string("settings.experimental.commandLabel"),
                text: $preferences.experimentalQuotaCommand
            )
            .textFieldStyle(.roundedBorder)
            .disabled(!preferences.experimentalQuotaEnabled)

            Text(preferences.string("settings.experimental.commandHelp"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(preferences.string("settings.experimental.section"))
        }
    }

    private func pathRow(
        label: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button(preferences.string("settings.storage.reveal"), action: action)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func remarkBinding(for account: CodexAccount) -> Binding<String> {
        Binding(
            get: { remarkDrafts[account.storageKey] ?? account.remark ?? "" },
            set: { remarkDrafts[account.storageKey] = $0 }
        )
    }

    private func saveRemarkDraft(for account: CodexAccount) {
        viewModel.saveRemark(remarkDrafts[account.storageKey] ?? account.remark ?? "", for: account)
    }

    private func canSaveRemark(for account: CodexAccount) -> Bool {
        normalizedRemark(remarkDrafts[account.storageKey] ?? account.remark ?? "") != normalizedRemark(account.remark ?? "")
    }

    private func normalizedRemark(_ remark: String) -> String {
        remark.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func diagnosticColor(for state: CodexTokenMenuViewModel.ProviderDiagnostic.State) -> Color {
        switch state {
        case .connected:
            return .green
        case .degraded:
            return .orange
        case .unavailable:
            return .red
        }
    }
}
