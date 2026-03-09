<p align="center">
  <img src="docs/images/banner.png" width="600" />
</p>

<h1 align="center">CodexToken</h1>

<p align="center">
  <strong>The missing account manager for Codex CLI.</strong><br>
  Switch accounts. Monitor quota. Launch isolated sessions. All from your menu bar.
</p>

<p align="center">
  <a href="#install"><img src="https://img.shields.io/badge/-Install-28a745?style=for-the-badge&logoColor=white" /></a>
  <a href="#features"><img src="https://img.shields.io/badge/-Features-0366d6?style=for-the-badge&logoColor=white" /></a>
  <a href="#architecture"><img src="https://img.shields.io/badge/-Architecture-6f42c1?style=for-the-badge&logoColor=white" /></a>
  <a href="README_CN.md"><img src="https://img.shields.io/badge/-中文文档-e36209?style=for-the-badge&logoColor=white" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS_14+-111?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/dependencies-0-brightgreen?style=flat-square" />
  <img src="https://img.shields.io/github/license/Zhao73/codextoken?style=flat-square&color=blue" />
  <img src="https://img.shields.io/github/stars/Zhao73/codextoken?style=flat-square" />
</p>

<!--
<p align="center">
  <img src="docs/screenshots/menu.png" width="380" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/settings.png" width="380" />
</p>
-->

---

## The Problem

You have multiple OpenAI / Codex accounts — personal, work, test keys. Every time you switch, you're manually editing `~/.codex/auth.json`, losing track of which account is active, unable to compare quotas, and terrified of overwriting the wrong token.

**CodexToken fixes this.** One click in the menu bar. Done.

---

## Features

<table>
<tr>
<td width="50%">

### 🔍 Auto-Discovery
Scans `~/.codex/accounts/` and `auth.json` automatically. Merges duplicates by `account_id`. Extracts email & provider from JWT claims — zero configuration needed.

### ⚡ One-Click Switching
Select an account, click switch. CodexToken copies the snapshot to `auth.json`, validates via `codex login status`, and **auto-rolls back** if anything goes wrong.

### 📊 Quota Monitoring
Composite provider chain: Codex App Server → custom shell command → local fallback. Displays 5-hour & weekly windows with confidence levels.

### 🏷️ Account Metadata
Custom display names, free-text remarks, drag-to-reorder. Stored in a separate local JSON — never touches your auth files.

</td>
<td width="50%">

### 🖥️ Isolated Terminal Sessions
"Open CLI" creates a dedicated Terminal with its own `CODEX_HOME`. Run **multiple Codex instances** simultaneously, each authenticated as a different account.

### 📸 Session Snapshots
Save the current `auth.json` as a named snapshot. Delete or hide accounts you no longer need. Import snapshots from login flows.

### 🗣️ Siri Shortcuts
Three AppIntents out of the box: save session, open `.codex` folder, reveal `auth.json`. Works with Shortcuts app and voice commands.

### 🌐 Bilingual Interface
Full English & 简体中文 UI with instant runtime switching — no restart required.

</td>
</tr>
</table>

---

## Install

> **Requirements:** macOS 14+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.38+, Xcode with Swift 6

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Clone & build
git clone https://github.com/Zhao73/codextoken.git
cd codextoken
xcodegen generate
open CodexToken.xcodeproj
# ⌘R → app appears in the menu bar (no Dock icon)
```

<details>
<summary><strong>Run tests</strong></summary>

```bash
xcodebuild test \
  -project CodexToken.xcodeproj \
  -scheme CodexTokenCore \
  -destination 'platform=macOS'
```
</details>

---

## How It Works

```
┌─────────────────┐     ┌──────────────────────────┐
│    Menu Bar      │────▶│  AccountDiscoveryService  │
│  CodexToken ⌘   │     │  scan ~/.codex/accounts/  │
└────────┬────────┘     │  parse JWT claims         │
         │              └──────────────────────────┘
         │
         ├── Switch ──▶ CLISwitchService
         │              ├─ backup auth.json
         │              ├─ write new token
         │              ├─ validate (codex login status)
         │              └─ rollback on failure ↩
         │
         ├── Open CLI ──▶ CLIProfilePreparationService
         │                ├─ create isolated CODEX_HOME
         │                └─ launch Terminal with env
         │
         └── Quota ──▶ CompositeQuotaProvider
                       ├─ CodexAppServerQuotaProvider (HTTPS)
                       ├─ ExperimentalQuotaProvider (shell cmd)
                       └─ LocalStateQuotaProvider (fallback)
