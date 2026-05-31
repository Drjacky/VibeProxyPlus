.PHONY: build app install clean run help fetch-cliproxy icon changelog-commits sync-version version check-isolation

icon: ## Regenerate AppIcon.icns from icon.png (use: make icon BADGE=1 to add + badge first)
	@chmod +x scripts/generate-app-icon.sh scripts/badge-app-icon.swift
	@if [ "$(BADGE)" = "1" ]; then ./scripts/generate-app-icon.sh --badge icon.png; else ./scripts/generate-app-icon.sh icon.png; fi

help: ## Show this help message
	@echo "VibeProxyPlus - macOS Menu Bar App"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Swift executable (debug)
	@echo "🔨 Building Swift executable..."
	@cd src && swift build
	@echo "✅ Build complete: src/.build/debug/CLIProxyMenuBar"

release: ## Build the Swift executable (release)
	@echo "🔨 Building Swift executable (release)..."
	@./build.sh
	@echo "✅ Build complete: src/.build/release/CLIProxyMenuBar"

fetch-cliproxy: ## Download cli-proxy-api-plus (required before first build)
	@chmod +x scripts/fetch-cliproxy-plus.sh
	@./scripts/fetch-cliproxy-plus.sh

fetch-dario: ## Build the dario engine binary via Bun (required before first build)
	@chmod +x scripts/fetch-dario.sh
	@./scripts/fetch-dario.sh

check-isolation: ## Verify engine modules stay mutually isolated (no cross-engine imports)
	@chmod +x scripts/check-engine-isolation.sh
	@./scripts/check-engine-isolation.sh

changelog-commits: ## Export commits since last v10.* tag for AI changelog (see -o)
	@chmod +x scripts/collect-unreleased-commits.sh
	@./scripts/collect-unreleased-commits.sh

sync-version: ## Copy VERSION -> src/Info.plist
	@chmod +x scripts/sync-app-version.sh scripts/app-version.sh
	@./scripts/sync-app-version.sh

version: ## Print app version from VERSION file
	@tr -d '[:space:]' < VERSION && echo

app: sync-version fetch-cliproxy fetch-dario ## Create the .app bundle
	@echo "📦 Creating .app bundle..."
	@./create-app-bundle.sh
	@echo "✅ App bundle created: VibeProxyPlus.app"

install: app ## Build and install to /Applications
	@echo "📲 Installing to /Applications..."
	@rm -rf "/Applications/VibeProxyPlus.app"
	@cp -r "VibeProxyPlus.app" /Applications/
	@echo "✅ Installed to /Applications/VibeProxyPlus.app"

run: app ## Build and run the app
	@echo "🚀 Launching app..."
	@open "VibeProxyPlus.app"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	@rm -rf src/.build
	@rm -rf "VibeProxyPlus.app"
	@rm -rf src/Sources/CLIProxyMenuBar/Resources/static
	@echo "✅ Clean complete"

test: ## Run a quick test build
	@echo "🧪 Testing build..."
	@cd src && swift build
	@echo "✅ Test build successful"

info: ## Show project information
	@echo "Project: VibeProxyPlus - macOS Menu Bar App"
	@echo "Language: Swift 5.9+"
	@echo "Platform: macOS 13.0+"
	@echo ""
	@echo "Files:"
	@find src/Sources -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print "  Swift code: " $$1 " lines"}'
	@echo "  Documentation: 4 files"
	@echo ""
	@echo "Structure:"
	@tree -L 3 -I ".build" || echo "  (install 'tree' for better output)"

open: ## Open app bundle to inspect contents
	@if [ -d "VibeProxyPlus.app" ]; then \
		open "VibeProxyPlus.app"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

edit-config: ## Edit the bundled config.yaml
	@if [ -d "VibeProxyPlus.app" ]; then \
		open -e "VibeProxyPlus.app/Contents/Resources/config.yaml"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

# Shortcuts
all: app ## Same as 'app'
