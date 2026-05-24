# VibeProxyPlus

<p align="center">
  <img src="icon.png" width="256" height="256" alt="VibeProxyPlus icon">
</p>

<p align="center">
  <a href="https://github.com/Drjacky/VibeProxyPlus/actions"><img src="https://github.com/Drjacky/VibeProxyPlus/workflows/Build/badge.svg" alt="Build"></a>
  <a href="https://github.com/Drjacky/vibeproxyplus/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-28a745"></a>
  <a href="https://github.com/Drjacky/vibeproxyplus"><img alt="GitHub" src="https://img.shields.io/github/stars/Drjacky/vibeproxyplus.svg?style=social&label=Star"></a>
</p>

Native macOS menu bar app that routes your existing AI subscriptions through a local OpenAI-compatible proxy (`http://localhost:8317`).

**VibeProxyPlus** is built on top of the open-source [VibeProxy](https://github.com/automazeio/vibeproxy) macOS UI and uses [CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus), an excellent unified proxy server for AI services with support for third-party providers.

Pre-built apps: **[Releases](https://github.com/Drjacky/vibeproxyplus/releases)**

---

## Supported providers

Claude Code, Codex (ChatGPT), Gemini, Kimi, Qwen, Antigravity, Z.AI GLM (API key), GitHub Copilot (where configured), **Cursor**, and custom OpenAI-compatible providers.

Use subscriptions with tools such as [Factory Droids](https://app.factory.ai/r/FM8BJHFQ), Amp, KiloCode, and any client that accepts a local OpenAI base URL.

<p align="center">
  <a href="https://www.loom.com/share/5cf54acfc55049afba725ab443dd3777"><img src="vibeproxyplus-factory-video.webp" width="600" height="380" alt="VibeProxyPlus demo"></a>
</p>

### Setup guides

- [Cursor provider](CURSOR_SETUP.md)
- [Factory CLI](FACTORY_SETUP.md)
- [Amp CLI](AMPCODE_SETUP.md)

---

## Features

- Native SwiftUI menu bar app (macOS 13+)
- One-click server start/stop; credentials in `~/.cli-proxy-api/`
- OAuth for Codex, Claude, Gemini, Kimi, Qwen, Antigravity; API key for Z.AI GLM
- **Cursor:** Add Account (PKCE) or Fetch Auth Locally from Cursor IDE `state.vscdb`
- Multi-account per provider with round-robin and failover
- Provider enable/disable with hot reload
- Vercel AI Gateway option for Claude (see settings)
- Self-contained `.app` (CLI binary, config, assets)

---

## Installation

**Requirements:** macOS 13+ on Apple Silicon (M1/M2/M3/M4). Intel ZIPs may be published but are best-effort.

### Download from GitHub Releases (recommended)

**https://github.com/Drjacky/vibeproxyplus/releases**

> **Signing.** Filenames use `VibeProxyPlus-arm64-unsigned.zip` (ad-hoc) or `VibeProxyPlus-arm64-signed.zip` when Apple signing secrets are configured. Unsigned builds need **right-click → Open** the first time.

1. Download the ZIP for your Mac from the latest release.
2. Extract and move `VibeProxyPlus.app` to **Applications**.
3. **Right-click** the app → **Open** → confirm **Open**.

Verify checksums: `shasum -a 256 -c VibeProxyPlus-arm64-unsigned.zip.sha256`

More detail: [INSTALLATION.md](INSTALLATION.md)

### Build from source

```bash
git clone https://github.com/Drjacky/vibeproxyplus.git
cd vibeproxyplus
make app    # downloads cli-proxy-api-plus automatically
open VibeProxyPlus.app
```

Requires `curl` and `jq` (or run `./scripts/fetch-cliproxy-plus.sh` first).

Regenerate `AppIcon.icns` after editing `icon.png`: `make icon`

---

## Quick start

1. Launch **VibeProxyPlus** and open **Settings** from the menu bar.
2. Enable the providers you need.
3. Authenticate:
   - **Connect** / **Add Account** for OAuth providers
   - **Fetch Auth Locally** or **Add Account** for Cursor ([CURSOR_SETUP.md](CURSOR_SETUP.md))
4. Point your tool at `http://localhost:8317/v1` with any placeholder API key (see provider setup docs).

---

## Development

### Project layout

```
vibeproxyplus/
├── src/
│   ├── Sources/
│   │   ├── CursorTokenImporter.swift
│   │   ├── ForkConfig.swift
│   │   └── Resources/cli-proxy-api-plus.version
│   └── Package.swift
├── appcast.xml              # Sparkle feed (arm64); empty until you ship releases
├── scripts/fetch-cliproxy-plus.sh
├── scripts/generate-app-icon.sh
├── create-app-bundle.sh
└── Makefile
```

### Commands

```bash
make icon     # Build AppIcon.icns from icon.png
make app      # Build VibeProxyPlus.app
make run      # Build and open
make install  # Copy to /Applications
make clean
cd src && swift test
```

The ~50MB `cli-proxy-api-plus` binary is **not in git** (fetched at build time). See `scripts/fetch-cliproxy-plus.sh` and `cli-proxy-api-plus.version`.

App version: edit `src/Info.plist` (`CFBundleShortVersionString` and `CFBundleVersion`), or pass `APP_VERSION` when building.

---

## GitHub Releases and CI

| Workflow                                 | Purpose                                     |
|------------------------------------------|---------------------------------------------|
| [Build](.github/workflows/build.yml)     | `swift build` + tests on push/PR            |
| [release](.github/workflows/release.yml) | Tagged `v*` → ZIP artifacts on **Releases** |


---

## Credits

- [VibeProxyPlus](https://github.com/automazeio/vibeproxyplus) - original macOS menu bar app
- [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) - unified proxy server (Cursor and other providers)

---

## License

MIT - see [LICENSE](LICENSE).

## Support

- **Issues:** https://github.com/Drjacky/vibeproxyplus/issues
- **Repository:** https://github.com/Drjacky/vibeproxyplus
