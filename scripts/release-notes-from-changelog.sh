#!/bin/bash
# Build GitHub release notes from CHANGELOG.md.
#
# Usage:
#   ./scripts/release-notes-from-changelog.sh 10.8.163

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="${PROJECT_DIR}/CHANGELOG.md"
VERSION=""

usage() {
  echo "Usage: $0 VERSION"
}

while [ $# -gt 0 ]; do
  case "$1" in
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
