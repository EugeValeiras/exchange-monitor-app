# Exchange Monitor - iOS Build & Deploy Makefile
# Usage:
#   make release        - Increment build, build IPA, open Organizer
#   make release-upload - Increment build, build IPA, upload to TestFlight (requires API key)
#   make build          - Build IPA without incrementing version
#   make increment      - Just increment the build number
#   make clean          - Clean build artifacts

PUBSPEC := pubspec.yaml
MAIN_TARGET := lib/main_prod.dart
ARCHIVE_PATH := build/ios/archive/Runner.xcarchive
IPA_PATH := build/ios/ipa/Exchange\ Monitor.ipa

# App Store Connect API (set these as environment variables or here)
# Get from: https://appstoreconnect.apple.com/access/api
API_KEY ?=
API_ISSUER ?=

.PHONY: all release release-upload build increment clean open-organizer upload help

help:
	@echo "Exchange Monitor - iOS Build Commands"
	@echo ""
	@echo "  make release        - Increment build number, build IPA, open Xcode Organizer"
	@echo "  make release-upload - Increment build number, build IPA, upload to TestFlight"
	@echo "  make build          - Build IPA without incrementing version"
	@echo "  make increment      - Just increment the build number"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make version        - Show current version"
	@echo ""
	@echo "For automatic upload, set environment variables:"
	@echo "  export API_KEY=your_api_key_id"
	@echo "  export API_ISSUER=your_issuer_id"

# Show current version
version:
	@grep "^version:" $(PUBSPEC) | head -1
	@echo "Current: $$(grep '^version:' $(PUBSPEC) | sed 's/version: //')"

# Increment build number in pubspec.yaml
increment:
	@echo "📦 Incrementing build number..."
	@CURRENT=$$(grep '^version:' $(PUBSPEC) | sed 's/version: //'); \
	VERSION=$$(echo $$CURRENT | cut -d'+' -f1); \
	BUILD=$$(echo $$CURRENT | cut -d'+' -f2); \
	NEW_BUILD=$$((BUILD + 1)); \
	NEW_VERSION="$$VERSION+$$NEW_BUILD"; \
	sed -i '' "s/^version: .*/version: $$NEW_VERSION/" $(PUBSPEC); \
	echo "✅ Version updated: $$CURRENT → $$NEW_VERSION"

# Build IPA
build:
	@echo "🔨 Building IPA..."
	@flutter build ipa --release -t $(MAIN_TARGET)
	@echo "✅ Build complete!"
	@echo "📍 Archive: $(ARCHIVE_PATH)"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	@flutter clean
	@rm -rf build/ios/archive build/ios/ipa
	@echo "✅ Clean complete!"

# Open Xcode Organizer
open-organizer:
	@echo "📱 Opening Xcode Organizer..."
	@open $(ARCHIVE_PATH)

# Upload to TestFlight using xcrun altool
upload:
ifndef API_KEY
	$(error API_KEY is not set. Run: export API_KEY=your_key_id)
endif
ifndef API_ISSUER
	$(error API_ISSUER is not set. Run: export API_ISSUER=your_issuer_id)
endif
	@echo "🚀 Uploading to TestFlight..."
	@xcrun altool --upload-app --type ios \
		-f "build/ios/ipa/"*.ipa \
		--apiKey $(API_KEY) \
		--apiIssuer $(API_ISSUER)
	@echo "✅ Upload complete!"

# Full release: increment + build + open organizer
release: increment build open-organizer
	@echo ""
	@echo "🎉 Release ready!"
	@echo "👉 Click 'Distribute App' in Xcode Organizer to upload to TestFlight"

# Full release with auto-upload
release-upload: increment build upload
	@echo ""
	@echo "🎉 Release uploaded to TestFlight!"
	@VERSION=$$(grep '^version:' $(PUBSPEC) | sed 's/version: //'); \
	echo "📦 Version: $$VERSION"

# Default target
all: release
