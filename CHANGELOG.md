# Changelog

All notable changes to **VibeProxyPlus** are documented in this file.

## [Unreleased]

## [10.8.169] - 2026-05-30

### Changed

- Cursor tokens are no longer imported automatically. Importing now happens only when you press **Add Account** or **Fetch Auth Locally**, so deleting `cursor.json` (via the menu or manually) stays deleted across app restarts.

### Fixed

- `make app` now builds locally without `TARGET_ARCH` set and without a Developer ID certificate.

## [10.8.162] - 2026-05-24

### Added

- Initial Drjacky release with **CLIProxyAPIPlus** backend and Cursor provider.

[Unreleased]: https://github.com/Drjacky/vibeproxyplus/compare/v10.8.162...HEAD
[10.8.162]: https://github.com/Drjacky/vibeproxyplus/releases/tag/v10.8.162
