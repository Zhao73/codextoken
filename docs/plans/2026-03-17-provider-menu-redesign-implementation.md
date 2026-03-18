# Provider Menu Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship a premium multi-provider menu UI with real Codex, Claude, and Antigravity quota surfaces while preserving Codex multi-account workflows.

**Architecture:** Keep Codex account management as the primary domain model, add focused provider services for Claude and Antigravity in `CodexTokenCore`, and upgrade the SwiftUI menu to render per-provider control-center panels from one view model. Use local history snapshots for the chart panel and route Codex account selection through the real CLI switch service.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, URLSession, Process-based local probing, XCTest.

---

### Task 1: Add failing tests for new provider services

**Files:**
- Create: `Tests/CodexTokenCoreTests/ClaudeOAuthCredentialStoreTests.swift`
- Create: `Tests/CodexTokenCoreTests/ClaudeOAuthQuotaProviderTests.swift`
- Create: `Tests/CodexTokenCoreTests/AntigravityQuotaProviderTests.swift`

**Step 1: Write failing tests**
- Cover Claude credential parsing from a `.credentials.json` fixture.
- Cover Claude OAuth usage response mapping to 5-hour and weekly `QuotaSnapshot` windows.
- Cover Antigravity process parsing, port parsing, and quota response mapping.

**Step 2: Run tests to verify failures**
Run: `xcodebuild test -project CodexToken.xcodeproj -scheme CodexTokenCore -destination 'platform=macOS' -only-testing:CodexTokenCoreTests/ClaudeOAuthCredentialStoreTests -only-testing:CodexTokenCoreTests/ClaudeOAuthQuotaProviderTests -only-testing:CodexTokenCoreTests/AntigravityQuotaProviderTests`
Expected: failing tests because the new types do not exist yet.

### Task 2: Implement Claude provider primitives

**Files:**
- Create: `Sources/CodexTokenCore/Services/Quota/ClaudeOAuthCredentialStore.swift`
- Create: `Sources/CodexTokenCore/Services/Quota/ClaudeOAuthQuotaProvider.swift`

**Step 1: Implement minimal credential loader**
- Read `~/.claude/.credentials.json`.
- Parse access token, expiry, scopes, and rate-limit tier.
- Keep the implementation file-based for now.

**Step 2: Implement OAuth usage fetcher**
- Call `GET https://api.anthropic.com/api/oauth/usage`.
- Map `five_hour` and `seven_day` windows into `QuotaSnapshot`.
- Add plan metadata to warnings for UI reuse.

**Step 3: Run the new tests**
Run the Task 1 command again.
Expected: Claude tests pass.

### Task 3: Implement Antigravity provider primitives

**Files:**
- Create: `Sources/CodexTokenCore/Services/Quota/AntigravityQuotaProvider.swift`

**Step 1: Implement local probe**
- Detect Antigravity process metadata from `ps` output.
- Parse listening ports from `lsof` output.
- Probe HTTPS first, HTTP fallback second.
- Map the best two model quotas into `QuotaSnapshot` windows.

**Step 2: Run the new tests**
Run the Task 1 command again.
Expected: Antigravity tests pass.

### Task 4: Add provider-facing app models and history storage

**Files:**
- Create: `Sources/CodexTokenApp/ProviderSurfaceModels.swift`
- Create: `Sources/CodexTokenApp/QuotaHistoryStore.swift`
- Modify: `Sources/CodexTokenApp/CodexTokenMenuViewModel.swift`

**Step 1: Add failing coverage if needed through core-friendly helpers**
- Prefer unit-testable pure helpers for chart/history aggregation.

**Step 2: Implement provider summary state**
- Add provider kinds, provider cards, and provider panel summaries.
- Record time-series history for visible quota snapshots.
- Fix Codex account selection so choosing an account can invoke `CLISwitchService`.

### Task 5: Rebuild the SwiftUI menu into the new premium layout

**Files:**
- Modify: `Sources/CodexTokenApp/CodexTokenMenuView.swift`
- Modify: `Resources/en.lproj/Localizable.strings`
- Modify: `Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Replace the current flat sections with card-based provider panels**
- Add provider tabs: Overview, Codex, Claude, Antigravity.
- Redesign hero/header, progress cards, action shelf, and utilization chart.
- Add the Antigravity tab content that mirrors the Models pane: a `Model Credits` card, AI credit overage status, and the per-model quota list with segmented progress bars and countdown text.
- Expand the Codex account popover to show both 5-hour and weekly quota.

**Step 2: Restore all existing Codex workflows**
- Keep refresh, add account, import session, delete, settings, and isolated CLI launch accessible.

**Step 3: Verify visual and behavioral states**
- Empty, loading, connected, error, and unavailable states must all render clearly.

### Task 6: Wire settings and validation

**Files:**
- Modify: `Sources/CodexTokenApp/CodexTokenSettingsView.swift`
- Modify: `project.yml` if new files require regeneration
- Modify: `CodexToken.xcodeproj/project.pbxproj` only if project structure demands it

**Step 1: Rebuild settings into a sidebar shell with a dedicated Models pane**
- Implement the sidebar navigation (Agent/Browser/Notifications/Models/Customizations/Tab/Editor/Account/Provide Feedback) and keep Codex account actions inside the Account pane.
- The Models pane hosts the Antigravity `Model Credits` card, listed quotas, refresh action, footer copy, and status hints (`Probing local service`, `Stale data`).
- Leave the existing provider diagnostic list in place as a fallback for non-Models panes.

**Step 2: Run the full core test suite**
Run: `xcodebuild test -project CodexToken.xcodeproj -scheme CodexTokenCore -destination 'platform=macOS'`
Expected: full green core suite.

**Step 3: Build the app target**
Run: `xcodebuild build -project CodexToken.xcodeproj -scheme CodexToken -destination 'platform=macOS'`
Expected: successful app build.
