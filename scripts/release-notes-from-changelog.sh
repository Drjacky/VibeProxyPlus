#!/bin/bash
# Build GitHub release notes from CHANGELOG.md + optional download lines.
#
# Usage:
#   ./scripts/release-notes-from-changelog.sh 10.8.163
#   ./scripts/release-notes-from-changelog.sh 10.8.163 --assets "VibeProxyPlus-arm64-unsigned.zip"

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="${PROJECT_DIR}/CHANGELOG.md"
VERSION=""
ASSETS=""

usage() {
  echo "Usage: $0 VERSION [--assets 'file1.zip,file2.dmg']"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --assets) ASSETS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -z "$VERSION" ]; then VERSION="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi
      shift
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$CHANGELOG" ]; then
  echo "Missing $CHANGELOG" >&2
  exit 1
fi

SECTION=$(awk -v ver="$VERSION" '
  BEGIN { found=0 }
  /^## \[/ {
    if (found) exit
    if ($0 ~ "^## \\[" ver "\\]") { found=1; next }
    next
  }
  found && /^\[/ { exit }
  found { print }
' "$CHANGELOG")

if [ -z "$SECTION" ]; then
  echo "No ## [${VERSION}] section in CHANGELOG.md — run collect-unreleased-commits.sh, draft with AI, then add the section." >&2
  exit 1
fi

printf '%s\n' "$SECTION"

if [ -n "$ASSETS" ]; then
  echo ""
  echo "### Downloads (Apple Silicon)"
  echo ""
  IFS=',' read -ra FILES <<< "$ASSETS"
  for f in "${FILES[@]}"; do
    f=$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$f" ] && echo "- \`${f}\`"
  done
  echo ""
  echo "Unsigned builds: right-click the app → **Open** on first launch."
fi
