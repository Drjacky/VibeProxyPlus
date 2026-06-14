# Changelog

All notable changes to **VibeProxyPlus** are documented in this file.

## [Unreleased]

## [14.9.0] - 2026-06-14

### Updated

- **CLIProxyAPIPlus 7.1.68-2** - [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus/releases/tag/v7.1.68-2). Adds newly verified models, post-auth request interceptors and a JavaScript plugin host, deduplicated concurrent token refresh, and streaming/translator fixes for Codex, Claude, Gemini, and Antigravity.
- **Dario 4.8.74** - [askalf/dario](https://github.com/askalf/dario/releases/tag/v4.8.74). The public `/health` endpoint no longer exposes OAuth internals to external callers; loopback callers (the app's readiness probe) still receive full detail.

### Fixed

- Dario login no longer hangs. `dario login` now starts the proxy as a side effect when valid credentials already exist; the app now passes `--no-proxy` so login only authenticates and exits cleanly, leaving proxy lifecycle to the app.
- `scripts/fetch-cliproxy-plus.sh` and the release workflow now match the upstream `_no-plugin` darwin asset naming (the suffix is matched optionally, so older un-suffixed assets still resolve).

## [14.8.170] - 2026-06-02

### Added

- **Dario engine.** VibeProxyPlus now bundles a second, fully independent proxy engine based on [askalf/dario](https://github.com/askalf/dario) alongside the existing CLIProxyAPIPlus engine.
- **Secret redaction in logs.** All logged lines (including engine subprocess output) are scrubbed of API keys, bearer tokens, JWTs, and access/refresh tokens before reaching the log buffer or diagnostics.
- **Crash safe-mode.** After an abnormal prior exit the app offers to start with the engine stopped so you can review settings before re-engaging.
- **Supply-chain checksums.** Engine fetch scripts record a SHA-256 of each bundled binary.

## [10.8.170] - 2026-05-30

### Added

- "Reset Config" button in Settings (with a confirmation dialog explaining the consequences) that rebuilds `merged-config.yaml` from the bundled defaults, your `config.yaml`, enabled providers, and stored API keys. Restarts the server if running.

### Fixed

- Stop/start the server or quit/reopen the app no longer overwrites `merged-config.yaml`. After the first run the existing file is treated as the source of truth and only the app-managed sections (`openai-compatibility`, `oauth-excluded-models`) are overlaid from provider toggles and stored keys, so all custom settings, secrets, and edits made directly or via the management dashboard are preserved across restarts.
- The local `scripts/fetch-cliproxy-plus.sh` now always targets the latest upstream CLIProxyAPIPlus release (including prereleases) and re-downloads when a newer version is available, keeping `cli-proxy-api-plus.version` in sync.

## [10.8.169] - 2026-05-30

### Changed

- Cursor tokens are no longer imported automatically. Importing now happens only when you press **Add Account** or **Fetch Auth Locally**, so deleting `cursor.json` (via the menu or manually) stays deleted across app restarts.

### Fixed

- `make app` now builds locally without `TARGET_ARCH` set and without a Developer ID certificate.

## [10.8.162] - 2026-05-24

### Added

- Initial Drjacky release with **CLIProxyAPIPlus** backend and Cursor provider.

[Unreleased]: https://github.com/Drjacky/vibeproxyplus/compare/v14.9.0...HEAD
[14.9.0]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.9.0
[14.8.170]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.8.170
[10.8.170]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.170
[10.8.169]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.169
[10.8.162]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.162
