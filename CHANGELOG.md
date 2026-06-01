# Changelog

All notable changes to **VibeProxyPlus** are documented in this file.

## [Unreleased]

### Added

- **Dario engine.** VibeProxyPlus now bundles a second, fully independent proxy engine based on [askalf/dario](https://github.com/askalf/dario) alongside the existing CLIProxyAPIPlus engine. Switch between them from the menu bar ("Switch to Dario Engine" / "Switch to cliproxyapiplus Engine"); switching shows a confirmation dialog, cleanly stops the running engine, and relaunches into the selected one. The choice persists across launches. The engines are fully isolated (separate config homes `~/.cli-proxy-api/` and `~/.dario/`, settings, credential storage, and process lifecycles). In Dario mode the app behaves as a dedicated Dario client.
- **Dario authentication options.** Dario settings offer two independent ways to authenticate: **Subscription (OAuth)** - a Login/Re-login button that opens the browser to authenticate a Claude Pro/Max subscription and uses Dario's full Claude-Code stealth/fingerprint upstream; and **API key + base URL** - a "Set API key..." action plus a "Use API key" toggle that configures a custom base URL + API key (stored in the Keychain) and registers it as Dario's OpenAI-compatible backend on demand (no subscription needed). The API-key path is a plain pass-through and does not apply the Claude-Code stealth. The proxy status dot reflects auth state: green when the subscription is logged in (stealth), yellow when only the API key is enabled (works, no stealth), red when neither is configured.
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

[Unreleased]: https://github.com/Drjacky/vibeproxyplus/compare/v10.8.170...HEAD
[10.8.170]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.170
[10.8.169]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.169
[10.8.162]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.162
