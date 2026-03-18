# Provider Menu Redesign Design

**Date:** 2026-03-17

## Goal

Turn CodexToken into a premium multi-provider menu bar control center with:
- `Overview / Codex / Claude / Antigravity` top navigation
- a redesigned primary panel inspired by the supplied reference UI
- real quota reads for Codex, Claude, and Antigravity when the local environment supports them
- preserved Codex multi-account workflows, including account snapshots, switching, and isolated CLI sessions

## Product Direction

Use a refined light-mode command-center aesthetic:
- warm stone background
- layered floating cards
- italic serif display headings paired with sober sans-serif system text
- strong provider color accents on selected tabs and progress fills
- premium spacing and grouped actions instead of dense utility rows

A Pencil concept mock was produced in the active editor as the visual reference for implementation.

## Information Architecture

### Tabs
- `Overview`: cross-provider summary cards and connection status
- `Codex`: primary workspace for multi-account Codex usage and account switching
- `Claude`: single-provider panel for Claude Code quota, identity, and status
- `Antigravity`: single-provider panel for Antigravity quota with Claude/Gemini model windows

### Settings shell
- The settings window becomes a sidebar-based shell mirroring the official Antigravity layout (Agent / Browser / Notifications / Models / Customizations / Tab / Editor / Account / Provide Feedback).
- `Models` is the default pane and hosts the rich quota experience, freeing the `Account` pane to keep the existing actions (refresh, settings, import session) without duplication.

### Codex panel
- provider header with account pill in the top-right
- account pill opens a popover showing all Codex accounts plus 5-hour and weekly remaining quota
- selecting an account performs a real CLI switch via `CLISwitchService`, then refreshes the menu
- dedicated actions for `Open CLI`, `Save current session`, `Refresh`, and `Settings`
- a local utilization mini-chart based on cached history instead of fake billing numbers

### Claude panel
- shows live session and weekly windows from Claude OAuth usage when credentials are available locally
- degrades cleanly to a connection-needed or unavailable state when credentials are missing or invalid
- surfaces plan tier when available

### Antigravity panel
- probes the local Antigravity language server for the full `/GetUserStatus` and `/GetCommandModelConfigs` payloads instead of just two windows.
- surfaces a `Model Credits` card reflecting prompt/flow credit balances, plan name, and the locally reported AI credit overage state (marks it as `Unknown` when the API omits the flag).
- renders every quota-aware model row (Gemini 3 Pro High/Low, Gemini Flash, Claude Sonnet/Opus, GPT-OSS 120B, etc.) with a segmented progress bar, `% remaining`, and the per-model reset countdown text.
- includes a `Refresh` control scoped to the Models pane plus footer copy explaining how to interpret the quota list, and shows status badges such as `Probing local service` or `Stale data` when the local API is warming up.
- reuses the existing diagnostic copy when Antigravity is not running or when the local language service cannot be reached.

## Architecture Changes

### Core layer
Add provider-specific services in `CodexTokenCore` for:
- Claude OAuth credential loading and usage fetch
- Antigravity local process detection and quota probing
- provider-neutral history storage primitives for charting

### App layer
Extend the menu view model with:
- provider tab selection and provider summary state
- provider refresh orchestration alongside existing Codex account refresh
- a real Codex switch action that writes `auth.json` and validates the result
- lightweight quota history sampling for the active provider/account surface

## Data Sources

### Codex
Existing `codex app-server` quota path and current local fallback remain unchanged.

### Claude
Initial implementation uses local Claude OAuth credentials read from `~/.claude/.credentials.json`, then calls the Anthropic OAuth usage endpoint.
Future enhancement can add Keychain and CLI PTY fallback, but the first shipping version stays intentionally narrow and testable.

### Antigravity
Use the local language-server probing flow:
- inspect running processes for Antigravity language server metadata
- discover listening ports with `lsof`
- probe `GetUnleashData`
- fetch `GetUserStatus` with fallback to `GetCommandModelConfigs`

## Non-Goals For This Pass
- full Claude multi-account manual token management
- web-cookie scraping for Claude
- historical billing/cost analytics from remote dashboards
- external cloud sync or telemetry

## Risks And Mitigations
- Claude credentials may be absent in some installations: show a clear local-credentials-needed state.
- Antigravity protocol can change: isolate probing logic behind a dedicated service and mark the source experimental in UI copy.
- Existing uncommitted work already adds account-import flow: preserve and integrate it instead of replacing it.
