#!/bin/bash
# Collect commits since the last release tag through HEAD for AI changelog drafting.
#
# Usage:
#   ./scripts/collect-unreleased-commits.sh
#   ./scripts/collect-unreleased-commits.sh --since v10.8.162
#   ./scripts/collect-unreleased-commits.sh --json -o unreleased.json
#   ./scripts/collect-unreleased-commits.sh --no-prompt -o commits-for-ai.md

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SINCE=""
TO="HEAD"
FORMAT="markdown"
INCLUDE_PROMPT=1
OUTPUT=""

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo ""
  echo "Options:"
  echo "  --since TAG     Base tag (default: latest v* tag)"
  echo "  --to REF        End ref (default: HEAD)"
  echo "  --json          Output JSON instead of markdown"
  echo "  --no-prompt     Omit AI instruction block (markdown only)"
  echo "  -o, --output F  Write to file instead of stdout"
  echo "  -h, --help      Show this help"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --json) FORMAT="json"; INCLUDE_PROMPT=0; shift ;;
    --prompt) INCLUDE_PROMPT=1; shift ;;
    --no-prompt) INCLUDE_PROMPT=0; shift ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

resolve_since_tag() {
  if [ -n "$SINCE" ]; then
    echo "$SINCE"
    return
  fi
  git tag -l 'v*' --sort=-v:refname 2>/dev/null | head -n 1 || true
}

SINCE_TAG=$(resolve_since_tag)
if [ -z "$SINCE_TAG" ]; then
  echo "No release tag found. Use --since vX.Y.Z or create a tag first." >&2
  exit 1
fi

if ! git rev-parse "$SINCE_TAG" >/dev/null 2>&1; then
  echo "Tag not found: $SINCE_TAG" >&2
  exit 1
fi
if ! git rev-parse "$TO" >/dev/null 2>&1; then
  echo "Ref not found: $TO" >&2
  exit 1
fi

RANGE="${SINCE_TAG}..${TO}"
COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)

COMPARE_URL=""
ORIGIN=$(git remote get-url origin 2>/dev/null || true)
if [ -n "$ORIGIN" ]; then
  REPO_PATH=$(echo "$ORIGIN" | sed -E 's#\.git$##' | sed -E 's#^git@github.com:##' | sed -E 's#^https://github.com/##')
  COMPARE_URL="https://github.com/${REPO_PATH}/compare/${SINCE_TAG}...${TO}"
fi

emit() {
  if [ -n "$OUTPUT" ]; then
    tee "$OUTPUT"
  else
    cat
  fi
}

if [ "$FORMAT" = "json" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for --json" >&2
    exit 1
  fi
  COMMITS=$(git log "$RANGE" --no-merges --pretty=format:'%H%x1f%h%x1f%aI%x1f%an%x1f%s%x1f%b%x1e' | jq -Rs '
    split("\u001e")
    | map(select(length > 0))
    | map(split("\u001f"))
    | map({
        hash: .[0],
        short: .[1],
        date: .[2],
        author: .[3],
        subject: .[4],
        body: (.[5] // "")
      })
  ')
  jq -n \
    --arg since "$SINCE_TAG" \
    --arg to "$TO" \
    --argjson count "$COUNT" \
    --arg compare "$COMPARE_URL" \
    --argjson commits "$COMMITS" \
    '{since_tag: $since, to_ref: $to, commit_count: $count, compare_url: $compare, commits: $commits}' \
    | emit
  [ -n "$OUTPUT" ] && echo "Wrote JSON (${COUNT} commits) to $OUTPUT" >&2
  exit 0
fi

{
  if [ "$INCLUDE_PROMPT" -eq 1 ]; then
    cat <<'PROMPT'
---
Task: Write a **Keep a Changelog** section for VibeProxyPlus (user-facing macOS app).

- Use categories: Added, Changed, Fixed, Removed (only sections that apply).
- One bullet per meaningful change; group related commits; skip CI-only noise unless user-visible.
- Output markdown only: start with `## [VERSION] - YYYY-MM-DD` (you choose version/date), then `###` subsections. No preamble.
- Do not include install, signing, or download instructions.
---

PROMPT
  fi

  echo "# Unreleased commits"
  echo ""
  echo "- **Range:** \`${SINCE_TAG}..${TO}\`"
  echo "- **Count:** ${COUNT} commits (no merges)"
  if [ -n "$COMPARE_URL" ]; then
    echo "- **Compare:** ${COMPARE_URL}"
  fi
  echo ""

  if [ "$COUNT" -eq 0 ]; then
    echo "_No commits since ${SINCE_TAG}._"
  else
    echo "## Commit list"
    echo ""
    git log "$RANGE" --no-merges --pretty=format:'- `%h` %s (%an, %ad)' --date=short
    echo ""
    echo "## Full messages"
    echo ""
    git log "$RANGE" --no-merges --format='----%ncommit %H%nAuthor: %an <%ae>%nDate: %ad%nSubject: %s%n%n%b' --date=iso-strict
  fi
} | emit

[ -n "$OUTPUT" ] && echo "Wrote markdown (${COUNT} commits, ${SINCE_TAG}..${TO}) to $OUTPUT" >&2
