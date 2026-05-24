#!/bin/bash
# Download CLIProxyAPIPlus into src/Sources/Resources/ (gitignored on this fork).
# Public GitHub forks cannot push new LFS objects; CI and local builds fetch the binary instead.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_DIR/src/Sources/Resources"
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

release_tag_exists() {
  local tag="$1"
  if command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    gh release view "$tag" --repo "$REPO" >/dev/null 2>&1
    return $?
  fi
  github_api "${GITHUB_API}/releases/tags/${tag}" >/dev/null
}

need_binary() {
  if [ ! -f "$TARGET_FILE" ] || [ ! -s "$TARGET_FILE" ]; then
    return 0
  fi
  if head -1 "$TARGET_FILE" 2>/dev/null | grep -q 'git-lfs'; then
    return 0
  fi
  return 1
}

if ! need_binary && [ "${FORCE_FETCH_CLIPROXY:-0}" != "1" ]; then
  echo "cli-proxy-api-plus already present ($(wc -c < "$TARGET_FILE" | tr -d ' ') bytes)"
  exit 0
fi

resolve_tag_candidates() {
  if [ -n "${CLIPROXY_TAG:-}" ]; then
    if [[ "${CLIPROXY_TAG}" == v* ]]; then echo "${CLIPROXY_TAG}"; else echo "v${CLIPROXY_TAG}"; fi
    return
  fi
  if [ -f "$VERSION_FILE" ]; then
    local v
    v=$(tr -d '[:space:]' < "$VERSION_FILE")
    if [[ "$v" == v* ]]; then
      echo "$v"
      echo "${v}-0"
      echo "${v}-1"
    else
      echo "v${v}"
      echo "v${v}-0"
      echo "v${v}-1"
    fi
    return
  fi
  github_api "${GITHUB_API}/releases/latest" | jq -r .tag_name
}

case "$ARCH" in
  arm64) ASSET_REGEX='^CLIProxyAPIPlus_.+_darwin_(aarch64|arm64)\.tar\.gz$' ;;
  x86_64) ASSET_REGEX='^CLIProxyAPIPlus_.+_darwin_amd64\.tar\.gz$' ;;
  *)
    echo "Unsupported TARGET_ARCH: $ARCH (use arm64 or x86_64)" >&2
    exit 1
    ;;
esac

TAG=""
while IFS= read -r candidate; do
  [ -z "$candidate" ] && continue
  if release_tag_exists "$candidate"; then
    TAG="$candidate"
    break
  fi
done < <(resolve_tag_candidates | awk '!seen[$0]++')

if [ -z "$TAG" ]; then
  echo "Could not resolve a CLIProxyAPIPlus release tag (check ${VERSION_FILE})" >&2
  if [ -f "$VERSION_FILE" ]; then
    echo "Pinned version: $(tr -d '[:space:]' < "$VERSION_FILE")" >&2
  fi
  echo "Tried: $(resolve_tag_candidates | tr '\n' ' ')" >&2
  if [ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    echo "Hint: set GH_TOKEN for GitHub API (required in CI)." >&2
  fi
  exit 1
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
file "$TARGET_FILE"
echo "Installed $(wc -c < "$TARGET_FILE" | tr -d ' ') bytes to $TARGET_FILE"
