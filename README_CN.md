<p align="center">
  <img src="docs/images/banner.png" width="88" alt="QuotaBar 图标" />
</p>

<h1 align="center">QuotaBar — macOS AI CLI 多账号管理工具</h1>

<p align="center">
  <strong>在菜单栏一键切换 Codex、Claude、Antigravity 账号。<br>实时查看额度、过期提醒、隔离会话 —— 全程无需打开终端。</strong>
</p>

<p align="center">
  <a href="README.md"><img src="https://img.shields.io/badge/English-2563eb?style=for-the-badge&logoColor=white" alt="English README" /></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/100%25_本地-无遥测-0f766e?style=for-the-badge" alt="100% 本地" />
</p>

---

## 痛点

用 **Codex CLI**、**Claude Code** 或 **Antigravity** 多账号的人都懂：

- 🔄 手动改 `~/.codex/auth.json` 才能切账号
- 🤷 不知道哪个号还有额度，撞了限速才发现
- 💀 Token 过期了没人告诉你，下一条命令直接报错
- 🧩 想给不同账号开隔离终端？自己写脚本吧

## 解决方案

**QuotaBar** 住在菜单栏里，以上全部解决：

| | 功能 | 原理 |
|---|---|---|
| ⚡ | **一键切号** | 原子交换 + 自动验证 + 失败回滚，不会搞坏当前登录态 |
| 📊 | **实时额度面板** | Codex、Claude OAuth、Antigravity 三家额度并排看 |
| 🔔 | **过期提醒** | Token 快到期就提醒，不再「突然断线」 |
| 🔒 | **隔离会话** | 每个账号独立终端，各自 `CODEX_HOME`，互不干扰 |
| 📋 | **复制分享** | 一键复制账号邮箱或额度摘要 |
| 🌍 | **7 种语言** | 英语、简中、繁中、日语、韩语、西班牙语、葡萄牙语 |
| 🛡️ | **100% 本地** | 零遥测、零云同步、零 Token 中继，密钥永远不出本机 |

## 快速开始

```bash
brew install xcodegen
git clone https://github.com/Zhao73/quotabar.git
cd codextoken
xcodegen generate
open CodexToken.xcodeproj
```

Xcode 里按 `⌘R`，QuotaBar 出现在菜单栏。

## 工作原理

```
┌────────────────────────────────────────────────────┐
│  ~/.codex/auth.json          → 当前 CLI 登录态     │
│  ~/.codex/accounts/*.json    → 已保存的账号快照     │
│  ~/.claude/.credentials.json → Claude OAuth 凭证   │
└──────────────┬─────────────────────────────────────┘
               ▼
┌──────────────────────────┐
│     QuotaBar 菜单栏       │
│                          │
│  ┌─────┬────────┬──────┐ │
│  │Codex│ Claude │ Anti │ │
│  └─────┴────────┴──────┘ │
│  • 实时额度进度条         │
│  • 账号切换器             │
│  • Token 健康监控         │
│  • 隔离 CLI 启动器        │
└──────────────────────────┘
```

**账号切换**是原子操作 —— QuotaBar 用 `codex login status` 验证目标账号，失败自动回滚。

**Token 监控**主动检查 `expiresAt` 和 API 响应，在出问题**之前**就发出警告。

## 架构

| 层 | 职责 |
| :--- | :--- |
| `CodexTokenCore` | 账号发现、CLI 切换（含回滚）、额度提供者（Codex app-server、Claude OAuth、Antigravity API） |
| `CodexTokenApp` | SwiftUI 菜单栏界面、设置、额度缓存、Terminal 启动服务 |

## 隐私与安全

- **无遥测** —— 没有任何分析 SDK
- **无云同步** —— 所有数据留在本机
- **无 Token 中继** —— API 密钥本地读取，绝不传给第三方
- **原子文件操作** —— 切账号使用原子写入 + 回滚

详见 [PRIVACY.md](PRIVACY.md) 和 [SECURITY.md](SECURITY.md)。

## 参与贡献

欢迎 PR。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<p align="center">
  <strong>QuotaBar</strong> by <a href="https://github.com/Zhao73">Zhao73</a><br>
  <sub>如果它帮你省下了一次「怎么又断线了」的抓狂，考虑点个 ⭐</sub>
</p>
