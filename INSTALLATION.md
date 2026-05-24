# Installing VibeProxyPlus

**VibeProxyPlus** builds are published on [GitHub Releases](https://github.com/Drjacky/vibeproxyplus/releases) (unsigned unless signed in CI).

**Requirements:** macOS 13+ on **Apple Silicon** (M1/M2/M3/M4). Intel ZIPs may appear in releases but are best-effort.

## Option 1: Download from this fork's Releases (recommended)

### Step 1: Download

1. Open [**Drjacky/vibeproxyplus Releases**](https://github.com/Drjacky/vibeproxyplus/releases)
2. Download **`VibeProxyPlus-arm64-unsigned.zip`** or **`VibeProxyPlus-arm64-signed.zip`** (name shows signing type)
3. Optional: verify with `shasum -a 256 -c VibeProxyPlus-arm64-unsigned.zip.sha256` (match your file name)

### Step 2: Install

**Via ZIP:**
1. Extract the archive
2. Drag `VibeProxyPlus.app` to `/Applications`

**Via DMG (if attached to the release):**
1. Open the DMG, drag `VibeProxyPlus.app` to Applications, eject the DMG

### Step 3: First launch (unsigned build)

These releases are **not** notarized and use **ad-hoc** code signing. macOS may block the first open.

1. **Right-click** `VibeProxyPlus.app` → **Open** → click **Open** in the dialog

Or: **System Settings** → **Privacy & Security** → **Open Anyway** after a blocked attempt.

After that, you can launch normally. See [README.md](README.md#github-releases-and-ci).

---

## Option 2: Build from Source

### Prerequisites

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- Xcode Command Line Tools
- Git

### Build Instructions

1. **Clone this fork**
   ```bash
   git clone https://github.com/Drjacky/vibeproxyplus.git
   cd vibeproxy
   ```
   The CLI binary is downloaded on first `make app` (not stored in git; public forks cannot push LFS).

2. **Build the app**
   ```bash
   make app
   # or: ./create-app-bundle.sh
   ```

   This will:
   - Build the Swift executable in release mode
   - Bundle `cli-proxy-api-plus` (CLIProxyAPIPlus, includes Cursor)
   - Create `VibeProxyPlus.app`
   - Sign with Developer ID if found, otherwise ad-hoc

3. **Install**
   ```bash
   # Move to Applications folder
   mv VibeProxyPlus.app /Applications/

   # Or run directly
   open VibeProxyPlus.app
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

Use [Drjacky/vibeproxyplus Releases](https://github.com/Drjacky/vibeproxyplus/releases) only for Cursor-enabled builds from this fork.

### 2. Verify checksum (optional)

```bash
curl -LO https://github.com/Drjacky/vibeproxyplus/releases/download/vX.X.X/VibeProxyPlus-arm64-unsigned.zip.sha256
curl -LO https://github.com/Drjacky/vibeproxyplus/releases/download/vX.X.X/VibeProxyPlus-arm64-unsigned.zip
shasum -a 256 -c VibeProxyPlus-arm64-unsigned.zip.sha256
```

Expected: `VibeProxyPlus-arm64-unsigned.zip: OK`

### 3. Inspect the Code

All source code is available in this repository - feel free to review before building.

---

## Troubleshooting

### "App is damaged and can't be opened"

This can happen if download quarantine attributes cause issues:

```bash
xattr -cr /Applications/VibeProxyPlus.app
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
- **Check Logs**: Look for errors in Console.app (search for "VibeProxyPlus")
- **Report an Issue (fork)**: [Drjacky/vibeproxyplus issues](https://github.com/Drjacky/vibeproxyplus/issues)

---

**Questions?** Open an [issue](https://github.com/Drjacky/vibeproxyplus/issues) or check the [README](README.md).
