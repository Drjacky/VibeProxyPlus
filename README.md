# VibeProxy

<p align="center">
  <img src="icon.png" width="128" height="128" alt="VibeProxy Icon">
</p>

<p align="center">
  <a href="https://github.com/Drjacky/vibeproxy/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-28a745"></a>
  <a href="https://github.com/Drjacky/vibeproxy"><img alt="GitHub" src="https://img.shields.io/github/stars/Drjacky/vibeproxy.svg?style=social&label=Star"></a>
</p>

Native macOS menu bar app that routes your existing AI subscriptions through a local OpenAI-compatible proxy (`http://localhost:8317`).

**This repo:** [Drjacky/vibeproxy](https://github.com/Drjacky/vibeproxy) - maintained fork with **Cursor provider** support and [CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) bundled. Based on [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy); see [FORK.md](FORK.md) for upstream sync notes.

---

## What is different in this fork

| Feature | Description |
|---------|-------------|
| **Cursor provider** | Use your Cursor subscription via the proxy (browser login or **Fetch Auth Locally** from Cursor IDE) |
| **CLIProxyAPIPlus** | Backend includes `-cursor-login` and Cursor API routing |
| **Fork issues** | Bug reports for Cursor and fork-only changes go to [this repo's issues](https://github.com/Drjacky/vibeproxy/issues) |

Full Cursor setup: **[CURSOR_SETUP.md](CURSOR_SETUP.md)**

---

## Supported providers

Claude Code, Codex (ChatGPT), Gemini, Kimi, Qwen, Antigravity, Z.AI GLM (API key), GitHub Copilot (where configured), **Cursor** (this fork), and custom OpenAI-compatible providers.

Use subscriptions with tools such as [Factory Droids](https://app.factory.ai/r/FM8BJHFQ), Amp, KiloCode, and any client that accepts a local OpenAI base URL.

<p align="center">
  <a href="https://www.loom.com/share/5cf54acfc55049afba725ab443dd3777"><img src="vibeproxy-factory-video.webp" width="600" height="380" alt="VibeProxy demo"></a>
</p>

### Setup guides

- [Cursor provider (fork)](CURSOR_SETUP.md)
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

Pre-built binaries for this fork are published here:

**https://github.com/Drjacky/vibeproxy/releases**

> **Signing.** CI names assets clearly: `VibeProxy-arm64-unsigned.zip` (ad-hoc) or `VibeProxy-arm64-signed.zip` if you configure Apple signing secrets. Unsigned builds need **right-click → Open** the first time.

1. Download the ZIP for your Mac from the latest release (e.g. `VibeProxy-arm64-unsigned.zip` on Apple Silicon).
2. Extract and move `VibeProxy.app` to **Applications**.
3. **Right-click** the app → **Open** → confirm **Open**.

Verify checksums when provided: `shasum -a 256 -c VibeProxy-arm64-unsigned.zip.sha256`

### Build from source

```bash
brew install git-lfs
git lfs install

git clone https://github.com/Drjacky/vibeproxy.git
cd vibeproxy
git lfs pull

make app
open VibeProxy.app
```

Same unsigned/ad-hoc behavior as CI builds. See [INSTALLATION.md](INSTALLATION.md) and [FORK.md](FORK.md#github-releases-unsigned).

### Automatic releases (maintainers)

Set repo secret **`AUTO_UPDATE_TOKEN`** (PAT) — see [FORK.md](FORK.md#automatic-pipeline-requires-auto_update_token). Then:

`update-cliproxyapi` → bump PR → `auto-release` merges and tags → `release` publishes ZIPs to [Releases](https://github.com/Drjacky/vibeproxy/releases).

### Manual tag (optional)

```bash
git tag v1.0.0-cursor.1
git push origin v1.0.0-cursor.1
```

Triggers [.github/workflows/release.yml](.github/workflows/release.yml) only.

---

## Quick start

1. Launch **VibeProxy** and open **Settings** from the menu bar.
2. Enable providers you need (including **Cursor** for this fork).
3. Authenticate:
   - **Connect** / **Add Account** for OAuth providers
   - **Fetch Auth Locally** or **Add Account** for Cursor ([CURSOR_SETUP.md](CURSOR_SETUP.md))
4. Point your tool at `http://localhost:8317/v1` with any placeholder API key (see provider setup docs).

---

## Development

### Project layout

```
vibeproxy/
├── src/
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── ServerManager.swift
│   │   ├── SettingsView.swift
│   │   ├── CursorTokenImporter.swift   # fork: Cursor local auth
│   │   ├── CursorJWTHelper.swift
│   │   ├── ForkConfig.swift
│   │   └── Resources/
│   │       ├── cli-proxy-api-plus
│   │       ├── config.yaml
│   │       └── AppIcon.icns
│   ├── Tests/
│   └── Package.swift
├── create-app-bundle.sh
├── Makefile
├── CURSOR_SETUP.md
└── FORK.md
```

### Commands

```bash
make app      # Build VibeProxy.app
make run      # Build and open
make install  # Copy to /Applications
make clean
cd src && swift test
```

### Key components

- **ServerManager** - Runs CLIProxyAPIPlus, OAuth / `-cursor-login`
- **CursorTokenImporter** - Reads Cursor IDE `state.vscdb`, writes `cursor.json`
- **AuthStatus** - Watches `~/.cli-proxy-api/`
- **ForkConfig** - Fork GitHub URLs in the app UI

---

## Credits

- [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy) - original macOS app and UI
- [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) - proxy server (Cursor and other providers)

---

## License

MIT - see [LICENSE](LICENSE).

## Support

- **Issues (this fork):** https://github.com/Drjacky/vibeproxy/issues
- **Repository:** https://github.com/Drjacky/vibeproxy
