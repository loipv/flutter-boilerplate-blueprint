# CLAUDE.md

> Minimal bootloader for Claude Code. Full rules are in **`AGENTS.md`**.

## Required Reading (Before Every Task)

1. **`AGENTS.md`**: Architecture rules, banned patterns, design system, testing standards
2. **`template/docs/tech.md`**: Schema, packages, directory structure
3. **`template/docs/ui_ux.md`**: Widget specs, haptics, typography
4. **`template/docs/testing_guide.md`**: TDD patterns, Mocktail usage

For blueprint release or versioning tasks, also read:

5. **`README.md`**: Blueprint install and release workflow
6. **`CHANGELOG.md`**: Blueprint change history between tags

## Project Identity

**flutter-firebase-blueprint**: A Flutter + Firebase starter template with feature-first architecture, Riverpod 3.x, auth, onboarding, and release tooling.
Flutter + Firebase · Feature-First Clean Architecture · Riverpod 3.x code-gen

## Key Commands

```bash
make run-staging          # Run staging flavor
make run-prod             # Run production flavor
make analyze              # fvm flutter analyze
make test                 # fvm flutter test
make codegen              # build_runner (freezed + riverpod)
make deploy-staging       # Deploy Firestore rules to staging
make deploy-prod          # Deploy Firestore rules to production
make release-preflight    # analyze + test gate
make build-prod-ipa       # IPA for App Store / TestFlight
make build-prod-aab       # AAB for Play Store
```

Always use `__FLUTTER_CMD__`, never bare `flutter`.

`make bump-version` and `make tag-release` are generated-app commands, not blueprint release commands. For blueprint releases, follow the process in `README.md` and use `BLUEPRINT_VERSION` in `scaffold.sh` as the source of truth.

## Critical Bans (Quick Reference)

- **Architecture:** Feature-first only. No `lib/controllers/`
- **State:** `@riverpod` code-gen only. No GetX, Provider, Bloc
- **Widgets:** `ConsumerWidget` / `ConsumerStatefulWidget`. No `StatefulWidget`
- **Imports:** Absolute only: `package:__APP_PACKAGE__/…`
- **Spacing:** `Gap(AppSpacing.pX)`. No `SizedBox`
- **Icons:** `lucide_icons_flutter`. No Material Icons
- **Fonts:** Bundled Inter / JetBrainsMono. No `google_fonts`
- **Logging:** `AppLogger`. No `print()` / `debugPrint()`
- **Colors:** `Color.withValues(alpha:)`. No `Color.withOpacity()`
- **Firebase:** SDK confined to `data/` layers and entrypoints
- **Errors:** Map all exceptions to `Failure` union type
