<p align="center">
  <img src="docs/images/banner.png" width="600" />
</p>

<h1 align="center">CodexToken</h1>

<p align="center">
  <strong>Codex CLI 的多账号管理器。</strong><br>
  切换账号。监控额度。启动隔离会话。都在菜单栏完成。
</p>

<p align="center">
  <a href="#安装"><img src="https://img.shields.io/badge/-安装-28a745?style=for-the-badge&logoColor=white" /></a>
  <a href="#功能"><img src="https://img.shields.io/badge/-功能-0366d6?style=for-the-badge&logoColor=white" /></a>
  <a href="#架构"><img src="https://img.shields.io/badge/-架构-6f42c1?style=for-the-badge&logoColor=white" /></a>
  <a href="README.md"><img src="https://img.shields.io/badge/-English-e36209?style=for-the-badge&logoColor=white" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS_14+-111?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/依赖-0-brightgreen?style=flat-square" />
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

## 痛点

你有多个 OpenAI / Codex 账号——个人的、工作的、测试 Key。每次切换都要手动改 `~/.codex/auth.json`，搞不清当前激活的是哪个账号，没法对比额度，还怕覆盖错 token。

**CodexToken 一键解决。**

---

## 功能

<table>
<tr>
<td width="50%">

### 🔍 自动发现
自动扫描 `~/.codex/accounts/` 和 `auth.json`。按 `account_id` 合并重复项。从 JWT claims 提取邮箱和登录方式——零配置。

### ⚡ 一键切换
选中账号，点击切换。CodexToken 把快照复制到 `auth.json`，通过 `codex login status` 验证，失败时 **自动回滚**。

### 📊 额度监控
组合式 Provider 链：Codex App Server → 自定义 Shell 命令 → 本地兜底。显示 5 小时和每周窗口及置信度。

### 🏷️ 账号元数据
自定义显示名、备注、拖拽排序。存在独立的本地 JSON 里——完全不碰你的 auth 文件。

</td>
<td width="50%">

### 🖥️ 隔离 Terminal 会话
"打开 CLI"会创建独立的 Terminal 窗口，拥有自己的 `CODEX_HOME`。**同时运行多个 Codex 实例**，各自用不同的账号。

### 📸 会话快照
把当前 `auth.json` 保存为命名快照。删除或隐藏不需要的账号。支持从登录流程导入。

### 🗣️ Siri 快捷指令
三个 AppIntent：保存会话、打开 `.codex` 文件夹、定位 `auth.json`。支持快捷指令 App 和语音。

### 🌐 双语界面
完整的 English & 简体中文 UI，运行时即时切换——无需重启。

</td>
</tr>
</table>

---

## 安装