```

### Data Files

All data stays in `~/.codex/` on your Mac — **nothing leaves your machine**.

| File | Owner | Content |
|:-----|:------|:--------|
| `auth.json` | Codex CLI | Active session token |
| `accounts/*.json` | CodexToken | Saved session snapshots |
| `codex-token-metadata.json` | CodexToken | Display names, remarks, sort order |
| `config.toml` | Codex CLI | CLI config (copied into isolated profiles) |

---

## Architecture

```
Sources/
├── CodexTokenCore/                    # ← Testable framework, no UI
│   ├── Infrastructure/
│   │   └── FileSystem.swift           #   Protocol + InMemoryFileSystem
│   ├── Models/
│   │   ├── CodexAccount.swift         #   id, email, authMode, lastRefresh…
│   │   ├── QuotaSnapshot.swift        #   status, windows, confidence
│   │   ├── CodexPaths.swift           #   ~/.codex path constants
│   │   └── AccountMetadata.swift      #   name, remark, sort, hidden
│   └── Services/
│       ├── AccountDiscoveryService    #   Scan + merge + sort
│       ├── CLISwitchService           #   Atomic swap + rollback
│       ├── CLIProfilePreparationService  # Per-account CODEX_HOME
│       ├── AccountSnapshotImport/Removal # Snapshot lifecycle
│       ├── AccountMetadataStore       #   Metadata CRUD
│       └── Quota/
│           ├── QuotaProviding         #   Protocol + composite chain
│           ├── CodexAppServerQuota…   #   HTTPS → openai.com
│           ├── ExperimentalQuota…     #   User shell command
│           └── LocalStateQuota…       #   Offline fallback
│
└── CodexTokenApp/                     # ← SwiftUI menu bar app
    ├── CodexTokenApp.swift            #   @main MenuBarExtra
    ├── CodexTokenMenuView/ViewModel   #   Account cards + business logic
    ├── CodexTokenSettingsView         #   Settings window
    ├── CodexTokenAppIntents           #   Siri Shortcuts
    ├── AppPreferences                 #   Language & feature toggles
    ├── TerminalCLILaunchService       #   launch.command generation
    └── CLILaunchRecordStore /
        QuotaSnapshotCacheStore        #   Local caches
```

### Design Highlights

| Principle | Implementation |
|:----------|:---------------|
| **Testability** | Every service accepts a `FileSystem` protocol. Tests use `InMemoryFileSystem` — no real disk I/O. |
| **Composite Quota** | Chain of `QuotaProviding` providers. First `.available` / `.experimental` wins; otherwise next in line. |
| **CODEX_HOME Isolation** | "Open CLI" creates a temp dir with its own `.codex/auth.json` + `CODEX_HOME` env var. |
| **Atomic Switch** | `CLISwitchService` backs up → overwrites → validates → rolls back on failure. |
| **Zero Dependencies** | Pure Swift 6 + SwiftUI + AppKit. No SPM packages, no CocoaPods, no Carthage. |

---

## Privacy & Security

> **TL;DR:** CodexToken never sends your data anywhere. Everything stays in `~/.codex/`.

- 📄 [Privacy Policy](PRIVACY.md) — What we collect (nothing), where data lives, experimental opt-ins
- 🔒 [Security Policy](SECURITY.md) — Token handling, atomic switching, isolated profiles

---

## Contributing

We welcome bug fixes, test coverage, docs, and localization improvements. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

<p align="center">
  <strong>MIT License</strong> © zhaojiapeng<br><br>
  <a href="https://github.com/Zhao73/codextoken/stargazers">⭐ Star this repo</a> if you find it useful!
</p>
