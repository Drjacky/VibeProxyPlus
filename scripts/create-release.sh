#!/bin/bash

# Local release creation script
# This builds the app and creates a distributable ZIP for manual uploads

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=${1:-"dev"}

echo -e "${BLUE}📦 Creating VibeProxyPlus Release ${VERSION}${NC}"
echo ""

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
cd "$PROJECT_DIR"
rm -rf VibeProxyPlus.app
rm -f VibeProxyPlus.zip
rm -f VibeProxyPlus.dmg

# Build the app
echo -e "${BLUE}🔨 Building VibeProxyPlus...${NC}"
./create-app-bundle.sh

if [ ! -d "VibeProxyPlus.app" ]; then
    echo -e "${RED}❌ Build failed - VibeProxyPlus.app not found${NC}"
    exit 1
fi

# Create ZIP
echo -e "${BLUE}📦 Creating ZIP archive...${NC}"
ditto -c -k --sequesterRsrc --keepParent "VibeProxyPlus.app" "VibeProxyPlus-${VERSION}.zip"

# Calculate checksum
echo -e "${BLUE}🔐 Calculating checksum...${NC}"
CHECKSUM=$(shasum -a 256 "VibeProxyPlus-${VERSION}.zip" | awk '{print $1}')

# Summary
echo ""
echo -e "${GREEN}✅ Release created successfully!${NC}"
echo ""
echo -e "${BLUE}Files created:${NC}"
echo "  - VibeProxyPlus.app (local testing)"
echo "  - VibeProxyPlus-${VERSION}.zip (for distribution)"
echo ""
echo -e "${BLUE}SHA-256 Checksum:${NC}"
echo "  ${CHECKSUM}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test the .app locally"
echo "  2. Create a new release on GitHub"
echo "  3. Upload VibeProxyPlus-${VERSION}.zip"
echo "  4. Add the checksum to release notes"
echo ""
echo -e "${BLUE}GitHub Release Command:${NC}"
echo "  gh release create v${VERSION} VibeProxyPlus-${VERSION}.zip --repo Drjacky/vibeproxyplus --notes 'Unsigned ad-hoc build. Right-click → Open on first launch.'"
echo ""
