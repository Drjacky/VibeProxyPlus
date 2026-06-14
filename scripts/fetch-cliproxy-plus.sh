#!/bin/bash
# Download CLIProxyAPIPlus into src/Sources/Resources/ (not in git; fetched at build time).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_DIR/src/Sources/AppBridge/Resources"
TARGET_FILE="$TARGET_DIR/cli-proxy-api-plus"
VERSION_FILE="$TARGET_DIR/cli-proxy-api-plus.version"
ARCH="${TARGET_ARCH:-arm64}"
REPO="kaitranntt/CLIProxyAPIPlus"
GITHUB_API="https://api.github.com/repos/${REPO}"

github_api() {
  local url="$1"
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if [ -n "$token" ]; then
    curl -sf -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.github+json" "$url"
  else
    curl -sf "$url"
  fi
}

normalize_tag() {
  local t="$1"
  if [[ "$t" == v* ]]; then echo "$t"; else echo "v$t"; fi
}

# Latest non-draft release tag (includes prereleases, ordered newest first).
latest_release_tag() {
  if command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    gh release list --repo "$REPO" --limit 1 --exclude-drafts --json tagName \
      --jq '.[0].tagName' 2>/dev/null && return 0
  fi
  github_api "${GITHUB_API}/releases" | jq -r '[.[] | select(.draft == false)][0].tag_name'
}

installed_version() {
  [ -f "$VERSION_FILE" ] && tr -d '[:space:]' < "$VERSION_FILE" || echo ""
}

binary_present() {
  [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ] \
    && ! head -1 "$TARGET_FILE" 2>/dev/null | grep -q 'git-lfs'
}

# Upstream darwin assets are published with a `_no-plugin` suffix (the plugin-enabled build
# is not distributed); the suffix is matched optionally so older un-suffixed assets also resolve.
case "$ARCH" in
  arm64) ASSET_REGEX='^CLIProxyAPIPlus_.+_darwin_(aarch64|arm64)(_no-plugin)?\.tar\.gz$' ;;
  x86_64) ASSET_REGEX='^CLIProxyAPIPlus_.+_darwin_amd64(_no-plugin)?\.tar\.gz$' ;;
  *)
    echo "Unsupported TARGET_ARCH: $ARCH (use arm64 or x86_64)" >&2
    exit 1
    ;;
esac

# Resolve the target tag: explicit pin via CLIPROXY_TAG, otherwise latest upstream release.
if [ -n "${CLIPROXY_TAG:-}" ]; then
  TAG="$(normalize_tag "$CLIPROXY_TAG")"
else
  TAG="$(latest_release_tag || true)"
fi

if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
  # Network/API lookup failed. Keep an existing binary; only error if we have nothing.
  if binary_present; then
    echo "Could not resolve latest CLIProxyAPIPlus tag; keeping installed version $(installed_version)" >&2
    exit 0
  fi
  echo "Could not resolve a CLIProxyAPIPlus release tag from ${REPO}." >&2
  if [ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    echo "Hint: set GH_TOKEN for GitHub API (required in CI)." >&2
  fi
  exit 1
fi

TARGET_VERSION="${TAG#v}"

# Skip download when the installed binary already matches the target tag (unless forced).
if [ "${FORCE_FETCH_CLIPROXY:-0}" != "1" ] \
   && binary_present \
   && [ "$(installed_version)" = "$TARGET_VERSION" ]; then
  echo "cli-proxy-api-plus ${TARGET_VERSION} already present ($(wc -c < "$TARGET_FILE" | tr -d ' ') bytes)"
  exit 0
fi

echo "Fetching CLIProxyAPIPlus ${TAG} for ${ARCH}..."
RELEASE_JSON=$(github_api "${GITHUB_API}/releases/tags/${TAG}")
URL=$(echo "$RELEASE_JSON" | jq -r --arg re "$ASSET_REGEX" '.assets[] | select(.name | test($re)) | .browser_download_url' | head -n 1)

if [ -z "$URL" ] || [ "$URL" = "null" ]; then
  echo "No asset for ${ARCH} on ${TAG}" >&2
  echo "$RELEASE_JSON" | jq -r '.assets[].name' >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

FILENAME=$(basename "$URL")
curl -L -f --retry 3 --retry-delay 2 -o "$TEMP_DIR/$FILENAME" "$URL"
tar -xzf "$TEMP_DIR/$FILENAME" -C "$TEMP_DIR"
BINARY=$(find "$TEMP_DIR" -type f \( -name 'CLIProxyAPIPlus' -o -name 'cli-proxy-api-plus' \) | head -n 1)
if [ -z "$BINARY" ]; then
  BINARY=$(find "$TEMP_DIR" -type f -perm +111 | head -n 1)
fi
[ -n "$BINARY" ] || { echo "Binary not found in tarball" >&2; exit 1; }

mkdir -p "$TARGET_DIR"
cp "$BINARY" "$TARGET_FILE"
chmod +x "$TARGET_FILE"
echo "${TAG#v}" > "$VERSION_FILE"
# Record a checksum of the installed binary for supply-chain verification.
shasum -a 256 "$TARGET_FILE" | awk '{print $1}' > "$TARGET_FILE.sha256"
file "$TARGET_FILE"
echo "Installed $(wc -c < "$TARGET_FILE" | tr -d ' ') bytes to $TARGET_FILE"
echo "Checksum: $(cat "$TARGET_FILE.sha256")"
