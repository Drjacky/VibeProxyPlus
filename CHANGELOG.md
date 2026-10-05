# Changelog

All notable changes to **VibeProxyPlus** are documented in this file.

## [Unreleased]

## [14.10.1] - 2026-10-05

### Fixed

- **Newer Claude models (e.g. Opus 5.5) work from Cline, Kilo Code and other OpenAI-compatible clients.** The CLIProxyAPIPlus engine reported Claude Code 2.1.258 for requests from clients that are not Claude Code, and Anthropic rejected models that need 2.1.280 or newer ("Claude Code 2.1.258 does not support this model"). The app now sets `claude-header-defaults` to Claude Code 2.1.280 and raises an older value in an existing `merged-config.yaml` on launch; a newer value you set yourself is kept. Updating the Claude Code CLI on the machine had no effect because requests never go through it.
- **Qwen login shows a clear message.** The bundled CLIProxyAPIPlus has no Qwen login command, so Connect failed with a raw "flag provided but not defined" error. The app now checks which login commands the engine provides and explains when one is unavailable.
- Orphaned engine cleanup no longer kills the app's own launch-time capability check.
- The server log shows the backend port (8318) instead of the proxy port.

### Security

- **The proxy on port 8317 accepts connections from this Mac only by default.** It used to listen on all network interfaces. Turn on **Allow LAN connections** in Settings to use it from other devices on your network.
- Logs no longer include credential file paths, account emails, request paths, login command arguments or login output.
- The main app executable is signed with its entitlements, like the bundled engine binaries.
- Signed release DMGs are notarized and stapled when Apple notarization credentials are configured.

### Updated

- **Dario 6.12.25** - [askalf/dario](https://github.com/askalf/dario/releases/tag/v6.12.25). Tracks Claude Code 2.1.289 (current Sonnet 5 system prompt, SDK package version 0.128.0).

## [14.10.0] - 2026-10-03

### Added

- **Global Claude cloak mode.** A new control in the Claude section of settings sets the cloak mode (Auto, Always, Never) for all Claude accounts, along with strict mode, sensitive words, and cached user id. The choice is remembered and defaults to Auto. Settings are written into each Claude OAuth auth file so they apply without a `claude-api-key` config entry.

### Fixed

- **Check for Updates now finds new releases.** The update feed was never populated, so the app always reported it was up to date. Published releases are now signed and added to the feed automatically. Installs older than 14.10.0 lack the update signing key and must download 14.10.0 manually once; later updates install from the app.
- The Dario proxy is now launched with `--port=PORT --host=ADDRESS` flags. Dario 6 rejects the space-separated form and refused to start.

### Updated

- **CLIProxyAPIPlus 7.3.12-1** - [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus/releases/tag/v7.3.12-1). Claude OAuth credentials honor cloak settings from the auth-file metadata (nonblank attributes first, string metadata as fallback), enabling per-credential cloak configuration for OAuth/token accounts ([#123](https://github.com/kaitranntt/CLIProxyAPIPlus/issues/123)).
- **Dario 6.12.23** - [askalf/dario](https://github.com/askalf/dario/releases/tag/v6.12.23). New major version; `dario proxy` now accepts flags only in `--key=value` form.

## [14.9.2] - 2026-06-27

### Updated

- **CLIProxyAPIPlus 7.1.68-6** - [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus/releases/tag/v7.1.68-6). Provider-side fixes for Qoder usage accounting and Kiro (cache usage fields, fallback models, IDE import normalization, raw IDE token imports).
- **Dario 4.8.101** - [askalf/dario](https://github.com/askalf/dario/releases/tag/v4.8.101). Tracks Claude Code v2.1.195 with refreshed wire-fidelity templates, and adds correctness fixes: advertise only client-declared tools, broaden the overage guard to all non-subscription billing claims, deterministic billing-tag (`cch`) anchoring, and preserve interactive-only tools across template rebakes.

## [14.9.1] - 2026-06-14

### Fixed

- Prevented a rare loss of `~/.cli-proxy-api/merged-config.yaml`. If the existing file was present but could not be parsed (for example a malformed manual edit, or a partial write while the management dashboard was saving), the app would silently overwrite it with a freshly composed config, discarding custom settings, secrets, and dashboard edits. The app now refuses to overwrite an unparseable merged-config.yaml and surfaces an error directing you to fix the file or use Reset Config.

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

[Unreleased]: https://github.com/Drjacky/vibeproxyplus/compare/v14.9.2...HEAD
[14.9.2]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.9.2
[14.9.1]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.9.1
[14.9.0]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.9.0
[14.8.170]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v14.8.170
[10.8.170]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.170
[10.8.169]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.169
[10.8.162]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.162
