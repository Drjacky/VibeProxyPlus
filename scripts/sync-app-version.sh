#!/bin/bash
# Write VERSION -> src/Info.plist (CFBundleShortVersionString + CFBundleVersion).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=app-version.sh
source "${SCRIPT_DIR}/app-version.sh"

VERSION=$(read_app_version)
BUILD=$(read_app_build_number)
sync_info_plist "$VERSION" "$BUILD"
echo "Synced VERSION ${VERSION} (build ${BUILD}) -> ${INFO_PLIST}"
