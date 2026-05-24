# Fork maintenance (Drjacky/vibeproxy)

This repository is a **personal fork** of [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy). It is not intended to replace upstream; changes here are for local experiments (e.g. Cursor provider support) and may never be opened as PRs upstream.

## What stays upstream (`automazeio/vibeproxy`)

Keep these aligned with upstream when you sync so merges stay easy:

| Area | Why |
|------|-----|
| `CHANGELOG.md` | Release history and links belong to upstream |
| `appcast.xml`, `appcast-x86_64.xml` | Sparkle feeds for official builds |
| `INSTALLATION.md`, `FACTORY_SETUP.md` | Install docs for official releases |
| `README.md` (body) | Same as upstream except the fork banner at the top |
| `.github/workflows/*.yml` | Release and bump automation match upstream |
| `create-app-bundle.sh` (appcast URL) | Official Intel appcast host |
| `src/Info.plist` (`SUFeedURL`) | Auto-update from upstream releases |

**Downloads and updates:** Use [upstream releases](https://github.com/automazeio/vibeproxy/releases) unless you build and publish from this fork yourself.

## What is fork-specific (`Drjacky/vibeproxy`)

| Area | Why |
|------|-----|
| [`src/Sources/ForkConfig.swift`](src/Sources/ForkConfig.swift) | Single place for fork URLs in the app UI |
| `SettingsView` "Report an issue" | Points at **fork** issues (Cursor / fork-only bugs) |
| `FORK.md` | This file (not in upstream) |
| README fork banner | Explains fork vs upstream |
| Future Cursor code | New Swift files and provider UI |

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

## If you publish your own releases later

Only then switch these to `Drjacky/vibeproxy`:

- `src/Info.plist` `SUFeedURL`
- `appcast.xml` / `appcast-x86_64.xml` enclosure URLs
- `.github/workflows/release.yml` download URLs
- Install docs pointing at your releases

Until then, keep Sparkle and release assets on **upstream** so auto-update and docs stay consistent.
