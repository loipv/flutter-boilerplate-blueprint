FLUTTER ?= $(shell command -v fvm >/dev/null 2>&1 && echo "fvm flutter" || echo "flutter")

DEVICE ?=
RELEASE_DEVICE ?=

# Convert every KEY=VALUE line in an env file into --dart-define=KEY=VALUE flags.
# Accepts a space-separated list of candidate files; first existing wins.
# Comments (#) and blank lines are ignored.
# Usage: $(call dart_defines,.env.staging .env)
dart_defines = $$(for f in $(1); do if [ -f "$$f" ]; then grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$$f" | sed 's/^/--dart-define=/' | tr '\n' ' '; break; fi; done)

.PHONY: help setup firebase-stubs run-staging run-prod run-prod-release \
        build-staging-ios build-staging-apk \
        build-prod-ios build-prod-apk build-prod-ipa build-prod-aab \
        deploy-staging deploy-prod deploy-storage-staging deploy-storage-prod \
        deploy-functions-staging deploy-functions-prod \
        set-secret-staging set-secret-prod \
        release-preflight bump-version changelog tag-release \
        analyze test codegen icons splash

help:
	@echo ""
	@echo "  Blueprint App dev commands"
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
	@echo "    make setup    (Firebase options stubs + pub get + codegen + functions npm install)"
	@echo "    make analyze"
	@echo "    make test"
	@echo "    make codegen"
	@echo "    make icons    (regenerate launcher icons from assets/icons/app_logo.png)"
	@echo "    make splash   (regenerate native splash from pubspec.yaml config)"
	@echo ""

run-staging:
	@$(FLUTTER) run --flavor staging $(if $(DEVICE),-d "$(DEVICE)") \
	  $(call dart_defines,.env.staging .env)

run-prod:
	@$(FLUTTER) run --flavor production $(if $(DEVICE),-d "$(DEVICE)") \
	  $(call dart_defines,.env.production .env)

run-prod-release:
	@$(FLUTTER) run --flavor production \
	  $(if $(RELEASE_DEVICE),-d "$(RELEASE_DEVICE)") --release \
	  $(call dart_defines,.env.production .env)

build-staging-ios:
	@$(FLUTTER) build ios --flavor staging \
	  $(call dart_defines,.env.staging .env)

build-staging-apk:
	@$(FLUTTER) build apk --flavor staging \
	  $(call dart_defines,.env.staging .env)

build-prod-ios:
	@$(FLUTTER) build ios --flavor production \
	  $(call dart_defines,.env.production .env)

build-prod-apk:
	@$(FLUTTER) build apk --flavor production \
	  $(call dart_defines,.env.production .env)

build-prod-ipa:
	@$(FLUTTER) build ipa --flavor production \
	  $(call dart_defines,.env.production .env)

build-prod-aab:
	@$(FLUTTER) build appbundle --flavor production \
	  $(call dart_defines,.env.production .env) \
	  --obfuscate --split-debug-info=build/app/outputs/symbols

release-preflight:
	$(FLUTTER:flutter=dart) format . && $(FLUTTER) analyze && $(FLUTTER) test

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
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

codegen:
	$(FLUTTER) pub run build_runner build --delete-conflicting-outputs

# Writes a stub lib/firebase_options_<env>.dart for each flavor that has none,
# so a fresh clone compiles before flutterfire configure. Never overwrites.
firebase-stubs:
	@for env in staging production; do \
	  f="lib/firebase_options_$$env.dart"; \
	  [ -f "$$f" ] && continue; \
	  printf '%s\n' \
	    '// Stub Firebase options so the project compiles before Firebase is configured.' \
	    '// Replace it by running:' \
	    "//   flutterfire configure --project=<$$env-project-id> --out=$$f" \
	    "import 'package:firebase_core/firebase_core.dart';" \
	    '' \
	    'class DefaultFirebaseOptions {' \
	    '  static FirebaseOptions get currentPlatform => const FirebaseOptions(' \
	    "    apiKey: 'stub'," \
	    "    appId: 'stub'," \
	    "    messagingSenderId: 'stub'," \
	    "    projectId: 'stub'," \
	    '  );' \
	    '}' > "$$f"; \
	  echo "Created stub $$f (run flutterfire configure to replace it)"; \
	done

setup: firebase-stubs
	$(FLUTTER) pub get
	$(FLUTTER) pub run build_runner build --delete-conflicting-outputs
	@if [ -d functions ]; then cd functions && npm install; fi

icons:
	$(FLUTTER) pub run flutter_launcher_icons

splash:
	$(FLUTTER) pub run flutter_native_splash:create