> **环境要求：** macOS 14+，[XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.38+，Xcode（Swift 6）

```bash
# 安装 XcodeGen（一次性）
brew install xcodegen

# 克隆 & 构建
git clone https://github.com/Zhao73/codextoken.git
cd codextoken
xcodegen generate
open CodexToken.xcodeproj
# ⌘R → 应用出现在菜单栏（无 Dock 图标）
```

<details>
<summary><strong>运行测试</strong></summary>

```bash
xcodebuild test \
  -project CodexToken.xcodeproj \
  -scheme CodexTokenCore \
  -destination 'platform=macOS'
```
</details>

---

## 工作原理

```
┌─────────────────┐     ┌──────────────────────────┐
│    菜单栏         │────▶│  AccountDiscoveryService  │
│  CodexToken ⌘   │     │  扫描 ~/.codex/accounts/  │
└────────┬────────┘     │  解析 JWT claims          │
         │              └──────────────────────────┘
         │
         ├── 切换 ──▶ CLISwitchService
         │            ├─ 备份 auth.json
         │            ├─ 写入新 token
         │            ├─ 验证 (codex login status)
         │            └─ 失败自动回滚 ↩
         │
         ├── 打开 CLI ──▶ CLIProfilePreparationService
         │                ├─ 创建隔离的 CODEX_HOME
         │                └─ 启动 Terminal + 环境变量
         │
         └── 额度 ──▶ CompositeQuotaProvider
                      ├─ CodexAppServerQuotaProvider (HTTPS)
                      ├─ ExperimentalQuotaProvider (Shell 命令)
                      └─ LocalStateQuotaProvider (兜底)
```

### 数据文件

所有数据都在本机 `~/.codex/` 下——**不会离开你的电脑**。

| 文件 | 归属 | 内容 |
|:-----|:-----|:-----|
| `auth.json` | Codex CLI | 当前会话 token |
| `accounts/*.json` | CodexToken | 保存的会话快照 |
| `codex-token-metadata.json` | CodexToken | 显示名、备注、排序 |
| `config.toml` | Codex CLI | CLI 配置（复制到隔离环境） |

---

## 架构

```
Sources/
├── CodexTokenCore/                    # ← 可测试框架，无 UI 依赖
│   ├── Infrastructure/
│   │   └── FileSystem.swift           #   协议 + InMemoryFileSystem
│   ├── Models/
│   │   ├── CodexAccount.swift         #   id, email, authMode, lastRefresh…
│   │   ├── QuotaSnapshot.swift        #   status, windows, confidence
│   │   ├── CodexPaths.swift           #   ~/.codex 路径常量
│   │   └── AccountMetadata.swift      #   name, remark, sort, hidden
│   └── Services/
│       ├── AccountDiscoveryService    #   扫描 + 合并 + 排序
│       ├── CLISwitchService           #   原子交换 + 回滚
│       ├── CLIProfilePreparation…     #   按账号隔离 CODEX_HOME
│       ├── AccountSnapshotImport/…    #   快照生命周期
│       ├── AccountMetadataStore       #   元数据增删改查
│       └── Quota/
│           ├── QuotaProviding         #   协议 + 组合链
│           ├── CodexAppServerQuota…   #   HTTPS → openai.com
│           ├── ExperimentalQuota…     #   用户自定义 Shell 命令
│           └── LocalStateQuota…       #   离线兜底
│
└── CodexTokenApp/                     # ← SwiftUI 菜单栏应用
    ├── CodexTokenApp.swift            #   @main MenuBarExtra
    ├── CodexTokenMenuView/ViewModel   #   账号卡片 + 业务逻辑
    ├── CodexTokenSettingsView         #   设置窗口
    ├── CodexTokenAppIntents           #   Siri 快捷指令
    ├── AppPreferences                 #   语言 & 功能开关
    ├── TerminalCLILaunchService       #   launch.command 生成
    └── CLILaunchRecordStore /
        QuotaSnapshotCacheStore        #   本地缓存
```

### 设计要点

| 原则 | 实现 |
|:-----|:-----|
| **可测试性** | 所有 Service 接受 `FileSystem` 协议，测试用 `InMemoryFileSystem`——无真实磁盘 I/O |
| **组合式额度** | `QuotaProviding` Provider 链，第一个返回 `.available` / `.experimental` 的胜出 |
| **CODEX_HOME 隔离** | "打开 CLI"创建临时目录 + 自己的 `.codex/auth.json` + `CODEX_HOME` 环境变量 |
| **原子切换** | `CLISwitchService`：备份 → 覆写 → 验证 → 失败回滚 |
| **零依赖** | 纯 Swift 6 + SwiftUI + AppKit。无 SPM、无 CocoaPods、无 Carthage |

---

## 隐私与安全

> **简而言之：** CodexToken 不会把你的数据发送到任何地方。一切都在 `~/.codex/`。

- 📄 [隐私政策](PRIVACY.md) — 收集什么（什么也不收集）、数据位置、实验性功能
- 🔒 [安全政策](SECURITY.md) — Token 处理、原子切换、隔离环境

---

## 贡献

欢迎 Bug 修复、测试覆盖、文档和国际化改进。请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<p align="center">
  <strong>MIT License</strong> © zhaojiapeng<br><br>
  <a href="https://github.com/Zhao73/codextoken/stargazers">⭐ 觉得有用就 Star 一下吧！</a>
</p>
