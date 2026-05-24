# VibeProxy

<p align="center">
  <img src="icon.png" width="128" height="128" alt="VibeProxy Icon">
</p>

<p align="center">
  <a href="https://github.com/Drjacky/vibeproxy/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-28a745"></a>
  <a href="https://github.com/Drjacky/vibeproxy"><img alt="GitHub" src="https://img.shields.io/github/stars/Drjacky/vibeproxy.svg?style=social&label=Star"></a>
</p>

Native macOS menu bar app that routes your existing AI subscriptions through a local OpenAI-compatible proxy (`http://localhost:8317`).

**This repo:** [Drjacky/vibeproxy](https://github.com/Drjacky/vibeproxy) - personal fork of [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy) with **Cursor provider** support and [CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) bundled. Pre-built apps are published on [this repo's Releases](https://github.com/Drjacky/vibeproxy/releases).

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

**https://github.com/Drjacky/vibeproxy/releases**

> **Signing.** Filenames indicate type: `VibeProxy-arm64-unsigned.zip` (ad-hoc) or `VibeProxy-arm64-signed.zip` if Apple signing secrets are set in the repo. Unsigned builds need **right-click → Open** the first time.

1. Download the ZIP for your Mac from the latest release.
2. Extract and move `VibeProxy.app` to **Applications**.
3. **Right-click** the app → **Open** → confirm **Open**.

Verify checksums: `shasum -a 256 -c VibeProxy-arm64-unsigned.zip.sha256`

More detail: [INSTALLATION.md](INSTALLATION.md)

### Build from source

```bash
git clone https://github.com/Drjacky/vibeproxy.git
cd vibeproxy
make app    # downloads cli-proxy-api-plus automatically
open VibeProxy.app
```

Requires `curl` and `jq` (or run `./scripts/fetch-cliproxy-plus.sh` first).

---

## Quick start

1. Launch **VibeProxy** and open **Settings** from the menu bar.
2. Enable providers you need (including **Cursor**).
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
│   │   ├── CursorTokenImporter.swift
│   │   ├── CursorJWTHelper.swift
│   │   ├── ForkConfig.swift
│   │   └── Resources/cli-proxy-api-plus.version
│   └── Package.swift
├── scripts/fetch-cliproxy-plus.sh
├── create-app-bundle.sh
├── Makefile
└── CURSOR_SETUP.md
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

## Maintaining this fork

This fork is not intended to replace upstream. Cursor and release automation live here; many docs and Sparkle feeds still align with [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy) for easier merges.

### What to keep aligned with upstream

| Area | Why |
|------|-----|
| `CHANGELOG.md` | Release history from upstream lineage |
| `appcast.xml`, `appcast-x86_64.xml` | Sparkle feeds (still point at upstream unless you change them) |
| `FACTORY_SETUP.md` | Factory setup for official-style releases |
| `.github/workflows/update-cliproxyapi.yml` | CLIProxyAPIPlus bump automation |
| `src/Info.plist` (`SUFeedURL`) | In-app auto-update (upstream feed by default) |

### What is fork-specific

| Area | Why |
|------|-----|
| [`ForkConfig.swift`](src/Sources/ForkConfig.swift) | Fork URLs in the app UI |
| `SettingsView` "Report an issue" | Points at **this repo's** issues |
| `README.md`, `INSTALLATION.md`, `CURSOR_SETUP.md` | This fork's install and Cursor docs |
| `.github/workflows/release.yml` | Builds `*-unsigned` / `*-signed` assets on **Drjacky/vibeproxy** Releases |
| Cursor Swift sources | `CursorTokenImporter`, `CursorJWTHelper`, provider UI |

**Downloads:** Use [Drjacky/vibeproxy Releases](https://github.com/Drjacky/vibeproxy/releases). Sparkle inside the app may still check upstream until you change `SUFeedURL` in `src/Info.plist`.

### Bundled backend (CLIProxyAPIPlus)

The ~50MB binary is **not stored in git** on this fork. GitHub blocks **new LFS uploads on public forks** (`can not upload new objects to public fork`).

Instead:

- `src/Sources/Resources/cli-proxy-api-plus.version` — pinned version (committed)
- `scripts/fetch-cliproxy-plus.sh` — downloads the binary locally (gitignored)
- CI (`release.yml`, `update-cliproxyapi.yml`) — downloads from [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) releases

Bump PRs only update the `.version` file; release builds fetch the binary on the runner.

```bash
./scripts/fetch-cliproxy-plus.sh
# or: make fetch-cliproxy
```

Alternative: [detach the fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/detaching-a-fork) on GitHub if you want to use Git LFS on the repo again.

### Syncing with upstream

```bash
git remote add upstream https://github.com/automazeio/vibeproxy.git   # once
git fetch upstream
git merge upstream/main
```

After each sync:

1. Resolve conflicts; prefer **upstream** for files in the table above.
2. Keep fork-specific pieces (`ForkConfig.swift`, Cursor code, `release.yml`, this README's fork sections).
3. Confirm "Report an issue" still points at this repo.
4. Re-run `cd src && swift test` and `make app` if provider code changed.

---

## GitHub Releases and CI

Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml) — **Build and Release**

| Trigger | Result |
|---------|--------|
| Push tag `v*` | Builds arm64 (+ x86_64 if asset exists), uploads `*-unsigned.zip` / `*-signed.zip` (+ DMG, `.sha256`) to **this repo's Releases** |
| `workflow_dispatch` | Builds artifacts only (no Release unless you also push a tag) |

Asset names:

- `VibeProxy-arm64-unsigned.zip` - ad-hoc (default without Apple signing secrets)
- `VibeProxy-arm64-signed.zip` - Apple Developer ID when signing secrets are configured

Release notes explain unsigned vs signed and **right-click → Open** for unsigned builds.

Optional later: notarization, Sparkle on this repo (`SUFeedURL`, `appcast.xml`, `SPARKLE_PRIVATE_KEY`).

### Automatic release pipeline

Requires repo secret **`AUTO_UPDATE_TOKEN`** (PAT). `GITHUB_TOKEN` cannot push tags that trigger other workflows.

1. **`update-cliproxyapi.yml`** (every 12h) - bumps CLIProxyAPIPlus, opens `bump-cliproxyapi-*` PR, triggers auto-release.
2. **`auto-release.yml`** - merges that PR, bumps patch in `CHANGELOG.md`, pushes tag `v*`.
3. **`release.yml`** - tag push publishes Release assets.

**Create the secret (one-time):**

1. GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
2. Name: `AUTO_UPDATE_TOKEN`
3. Value: classic PAT (`repo` + `workflow`) or fine-grained token with **Contents**, **Pull requests**, **Actions**, and **Workflows** read/write.

### Manual tag

```bash
git tag v1.0.0-cursor.1
git push origin v1.0.0-cursor.1
```

Triggers `release.yml` only (no bump PR merge).

Optional Apple signing secrets for `*-signed*` artifacts: `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`, `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`, `APPLE_DEVELOPER_ID_APPLICATION`.

---

## Credits

- [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy) - original macOS app and UI
- [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) - proxy server (Cursor and other providers)

---

## License

MIT - see [LICENSE](LICENSE).

## Support

- **Issues:** https://github.com/Drjacky/vibeproxy/issues
- **Repository:** https://github.com/Drjacky/vibeproxy
