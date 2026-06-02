#!/bin/bash
# Build the Dario engine into a single self-contained macOS binary and install it into
# src/Sources/AppBridge/Resources/ (not in git; built at build time).
#
# Dario (askalf/dario, npm @askalf/dario) is a pure-ESM Node.js project with no prebuilt binary
# release, so the binary is compiled with Bun's `--compile`. Dario relies on the Bun runtime for
# TLS wire-fidelity, so a Bun-compiled binary matches its runtime requirements.
#
# Bun --compile only embeds statically-analyzable assets. Dario reads its bundled
# cc-template-data.json at runtime via `readFileSync(join(__dirname, 'cc-template-data.json'))`,
# which --compile rewrites to a non-existent /$bunfs/root path. A pre-compile patch redirects that
# single read to a `with { type: "file" }` import so the asset is embedded and resolvable.
#
# Prerequisites (build/CI machine only, never the end user's machine): Bun, Node >=18, git.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_DIR/src/Sources/AppBridge/Resources"
TARGET_FILE="$TARGET_DIR/dario"
VERSION_FILE="$TARGET_DIR/dario.version"
ARCH="${TARGET_ARCH:-arm64}"
REPO="askalf/dario"
# Pin the Dario version. Override with DARIO_TAG to bump deliberately; never auto-advance.
DARIO_TAG="${DARIO_TAG:-v4.8.19}"

case "$ARCH" in
  arm64)  BUN_TARGET="bun-darwin-arm64" ;;
  x86_64) BUN_TARGET="bun-darwin-x64" ;;
  *)
    echo "Unsupported TARGET_ARCH: $ARCH (use arm64 or x86_64)" >&2
    exit 1
    ;;
esac

binary_present() {
  [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]
}

installed_version() {
  [ -f "$VERSION_FILE" ] && tr -d '[:space:]' < "$VERSION_FILE" || echo ""
}

TARGET_VERSION="${DARIO_TAG#v}"

# Skip rebuild when the installed binary already matches the pinned tag (unless forced).
if [ "${FORCE_FETCH_DARIO:-0}" != "1" ] \
   && binary_present \
   && [ "$(installed_version)" = "$TARGET_VERSION" ]; then
  echo "dario ${TARGET_VERSION} already present ($(wc -c < "$TARGET_FILE" | tr -d ' ') bytes)"
  exit 0
fi

# Locate Bun (allow a freshly-installed copy under ~/.bun).
BUN_BIN="$(command -v bun || true)"
if [ -z "$BUN_BIN" ] && [ -x "$HOME/.bun/bin/bun" ]; then
  BUN_BIN="$HOME/.bun/bin/bun"
fi
if [ -z "$BUN_BIN" ]; then
  echo "Bun is required to build dario. Install from https://bun.sh (curl -fsSL https://bun.sh/install | bash)." >&2
  exit 1
fi
command -v npm >/dev/null 2>&1 || { echo "npm (Node >=18) is required to build dario." >&2; exit 1; }

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Cloning ${REPO} ${DARIO_TAG}..."
git clone --depth 1 --branch "$DARIO_TAG" "https://github.com/${REPO}.git" "$TEMP_DIR/dario" 2>&1 | tail -1

cd "$TEMP_DIR/dario"
echo "Installing dependencies..."
npm ci >/dev/null 2>&1
echo "Building dist/..."
npm run build >/dev/null 2>&1

# --- Targeted asset-embedding patch (see header) ---
# Embed cc-template-data.json as a Bun file import and redirect the single runtime read at
# dist/live-fingerprint.js to the embedded copy. Abort if the expected read is absent, which
# indicates Dario's source layout changed and the patch needs updating.
LF="dist/live-fingerprint.js"
if ! grep -q "join(__dirname, 'cc-template-data.json')" "$LF"; then
  echo "ERROR: expected cc-template-data.json read not found in $LF. Dario layout changed; update fetch-dario.sh." >&2
  exit 1
fi
perl -0pi -e 's{^}{import __vpEmbeddedCcTemplate from "./cc-template-data.json" with \{ type: "file" \};\n}' "$LF"
perl -0pi -e "s/join\(__dirname, 'cc-template-data\.json'\)/__vpEmbeddedCcTemplate/g" "$LF"

# Compile to a path distinct from the clone dir ($TEMP_DIR/dario) to avoid a collision.
COMPILED_BIN="$TEMP_DIR/dario-bin"
echo "Compiling single binary for ${BUN_TARGET}..."
"$BUN_BIN" build --compile --target="$BUN_TARGET" ./dist/cli.js --outfile "$COMPILED_BIN" >/dev/null 2>&1

[ -s "$COMPILED_BIN" ] || { echo "Bun compile produced no binary" >&2; exit 1; }

# Smoke-test the compiled binary: `doctor` must run and load the embedded template.
# doctor exits non-zero when not authenticated (expected); only the ENOENT template crash is fatal.
if "$COMPILED_BIN" doctor 2>&1 | grep -q 'cc-template-data.json'; then
  echo "ERROR: compiled dario cannot load embedded cc-template-data.json" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$COMPILED_BIN" "$TARGET_FILE"
chmod +x "$TARGET_FILE"
echo "$TARGET_VERSION" > "$VERSION_FILE"
# Record a checksum of the installed binary for supply-chain verification (release pipeline
# can compare this to detect tampering between build and bundling).
shasum -a 256 "$TARGET_FILE" | awk '{print $1}' > "$TARGET_FILE.sha256"
file "$TARGET_FILE"
echo "Installed dario $(installed_version) ($(wc -c < "$TARGET_FILE" | tr -d ' ') bytes) to $TARGET_FILE"
echo "Checksum: $(cat "$TARGET_FILE.sha256")"

