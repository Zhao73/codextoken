<p align="center">
  <img src="docs/images/banner.png" width="88" alt="QuotaBar icon" />
</p>

<h1 align="center">QuotaBar — AI CLI Account Manager for macOS</h1>

<p align="center">
  <strong>Switch between Codex, Claude & Antigravity accounts from your menu bar.<br>See real-time quota, get expiry alerts, launch isolated sessions — all without touching a terminal.</strong>
</p>

<p align="center">
  <a href="README_CN.md"><img src="https://img.shields.io/badge/中文文档-2563eb?style=for-the-badge&logoColor=white" alt="Chinese README" /></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/100%25_Local-No_Telemetry-0f766e?style=for-the-badge" alt="100% Local" />
</p>

---

## The Problem

If you use **Codex CLI**, **Claude Code**, or **Antigravity** with multiple accounts, you know the pain:

- 🔄 Manually editing `~/.codex/auth.json` to switch accounts
- 🤷 No idea which account has quota left until you hit a rate limit
- 💀 Sessions silently expire — you only find out when your next command fails
- 🧩 No way to run isolated CLI sessions per-account without scripting it yourself

## The Solution

**QuotaBar** lives in your macOS menu bar and fixes all of this:

| | Feature | How it works |
|---|---|---|
| ⚡ | **One-click account switch** | Swap the active CLI identity with validation and automatic rollback on failure |
| 📊 | **Live quota dashboard** | See 5-hour and weekly rate limits for Codex, Claude OAuth, and Antigravity side by side |
| 🔔 | **Expiry alerts** | Get warned before tokens expire — never hit a surprise "not logged in" again |
| 🔒 | **Isolated sessions** | Launch per-account terminal shells, each with its own `CODEX_HOME` |
| 📋 | **Copy & share** | One-click copy account email or quota summary to clipboard |
| 🌍 | **7 languages** | English, 简体中文, 繁體中文, 日本語, 한국어, Español, Português |
| 🛡️ | **100% local** | Zero telemetry, zero cloud sync, zero token relay. Your keys never leave your machine |

## Quick Start

```bash
brew install xcodegen
git clone https://github.com/Zhao73/quotabar.git
cd codextoken
xcodegen generate
open CodexToken.xcodeproj
```

Press `⌘R` in Xcode. QuotaBar appears in your menu bar.

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  ~/.codex/auth.json          → Active CLI session   │
│  ~/.codex/accounts/*.json    → Saved account pool   │
│  ~/.claude/.credentials.json → Claude OAuth tokens  │
└──────────────┬──────────────────────────────────────┘
               ▼
┌──────────────────────────┐
│     QuotaBar Menu Bar    │
│                          │
│  ┌─────┬────────┬──────┐ │
│  │Codex│ Claude │ Anti │ │
│  └─────┴────────┴──────┘ │
│  • Live quota bars       │
│  • Account switcher      │
│  • Token health monitor  │
│  • Isolated CLI launcher │
└──────────────────────────┘
```

**Account switching** is atomic — QuotaBar validates the target account with `codex login status` and rolls back automatically if the switch fails.

**Token monitoring** checks `expiresAt` fields and API responses proactively. You see warnings *before* things break, not after.

## Architecture

| Layer | What it does |
| :--- | :--- |
| `CodexTokenCore` | Account discovery, CLI switching with rollback, quota providers (Codex app-server, Claude OAuth, Antigravity API) |
| `CodexTokenApp` | SwiftUI menu bar UI, settings, quota caching, Terminal launch service |

<details>
<summary><strong>Run tests</strong></summary>

```bash
xcodebuild test \
  -project CodexToken.xcodeproj \
  -scheme CodexTokenCore \
  -destination 'platform=macOS'
```

</details>

## Privacy & Security

- **No telemetry** — no analytics SDK, no usage tracking
- **No cloud sync** — all data stays on your Mac
- **No token relay** — API keys are read locally, never transmitted to third parties
- **Atomic file operations** — account switches use atomic writes with rollback

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md) for details.

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

<p align="center">
  <strong>QuotaBar</strong> by <a href="https://github.com/Zhao73">Zhao73</a><br>
  <sub>If this saves you from one more "not logged in" surprise, consider giving it a ⭐</sub>
</p>
