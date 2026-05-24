# Fork maintenance (Drjacky/vibeproxy)

This repository is a **personal fork** of [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy). It is not intended to replace upstream; changes here are for local experiments (e.g. Cursor provider support) and may never be opened as PRs upstream.

## What stays upstream (`automazeio/vibeproxy`)

Keep these aligned with upstream when you sync so merges stay easy:

| Area                                       | Why                                                |
|--------------------------------------------|----------------------------------------------------|
| `CHANGELOG.md`                             | Release history and links belong to upstream       |
| `appcast.xml`, `appcast-x86_64.xml`        | Sparkle feeds for official builds                  |
| `FACTORY_SETUP.md`                         | Install docs aligned with upstream releases        |
| `.github/workflows/update-cliproxyapi.yml` | Bump PR automation (can match upstream)            |
| `.github/workflows/release.yml`            | **Fork-specific** — unsigned releases on this repo |
| `create-app-bundle.sh` (appcast URL)       | Official Intel appcast host                        |
| `src/Info.plist` (`SUFeedURL`)             | Auto-update from upstream releases                 |

**Downloads:** Pre-built ZIPs/DMGs are published on **[Drjacky/vibeproxy Releases](https://github.com/Drjacky/vibeproxy/releases)** (unsigned, ad-hoc). Sparkle in the app may still point at upstream until you change `SUFeedURL` in `src/Info.plist`.

## What is fork-specific (`Drjacky/vibeproxy`)

| Area | Why |
|------|-----|
| [`src/Sources/ForkConfig.swift`](src/Sources/ForkConfig.swift) | Single place for fork URLs in the app UI |
| `SettingsView` "Report an issue" | Points at **fork** issues (Cursor / fork-only bugs) |
| `FORK.md` | This file (not in upstream) |
| `README.md`, `INSTALLATION.md`, `CURSOR_SETUP.md` | Drjacky clone/build, Cursor setup |
| Cursor Swift sources | `CursorTokenImporter`, `CursorJWTHelper`, provider UI |

## Bundled backend binary

VibeProxy ships `src/Sources/Resources/cli-proxy-api-plus` from **[kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus)** releases (not `router-for-me/CLIProxyAPI`), so the fork includes the **Cursor** provider and `-cursor-login`. CI workflows download the same source on release and on scheduled bumps.

The binary is tracked with **Git LFS** (~50MB). See [Git LFS setup](#git-lfs-setup) below.

## Git LFS setup

GitHub warns on large files; LFS stores the binary on GitHub's LFS storage and keeps a small pointer in git.

### One-time on your Mac

```bash
brew install git-lfs
git lfs install    # configures your user account (run once per machine)
```

### Clone or pull this repo

```bash
git clone git@github.com:Drjacky/vibeproxy.git
cd vibeproxy
git lfs pull       # usually automatic after clone if lfs is installed
```

### Commit the binary (after updating it)

```bash
cd vibeproxy
git lfs install
git add .gitattributes
git add src/Sources/Resources/cli-proxy-api-plus
git commit -m "Update cli-proxy-api-plus via LFS"
git push
```

If `git lfs` is not installed, `git add` still works but stores the full 50MB in git (GitHub will warn again).

### GitHub LFS quota

Public repos: generous LFS bandwidth. Private repos: 1 GiB storage + 1 GiB bandwidth/month on free plan ([GitHub LFS billing](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-git-large-file-storage/about-billing-for-git-large-file-storage)). Bumping the binary a few times per month is usually fine.

### Old history without LFS

Commits from **automazeio/vibeproxy** may still contain the binary as a normal git object. Only **new** commits on this fork use LFS (via `.gitattributes`). Rewriting all history to LFS is optional (`git lfs migrate import`); not required for day-to-day work.

## Syncing with upstream

```bash
git remote add upstream https://github.com/automazeio/vibeproxy.git   # once
git fetch upstream
git merge upstream/main   # or rebase, your preference
```

After each sync:

1. Resolve conflicts; prefer **upstream** for files listed in "What stays upstream".
2. Re-apply the README fork banner if it was lost.
3. Confirm `ForkConfig.swift` and `SettingsView` still use fork issue URL.
4. Re-run tests / build if you changed provider code.

## GitHub Releases

### Automatic pipeline (requires `AUTO_UPDATE_TOKEN`)

1. **`update-cliproxyapi.yml`** (every 12h) — bumps bundled CLIProxyAPIPlus, opens `bump-cliproxyapi-*` PR, triggers auto-release.
2. **`auto-release.yml`** — merges that PR, bumps patch version in `CHANGELOG.md`, pushes tag `v*`.
3. **`release.yml`** — tag push builds `*-unsigned.zip` / `*-signed.zip` on **this repo's Releases**.

`GITHUB_TOKEN` cannot push tags that trigger other workflows; use a **PAT** stored as repo secret **`AUTO_UPDATE_TOKEN`**.

**Create the secret (one-time):**

1. GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
2. Name: `AUTO_UPDATE_TOKEN`
3. Value: classic PAT or fine-grained token with:
   - **Contents:** Read and write
   - **Pull requests:** Read and write
   - **Actions:** Read and write (to run `auto-release` / `release` workflows)
   - **Workflows:** Read and write (classic: `repo` + `workflow` scopes)

### Manual release

Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml) — **Build and Release**

| Trigger | Result |
|---------|--------|
| Push tag `v*` (e.g. `v1.0.0-cursor.1`) | Builds arm64 (+ x86_64 if asset exists), uploads ZIP/DMG + `.sha256` to **this repo's Releases** |
| `workflow_dispatch` | Builds artifacts only (no Release unless you also push a tag) |

Release asset names:

- `VibeProxy-arm64-unsigned.zip` — ad-hoc (default when no Apple secrets)
- `VibeProxy-arm64-signed.zip` — when signing secrets are configured

Release notes explain both suffixes and **right-click → Open** for unsigned builds.

Maintainer:

```bash
git tag v1.0.0-cursor.1
git push origin v1.0.0-cursor.1
```

If GitHub secrets for Apple code signing are set, CI produces `*-signed.zip` assets; otherwise `*-unsigned.zip` (ad-hoc). Filenames on the Releases page make this obvious.

Optional later: notarization, Sparkle (`SUFeedURL`, `appcast.xml`) on `Drjacky/vibeproxy`, and `SPARKLE_PRIVATE_KEY`.
