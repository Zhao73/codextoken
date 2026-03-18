import Foundation

public enum AccountSnapshotImportError: LocalizedError {
    case activeAuthMissing
    case unreadableAccountIdentifier

    public var errorDescription: String? {
        switch self {
        case .activeAuthMissing:
            return "The active Codex auth.json file could not be found."
        case .unreadableAccountIdentifier:
            return "The current auth.json session does not contain a usable account identifier."
        }
    }
}

public final class AccountSnapshotImportService {
    private let fileSystem: any FileSystem
    private let paths: CodexPaths
    private let decoder = JSONDecoder()

    public init(
        fileSystem: any FileSystem = LocalFileSystem(),
        paths: CodexPaths = .live()
    ) {
        self.fileSystem = fileSystem
        self.paths = paths
    }

    @discardableResult
    public func importCurrentSessionSnapshot(preferredFileName: String?) throws -> URL {
        guard fileSystem.fileExists(at: paths.activeAuthFile) else {
            throw AccountSnapshotImportError.activeAuthMissing
        }

        return try storeSnapshot(from: paths.activeAuthFile, preferredFileName: preferredFileName)
    }

    public func makeCurrentSessionImportShellScript() -> String {
        """
        export CODEXTOKEN_AUTH_FILE='\(escapedForSingleQuotes(paths.activeAuthFile.path))'
        export CODEXTOKEN_ACCOUNTS_DIR='\(escapedForSingleQuotes(paths.accountsDirectory.path))'
        /usr/bin/python3 - <<'PY'
        import json
        import os
        import pathlib
        import re
        import shutil
        import sys

        auth_path = pathlib.Path(os.environ["CODEXTOKEN_AUTH_FILE"])
        accounts_dir = pathlib.Path(os.environ["CODEXTOKEN_ACCOUNTS_DIR"])

        if not auth_path.exists():
            print("CodexToken: auth.json was not found after login.", file=sys.stderr)
            sys.exit(1)

        try:
            record = json.loads(auth_path.read_text())
        except Exception as exc:
            print(f"CodexToken: failed to read auth.json: {exc}", file=sys.stderr)
            sys.exit(1)

        tokens = record.get("tokens") or {}
        account_id = (tokens.get("account_id") or record.get("account_id") or "").strip()
        sanitized = re.sub(r"-{2,}", "-", re.sub(r"[^A-Za-z0-9_-]", "-", account_id)).strip("-")

        if not sanitized:
            print("CodexToken: auth.json does not contain a usable account identifier.", file=sys.stderr)
            sys.exit(1)

        accounts_dir.mkdir(parents=True, exist_ok=True)
        destination = accounts_dir / f"{sanitized}.json"
        shutil.copy2(auth_path, destination)
        print(destination)
        PY
        unset CODEXTOKEN_AUTH_FILE
        unset CODEXTOKEN_ACCOUNTS_DIR
        """
    }

    @discardableResult
    public func storeSnapshot(from sourceFile: URL, preferredFileName: String?) throws -> URL {
        guard fileSystem.fileExists(at: sourceFile) else {
            throw AccountSnapshotImportError.activeAuthMissing
        }

        let data = try fileSystem.read(from: sourceFile)
        let record = try decoder.decode(ImportedAuthRecord.self, from: data)

        let baseName = sanitizedBaseName(
            preferredFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? sanitizedBaseName(record.tokens.accountID) ?? sanitizedBaseName(record.accountID)

        guard let baseName else {
            throw AccountSnapshotImportError.unreadableAccountIdentifier
        }

        let destination = paths.accountsDirectory.appendingPathComponent("\(baseName).json")
        try fileSystem.createDirectory(at: paths.accountsDirectory, withIntermediateDirectories: true)
        try fileSystem.write(data, to: destination, options: .atomic)
        return destination
    }

    private func sanitizedBaseName(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return collapsed.isEmpty ? nil : collapsed
    }

    private func escapedForSingleQuotes(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}

private struct ImportedAuthRecord: Decodable {
    struct Tokens: Decodable {
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accountID = "account_id"
        }
    }

    let accountID: String?
    let tokens: Tokens

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case tokens
    }
}
