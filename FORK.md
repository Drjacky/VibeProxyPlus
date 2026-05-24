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
