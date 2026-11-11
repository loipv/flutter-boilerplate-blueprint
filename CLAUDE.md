# CLAUDE.md

> Minimal bootloader for Claude Code. Full rules are in **`AGENTS.md`**.

## Required Reading (Before Every Task)

1. **`AGENTS.md`**: Architecture rules, banned patterns, design system, testing standards
2. **`docs/tech.md`**: Schema, packages, directory structure
3. **`docs/ui_ux.md`**: Widget specs, haptics, typography
4. **`docs/testing_guide.md`**: TDD patterns, Mocktail usage

<!-- BEGIN_BLUEPRINT -->
For blueprint release or versioning tasks, also read:

5. **`README.md`**: Blueprint install and release workflow
6. **`CHANGELOG.md`**: Blueprint change history between tags

<!-- END_BLUEPRINT -->
## Also Read When Relevant

- **`docs/setup.md`**: Firebase setup, env files, platform config
- **`docs/auth_setup.md`**: Google Sign-In, Apple Sign-In, App Check, custom auth domains
- **`docs/release_guide.md`**: iOS and Android publishing flow

If a task touches analytics, auth redirects, or platform setup, check env-driven config first. The app may use `POSTHOG_HOST` or `FIREBASE_AUTH_DOMAIN` in the entrypoints.

## Project Identity

**Blueprint App**: A Flutter + Firebase starter app
Flutter + Firebase · Feature-First Clean Architecture · Riverpod 3.x code-gen

## Key Commands

```bash
make run-staging          # Run staging flavor
make run-prod             # Run production flavor
make analyze              # fvm flutter analyze
make test                 # fvm flutter test
make check-test-layout    # every test file mirrors a source file
make coverage             # tests + per-layer coverage gate
make codegen              # build_runner (freezed + riverpod)
make deploy-staging       # Deploy Firestore rules to staging
make deploy-prod          # Deploy Firestore rules to production
make release-preflight    # format + analyze + layout check + coverage gate
make bump-version VERSION=1.0.0 BUILD=1
make build-prod-ipa       # IPA for App Store / TestFlight
make build-prod-aab       # AAB for Play Store
make tag-release VERSION=1.0.0
```

Use the `make` target; where none exists, `fvm flutter`. Never use bare `flutter`.

<!-- BEGIN_BLUEPRINT -->
`make bump-version` and `make tag-release` are app commands, not blueprint release commands. For blueprint releases, follow the process in `README.md` and use `BLUEPRINT_VERSION.md` as the source of truth.

<!-- END_BLUEPRINT -->
## Critical Bans (Quick Reference)

- **Architecture:** Feature-first only. No `lib/controllers/`
- **State:** `@riverpod` code-gen only. No GetX, Provider, Bloc
- **Widgets:** `ConsumerWidget` / `ConsumerStatefulWidget`. No `StatefulWidget`
- **Imports:** Absolute only: `package:blueprint_app/…`
- **Spacing:** `Gap(AppSpacing.pX)`. No `SizedBox`
- **Icons:** `lucide_icons_flutter`. No Material Icons
- **Fonts:** Bundled Inter / JetBrainsMono. No `google_fonts`
- **Logging:** `AppLogger`. No `print()` / `debugPrint()`
- **Colors:** `Color.withValues(alpha:)`. No `Color.withOpacity()`
- **Firebase:** SDK confined to `data/` layers and entrypoints
- **Errors:** Map all exceptions to `Failure` union type
