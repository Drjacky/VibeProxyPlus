# Installing VibeProxy

**Fork:** [Drjacky/vibeproxy](https://github.com/Drjacky/vibeproxy) — Cursor support, CLIProxyAPIPlus, **unsigned** CI builds on [this repo's Releases](https://github.com/Drjacky/vibeproxy/releases).

**Requirements:** macOS 13+ on **Apple Silicon** (M1/M2/M3/M4). Intel ZIPs may appear in releases but are best-effort.

## Option 1: Download from this fork's Releases (recommended)

### Step 1: Download

1. Open [**Drjacky/vibeproxy Releases**](https://github.com/Drjacky/vibeproxy/releases)
2. Download **`VibeProxy-arm64-unsigned.zip`** or **`VibeProxy-arm64-signed.zip`** (name shows signing type)
3. Optional: verify with `shasum -a 256 -c VibeProxy-arm64-unsigned.zip.sha256` (match your file name)

### Step 2: Install

**Via ZIP:**
1. Extract the archive
2. Drag `VibeProxy.app` to `/Applications`

**Via DMG (if attached to the release):**
1. Open the DMG, drag `VibeProxy.app` to Applications, eject the DMG

### Step 3: First launch (unsigned build)

These releases are **not** notarized and use **ad-hoc** code signing. macOS may block the first open.

1. **Right-click** `VibeProxy.app` → **Open** → click **Open** in the dialog

Or: **System Settings** → **Privacy & Security** → **Open Anyway** after a blocked attempt.

After that, you can launch normally. See [FORK.md](FORK.md#github-releases-unsigned).

---

## Option 2: Build from Source

### Prerequisites

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- Xcode Command Line Tools
- Git

### Build Instructions

1. **Clone this fork and fetch LFS binary**
   ```bash
   brew install git-lfs
   git lfs install
   git clone https://github.com/Drjacky/vibeproxy.git
   cd vibeproxy
   git lfs pull
   ```

2. **Build the app**
   ```bash
   make app
   # or: ./create-app-bundle.sh
   ```

   This will:
   - Build the Swift executable in release mode
   - Bundle `cli-proxy-api-plus` (CLIProxyAPIPlus, includes Cursor)
   - Create `VibeProxy.app`
   - Sign with Developer ID if found, otherwise ad-hoc

3. **Install**
   ```bash
   # Move to Applications folder
   mv VibeProxy.app /Applications/

   # Or run directly
   open VibeProxy.app
   ```

### Build Commands

```bash
# Quick build and run
make run

# Build .app bundle
make app

# Install to /Applications
make install

# Clean build artifacts
make clean
```

### Code Signing (Optional)

If you have an Apple Developer account, the build script will automatically detect and use your Developer ID certificate for signing.

To manually specify a certificate:
```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./create-app-bundle.sh
```

---

## Verifying Downloads

Before installing any downloaded app, verify its authenticity:

### 1. Download from this fork

Use [Drjacky/vibeproxy Releases](https://github.com/Drjacky/vibeproxy/releases) only for Cursor-enabled builds from this fork.

### 2. Verify checksum (optional)

```bash
curl -LO https://github.com/Drjacky/vibeproxy/releases/download/vX.X.X/VibeProxy-arm64-unsigned.zip.sha256
curl -LO https://github.com/Drjacky/vibeproxy/releases/download/vX.X.X/VibeProxy-arm64-unsigned.zip
shasum -a 256 -c VibeProxy-arm64-unsigned.zip.sha256
```

Expected: `VibeProxy-arm64-unsigned.zip: OK`

### 3. Inspect the Code

All source code is available in this repository - feel free to review before building.

---

## Troubleshooting

### "App is damaged and can't be opened"

This can happen if download quarantine attributes cause issues:

```bash
xattr -cr /Applications/VibeProxy.app
```

Then try opening again.

### Build Fails

**Error: Swift not found**
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

**Error: Permission denied**
```bash
# Make scripts executable
chmod +x build.sh create-app-bundle.sh
```

### Still Having Issues?

- **Check System Requirements**: macOS 13.0 (Ventura) or later
- **Check Logs**: Look for errors in Console.app (search for "VibeProxy")
- **Report an Issue (fork)**: [Drjacky/vibeproxy issues](https://github.com/Drjacky/vibeproxy/issues)

---

**Questions?** Open an [issue](https://github.com/Drjacky/vibeproxy/issues) or check the [README](README.md).
