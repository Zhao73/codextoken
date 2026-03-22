import AppKit
import CodexTokenCore
import Foundation

@MainActor
final class TerminalCLILaunchService {
    enum LaunchError: LocalizedError {
        case terminalOpenFailed(String)

        var errorDescription: String? {
            switch self {
            case let .terminalOpenFailed(message):
                return message
            }
        }
    }

    func launch(context: CLIProfileLaunchContext, accountLabel: String) throws {
        let codexHome = context.codexHomeDirectory.path.hasSuffix("/")
            ? context.codexHomeDirectory.path
            : context.codexHomeDirectory.path + "/"

        let script = """
        #!/bin/zsh
        export CODEX_HOME='\(escapeSingleQuotes(codexHome))'
        clear
        printf '\\e]1;QuotaBar - \(escapeSingleQuotes(accountLabel))\\a'
        echo 'QuotaBar account: \(escapeSingleQuotes(accountLabel))'
        echo 'CODEX_HOME: \(escapeSingleQuotes(codexHome))'
        echo
        exec codex
        """

        let scriptURL = context.codexHomeDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("launch.command")
        try openTerminal(script: script, scriptURL: scriptURL)
    }

    func launchLogin(codexDirectory: URL, postLoginScript: String) throws {
        try launchLoginFlow(
            codexDirectory: codexDirectory,
            postLoginScript: postLoginScript,
            terminalTitle: "QuotaBar - Add Account",
            heading: "QuotaBar add account",
            successMessage: "Account saved. Return to QuotaBar and the list will refresh automatically."
        )
    }

    func launchRelogin(codexDirectory: URL, postLoginScript: String) throws {
        try launchLoginFlow(
            codexDirectory: codexDirectory,
            postLoginScript: postLoginScript,
            terminalTitle: "QuotaBar - Re-login",
            heading: "QuotaBar re-login current CLI",
            successMessage: "Login refreshed. Return to QuotaBar and quota data will refresh automatically."
        )
    }

    func launchClaudeLogin() throws {
        let script = """
        #!/bin/zsh
        clear
        printf '\\e]1;QuotaBar - Claude Login\\a'
        echo 'QuotaBar — Claude OAuth Login'
        echo
        if ! command -v claude >/dev/null 2>&1; then
            echo 'claude CLI was not found in PATH.'
            echo 'Install it first: npm install -g @anthropic-ai/claude-code'
            echo
            echo 'Press any key to close.'
            read -k 1
            exit 1
        fi
        echo 'Running: claude login'
        echo
        if claude login; then
            echo
            echo 'Claude login succeeded. Return to QuotaBar and refresh.'
            echo
            exec /bin/zsh -l
        else
            status=$?
            echo
            echo 'Claude login was cancelled or failed.'
            exit "$status"
        fi
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codextoken-claude-login.command")
        try openTerminal(script: script, scriptURL: scriptURL)
    }

    private func launchLoginFlow(
        codexDirectory: URL,
        postLoginScript: String,
        terminalTitle: String,
        heading: String,
        successMessage: String
    ) throws {
        let codexHome = codexDirectory.path.hasSuffix("/")
            ? codexDirectory.path
            : codexDirectory.path + "/"

        let script = """
        #!/bin/zsh
        set -euo pipefail
        export CODEX_HOME='\(escapeSingleQuotes(codexHome))'
        clear
        printf '\\e]1;\(escapeSingleQuotes(terminalTitle))\\a'
        echo '\(escapeSingleQuotes(heading))'
        echo 'CODEX_HOME: \(escapeSingleQuotes(codexHome))'
        echo
        if ! command -v codex >/dev/null 2>&1; then
            echo 'codex CLI was not found in PATH.'
            echo 'Press any key to close.'
            read -k 1
            exit 1
        fi
        if codex login; then
            echo
            echo 'Saving account snapshot...'
            \(postLoginScript)
            echo
            echo '\(escapeSingleQuotes(successMessage))'
            echo
            exec /bin/zsh -l
        else
            status=$?
            echo
            echo 'codex login was cancelled or failed.'
            exit "$status"
        fi
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codextoken-login-flow.command")
        try openTerminal(script: script, scriptURL: scriptURL)
    }

    private func openTerminal(script: String, scriptURL: URL) throws {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", scriptURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LaunchError.terminalOpenFailed("Failed to open Terminal for the selected account.")
        }
    }

    private func escapeSingleQuotes(_ text: String) -> String {
        text.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}
