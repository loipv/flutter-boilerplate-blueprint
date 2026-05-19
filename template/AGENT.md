<!-- prettier-ignore -->
# __AI_TOOL_NAME__

<!-- prettier-ignore -->
> Minimal bootloader for __AI_TOOL_NAME__. Full rules are in **`AGENTS.md`**.

## Required Reading (Before Every Task)

1. **`AGENTS.md`**: Architecture rules, banned patterns, design system, testing standards
2. **`docs/tech.md`**: Schema, packages, directory structure
3. **`docs/ui_ux.md`**: Widget specs, haptics, typography
4. **`docs/testing_guide.md`**: TDD patterns, Mocktail usage

## Also Read When Relevant

- **`docs/setup.md`**: Firebase setup, env files, platform config
- **`docs/auth_setup.md`**: Google Sign-In, Apple Sign-In, App Check, custom auth domains
- **`docs/release_guide.md`**: iOS and Android publishing flow

If a task touches analytics, auth redirects, or platform setup, check env-driven config first. The generated app may use `POSTHOG_HOST` or `FIREBASE_AUTH_DOMAIN` in the entrypoints.

## Project Identity

<!-- prettier-ignore -->
**__APP_TITLE__**: <!-- add one-sentence description here -->
Flutter + Firebase · Feature-First Clean Architecture · Riverpod 3.x code-gen

## Key Commands

```bash
make run-staging          # Run staging flavor
make run-prod             # Run production flavor
make analyze              # __FLUTTER_CMD__ analyze
make test                 # __FLUTTER_CMD__ test
make codegen              # build_runner (freezed + riverpod)
make deploy-staging       # Deploy Firestore rules to staging
make deploy-prod          # Deploy Firestore rules to production
make release-preflight    # analyze + test gate
make bump-version VERSION=1.0.0 BUILD=1
make build-prod-ipa       # IPA for App Store / TestFlight
make build-prod-aab       # AAB for Play Store
make tag-release VERSION=1.0.0
```

Always use `__FLUTTER_CMD__`, never bare `flutter`.

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
