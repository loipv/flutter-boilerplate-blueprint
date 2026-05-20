# __APP_TITLE__

__APP_DESC__

Scaffolded from [`flutter-boilerplate-blueprint`](https://github.com/loipv/flutter-boilerplate-blueprint) `v__BLUEPRINT_VERSION__`.

## Getting started

1. Follow the post-scaffold checklist in [`docs/next_steps.md`](docs/next_steps.md).
2. For full Firebase, signing, and first-run setup, see [`docs/setup.md`](docs/setup.md).
3. For architecture rules and contribution conventions, see [`AGENTS.md`](AGENTS.md).

## Common commands

```sh
make run-staging          # Run the staging flavor
make run-prod             # Run the production flavor
make analyze              # Static analysis
make test                 # Unit + widget tests
make codegen              # Run build_runner (freezed + riverpod)
make deploy-staging       # Deploy Firestore rules to staging
make deploy-prod          # Deploy Firestore rules to production
make release-preflight    # analyze + test gate before a release
make build-prod-ipa       # Build production IPA
make build-prod-aab       # Build production AAB
```

See the [`Makefile`](Makefile) for the full list of targets.

## Documentation

- [`docs/setup.md`](docs/setup.md) — Firebase projects, env files, platform setup
- [`docs/auth_setup.md`](docs/auth_setup.md) — Google / Apple Sign-In, App Check
- [`docs/tech.md`](docs/tech.md) — Architecture, packages, directory layout
- [`docs/ui_ux.md`](docs/ui_ux.md) — Design system, spacing, typography
- [`docs/testing_guide.md`](docs/testing_guide.md) — Test patterns and mocks
- [`docs/release_guide.md`](docs/release_guide.md) — iOS and Android release prep
- [`docs/android_signing.md`](docs/android_signing.md) — Android signing setup
