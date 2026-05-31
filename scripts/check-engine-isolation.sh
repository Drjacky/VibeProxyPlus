#!/bin/bash
# Engine isolation guard.
#
# Enforces the compile-time isolation invariants from the dual-engine architecture
# (plans/dario-integration-architecture.md, Sections 2, 23, 115):
#
#   1. CLIProxyEngine must never import DarioEngine.
#   2. DarioEngine must never import CLIProxyEngine.
#   3. EngineKit (the contract sink) must never import any concrete engine or
#      higher-level module (SharedUI, Persistence, ProcessRuntime, Diagnostics).
#   4. SharedUI must never import a concrete engine module.
#
# Run locally via `make check-isolation` and in CI before build/test.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES_DIR="$PROJECT_DIR/src/Sources"
FAILURES=0

# Report a violation and mark the run as failed.
fail() {
  echo "ISOLATION VIOLATION: $1" >&2
  FAILURES=$((FAILURES + 1))
}

# scan_module <module-dir> <forbidden-module> ...
# Fails if any .swift file in <module-dir> contains `import <forbidden-module>`.
scan_module() {
  local module_dir="$1"
  shift
  local module_path="$SOURCES_DIR/$module_dir"

  [ -d "$module_path" ] || return 0

  local forbidden
  for forbidden in "$@"; do
    # Match a top-level Swift import statement for the forbidden module only.
    local matches
    matches=$(grep -rEn "^[[:space:]]*(@[A-Za-z]+[[:space:]]+)?import[[:space:]]+${forbidden}([[:space:]]|$)" \
      --include='*.swift' "$module_path" || true)
    if [ -n "$matches" ]; then
      fail "$module_dir imports $forbidden:"
      echo "$matches" >&2
    fi
  done
}

# Engine modules must stay mutually isolated.
scan_module "CLIProxyEngine" "DarioEngine"
scan_module "DarioEngine" "CLIProxyEngine"

# EngineKit is the contract sink: Foundation only, no upward or engine imports.
scan_module "EngineKit" "SharedUI" "Persistence" "ProcessRuntime" "Diagnostics" "CLIProxyEngine" "DarioEngine"

# SharedUI is engine-neutral: it may use EngineKit but never a concrete engine.
scan_module "SharedUI" "CLIProxyEngine" "DarioEngine"

if [ "$FAILURES" -ne 0 ]; then
  echo "Engine isolation check failed with $FAILURES violation(s)." >&2
  exit 1
fi

echo "Engine isolation check passed."
