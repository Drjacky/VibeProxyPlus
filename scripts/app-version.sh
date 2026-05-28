#!/bin/bash
# App version helpers — canonical version lives in repo-root VERSION (no "v" prefix).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${APP_VERSION_FILE:-${PROJECT_DIR}/VERSION}"
INFO_PLIST="${APP_INFO_PLIST:-${PROJECT_DIR}/src/Info.plist}"

read_app_version() {
  if [ ! -f "$VERSION_FILE" ]; then
    echo "Missing VERSION file: $VERSION_FILE" >&2
    return 1
  fi
  local v
  v=$(tr -d '[:space:]' < "$VERSION_FILE")
  if [ -z "$v" ]; then
    echo "VERSION file is empty: $VERSION_FILE" >&2
    return 1
  fi
  echo "$v"
}

read_app_build_number() {
  if [ -n "${APP_BUILD_NUMBER:-}" ]; then
    echo "$APP_BUILD_NUMBER"
    return
  fi
  if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$PROJECT_DIR" rev-list --count HEAD
    return
  fi
  if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0"
    return
  fi
  echo "0"
}

sync_info_plist() {
  local version="${1:-$(read_app_version)}"
  local build="${2:-$(read_app_build_number)}"
  if [ ! -f "$INFO_PLIST" ]; then
    echo "Missing Info.plist: $INFO_PLIST" >&2
    return 1
  fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build}" "$INFO_PLIST"
}

validate_git_tag_matches_version() {
  local tag="${1:-}"
  local version
  version=$(read_app_version)
  if [ -z "$tag" ]; then
    echo "validate_git_tag_matches_version: tag required" >&2
    return 1
  fi
  local tag_version="${tag#v}"
  if [ "$tag_version" != "$version" ]; then
    echo "Tag ${tag} does not match VERSION file (${version})." >&2
    echo "Update VERSION to ${tag_version} or retag as v${version}." >&2
    return 1
  fi
}
