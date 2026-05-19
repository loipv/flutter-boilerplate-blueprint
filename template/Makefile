DEVICE ?=
RELEASE_DEVICE ?=

# Convert every KEY=VALUE line in an env file into --dart-define=KEY=VALUE flags.
# Accepts a space-separated list of candidate files; first existing wins.
# Comments (#) and blank lines are ignored.
# Usage: $(call dart_defines,.env.staging .env)
dart_defines = $$(for f in $(1); do if [ -f "$$f" ]; then grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$$f" | sed 's/^/--dart-define=/' | tr '\n' ' '; break; fi; done)

.PHONY: help run-staging run-prod run-prod-release \
        build-staging-ios build-staging-apk \
        build-prod-ios build-prod-apk build-prod-ipa build-prod-aab \
        deploy-staging deploy-prod deploy-storage-staging deploy-storage-prod \
        deploy-functions-staging deploy-functions-prod \
        set-secret-staging set-secret-prod \
        release-preflight bump-version changelog tag-release \
        analyze test codegen icons splash

help:
	@echo ""
	@echo "  __APP_TITLE__ dev commands"
	@echo ""
	@echo "  Run"
	@echo "    make run-staging [DEVICE=<device-id>]"
	@echo "    make run-prod    [DEVICE=<device-id>]"
	@echo "    make run-prod-release [RELEASE_DEVICE=id]"
	@echo ""
	@echo "  Build"
	@echo "    make build-staging-ios"
	@echo "    make build-staging-apk"
	@echo "    make build-prod-ipa    (IPA for App Store / TestFlight)"
	@echo "    make build-prod-aab    (AAB + symbols for Play Store)"
	@echo ""
	@echo "  Release"
	@echo "    make release-preflight            (analyze + test gate)"
	@echo "    make bump-version VERSION=1.0.0 BUILD=2"
	@echo "    make changelog"
	@echo "    make tag-release VERSION=1.0.0"
	@echo ""
	@echo "  Deploy rules"
	@echo "    make deploy-staging           (Firestore rules)"
	@echo "    make deploy-prod"
	@echo "    make deploy-storage-staging   (Storage rules)"
	@echo "    make deploy-storage-prod"
	@echo ""
	@echo "  Cloud Functions"
	@echo "    make deploy-functions-staging"
	@echo "    make deploy-functions-prod"
	@echo "    make set-secret-staging SECRET=<NAME>"
	@echo "    make set-secret-prod    SECRET=<NAME>"
	@echo ""
	@echo "  Dev"
	@echo "    make analyze"
	@echo "    make test"
	@echo "    make codegen"
	@echo "    make icons    (regenerate launcher icons from assets/icons/app_logo.png)"
	@echo "    make splash   (regenerate native splash from pubspec.yaml config)"
	@echo ""

run-staging:
	@__FLUTTER_CMD__ run --flavor staging -t lib/main_staging.dart $(if $(DEVICE),-d "$(DEVICE)") \
	  --dart-define=APP_ENV=staging $(call dart_defines,.env.staging .env)

run-prod:
	@__FLUTTER_CMD__ run --flavor production -t lib/main_production.dart $(if $(DEVICE),-d "$(DEVICE)") \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env)

run-prod-release:
	@__FLUTTER_CMD__ run --flavor production -t lib/main_production.dart \
	  $(if $(RELEASE_DEVICE),-d "$(RELEASE_DEVICE)") --release \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env)

build-staging-ios:
	@__FLUTTER_CMD__ build ios --flavor staging -t lib/main_staging.dart \
	  --dart-define=APP_ENV=staging $(call dart_defines,.env.staging .env)

build-staging-apk:
	@__FLUTTER_CMD__ build apk --flavor staging -t lib/main_staging.dart \
	  --dart-define=APP_ENV=staging $(call dart_defines,.env.staging .env)

build-prod-ios:
	@__FLUTTER_CMD__ build ios --flavor production -t lib/main_production.dart \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env)

build-prod-apk:
	@__FLUTTER_CMD__ build apk --flavor production -t lib/main_production.dart \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env)

build-prod-ipa:
	@__FLUTTER_CMD__ build ipa --flavor production -t lib/main_production.dart \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env)

build-prod-aab:
	@__FLUTTER_CMD__ build appbundle --flavor production -t lib/main_production.dart \
	  --dart-define=APP_ENV=production $(call dart_defines,.env.production .env) \
	  --obfuscate --split-debug-info=build/app/outputs/symbols

release-preflight:
	dart format . && __FLUTTER_CMD__ analyze && __FLUTTER_CMD__ test

bump-version:
	@if [ -z "$(VERSION)" ] || [ -z "$(BUILD)" ]; then \
	  echo "Usage: make bump-version VERSION=1.0.0 BUILD=2"; exit 1; \
	fi
	@sed -i '' "s/^version: .*/version: $(VERSION)+$(BUILD)/" pubspec.yaml
	@echo "Bumped to $(VERSION)+$(BUILD)"

changelog:
	@LAST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo ""); \
	VERSION=$$(grep '^version:' pubspec.yaml | sed 's/version: //'); \
	DATE=$$(date +%Y-%m-%d); \
	{ \
	  echo "## $$VERSION - $$DATE"; echo ""; \
	  if [ -z "$$LAST_TAG" ]; then git log --pretty=format:"- %s" HEAD; \
	  else git log --pretty=format:"- %s" $$LAST_TAG..HEAD; fi; \
	  echo ""; echo ""; \
	  if [ -f CHANGELOG.md ]; then cat CHANGELOG.md; fi; \
	} > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
	@echo "Changelog updated. Edit before committing.."

tag-release:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make tag-release VERSION=1.0.0"; exit 1; fi
	git tag -a v$(VERSION) -m "Release $(VERSION)"
	@echo "Created tag v$(VERSION). Push when ready: git push origin v$(VERSION)"

deploy-staging:
	firebase use staging && firebase deploy --only firestore

deploy-prod:
	firebase use production && firebase deploy --only firestore

deploy-storage-staging:
	firebase use staging && firebase deploy --only storage

deploy-storage-prod:
	firebase use production && firebase deploy --only storage

deploy-functions-staging:
	cd functions && npm run build && firebase use staging && firebase deploy --only functions

deploy-functions-prod:
	cd functions && npm run build && firebase use production && firebase deploy --only functions

set-secret-staging:
	@if [ -z "$(SECRET)" ]; then echo "Usage: make set-secret-staging SECRET=<NAME>"; exit 1; fi
	firebase use staging && firebase functions:secrets:set $(SECRET)

set-secret-prod:
	@if [ -z "$(SECRET)" ]; then echo "Usage: make set-secret-prod SECRET=<NAME>"; exit 1; fi
	firebase use production && firebase functions:secrets:set $(SECRET)

analyze:
	__FLUTTER_CMD__ analyze

test:
	__FLUTTER_CMD__ test

codegen:
	__FLUTTER_CMD__ pub run build_runner build --delete-conflicting-outputs

icons:
	__FLUTTER_CMD__ pub run flutter_launcher_icons

splash:
	__FLUTTER_CMD__ pub run flutter_native_splash:create
