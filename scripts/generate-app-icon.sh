#!/bin/bash
# Generate AppIcon.icns from a master PNG (default: repo-root icon.png).
#
# Usage:
#   ./scripts/generate-app-icon.sh [input.png]
#   ./scripts/generate-app-icon.sh --badge [input.png]   # add + badge before building
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${PROJECT_DIR}/icon.png"
BADGE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --badge)
            BADGE=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--badge] [input.png]"
            echo "  --badge   Run badge-app-icon.swift on input before generating .icns"
            exit 0
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

if [[ "$INPUT" != /* ]]; then
    INPUT="$PROJECT_DIR/$INPUT"
fi

if [[ ! -f "$INPUT" ]]; then
    echo "error: input not found: $INPUT" >&2
    exit 1
fi

ICONSET="$PROJECT_DIR/src/Sources/CLIProxyMenuBar/Resources/AppIcon.iconset"
ICNS="$PROJECT_DIR/src/Sources/CLIProxyMenuBar/Resources/AppIcon.icns"
WORK="$INPUT"

if [[ "$BADGE" -eq 1 ]]; then
    WORK="$(mktemp "${TMPDIR:-/tmp}/vibeproxyplus-icon.XXXXXX.png")"
    trap 'rm -f "$WORK"' EXIT
    chmod +x "$PROJECT_DIR/scripts/badge-app-icon.swift"
    swift "$PROJECT_DIR/scripts/badge-app-icon.swift" "$INPUT" "$WORK"
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$WORK" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns -o "$ICNS" "$ICONSET"
rm -rf "$ICONSET"

echo "Wrote $ICNS (from $INPUT)"
