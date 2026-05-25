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

VibeProxyPlus connects the AI subscriptions you already pay for to a single local endpoint (`http://localhost:8317/v1`). Enable only the providers you need in Settings.

**Built-in providers**

- **Claude Code** (OAuth)
- **Codex / ChatGPT** (OAuth)
- **Gemini** (OAuth)
- **Kimi** (OAuth)
- **Qwen** (OAuth)
- **Antigravity** (OAuth)
- **Z.AI GLM** (API key)
- **GitHub Copilot** (OAuth, when configured)
- **Cursor** (OAuth or local token import from Cursor IDE)
- **Custom providers** (OpenAI-compatible endpoints you define)

<p align="center">
  <img src="demo/vibeproxyplus-demo.png" width="600" alt="VibeProxyPlus demo"></a>
</p>

---

## Features

- Native SwiftUI **menu bar app** (macOS 13+); server starts automatically on launch
- Local OpenAI-compatible API at **`http://localhost:8317/v1`** (ThinkingProxy in front of CLIProxyAPIPlus on port 8318)
- Start/stop from the menu bar or Settings; credentials stored in `~/.cli-proxy-api/`
- **OAuth:** Claude Code, Codex (ChatGPT), Gemini, Kimi, Qwen, Antigravity, GitHub Copilot, Cursor
- **API key:** Z.AI GLM (and custom providers via `openai-compatibility` in config)
- **Cursor:** browser login (PKCE) or **Fetch Auth Locally** from Cursor IDE `state.vscdb`, with optional auto-import when tokens change
- **Custom providers:** add OpenAI-compatible endpoints from `config.yaml` (display name, models, API keys in app or config)
- **Multi-account** per provider: round-robin, failover, and per-account enable/disable
- **Provider toggles** in Settings with hot reload (no restart required)
- **Vercel AI Gateway** for Claude (optional; configure in Settings)
- **Launch at login** toggle
- **Check for Updates** via Sparkle (manual; automatic checks off until you configure `appcast.xml` and signing)
- Self-contained `.app` (CLIProxyAPIPlus binary, config, icons, Sparkle)

---

## Installation

**Requirements:** macOS 13 or later.

- **Apple Silicon (recommended):** any Mac with Apple silicon (M1 and newer, including M5). Download `VibeProxyPlus-arm64-*.zip`.
- **Intel Macs:** an `x86_64` build may be attached to releases when CI produces it. Those builds are not tested on every release; use Apple Silicon if you can.

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
   - **Fetch Auth Locally** or **Add Account** for Cursor
4. Point your tool at `http://localhost:8317/v1` with any placeholder API key.

---

## Development

### Project layout

```
vibeproxyplus/
├── src/
│   ├── Sources/
│   │   ├── CursorTokenImporter.swift
│   │   ├── AppConfig.swift
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

| Workflow                                           | When it runs      | What it does                                 |
|----------------------------------------------------|-------------------|----------------------------------------------|
| [Build](.github/workflows/build.yml)               | Push/PR to `main` | Compile + tests only (no release)            |
| [Build and Release](.github/workflows/release.yml) | See below         | Build ZIP/DMG and attach to a GitHub Release |

**Pushing commits to `main` does not create a release.**

### Option A: Draft release on GitHub (recommended)

1. **Releases** → **Draft a new release**
2. Create tag `v10.8.163` (or your version) on the commit you want
3. Leave **Set as a pre-release** off, keep **This is a draft release** checked
4. Click **Save draft** (do not publish yet)
5. **Actions** runs **Build and Release** automatically and uploads ZIP/DMG to that draft
6. Review assets on the draft, then **Publish release** when ready

Use tag names like `v10.8.162` (must start with `v`).

### Option B: Run workflow manually

1. **Actions** → **Build and Release** → **Run workflow**
2. **version:** e.g. `10.8.163` (no `v` prefix)
3. **draft:** `true` to keep a draft on GitHub (default)
4. **publish:** `true` only if `draft` is `false` and you want it live immediately

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
