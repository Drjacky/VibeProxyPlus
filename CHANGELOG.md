# Changelog

All notable changes to **VibeProxyPlus** are documented in this file.

## [Unreleased]

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
