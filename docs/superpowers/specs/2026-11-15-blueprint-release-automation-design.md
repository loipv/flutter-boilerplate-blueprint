# Blueprint release automation design

Date: 2026-11-15
Status: approved

## Intent

Blueprint releases are manual today: edit `BLUEPRINT_VERSION.md`, the README version line and pinned-tag examples, write a `CHANGELOG.md` entry, create an annotated `vX.Y.Z` tag, push. Dependency updates are also manual. Automate both for the blueprint repository only.

## Goals

- A release workflow that proposes the next blueprint version from conventional commits and, when merged, tags `vX.Y.Z` and publishes a GitHub Release.
- Dependabot PRs for the blueprint's pub, npm and GitHub Actions dependencies.

## Non-goals

- Nothing ships into generated apps. Apps keep `ci.yml` and `integration.yml` only; their own `make bump-version` / `make changelog` / `make tag-release` flow is unchanged.
- No changeset files and no `@changesets/cli`.
- No Gradle or CocoaPods Dependabot ecosystems (Flutter manages those).

## Anti-goals

- A generated app containing release-please config, `dependabot.yml`, or leftover version markers.
- Breaking the existing tag format (`v1.4.0`) or `scaffold.sh` / `BLUEPRINT_REF` pinning.

## Approaches

| Approach | Trade-off | Picked |
|---|---|---|
| release-please (conventional commits) | No extra files per change; commits already follow `feat:`/`fix:`/`chore:`. Changelog becomes a grouped commit list instead of prose; editable in the release PR. | Yes |
| `@changesets/cli` | Rich per-change notes, standard action. Needs a root `package.json`; built for npm packages, so updating `BLUEPRINT_VERSION.md` / README needs custom glue. | No |
| Custom Dart changeset script | Fits the Flutter stack, no Node at root. Most code to write and maintain. | No |

The user picked release-please, scoped to the blueprint repo only.

## Design

### Release workflow

- `.github/workflows/release.yml`: on push to `main`, run `googleapis/release-please-action@v4` with `release-please-config.json` and `.release-please-manifest.json`.
- Config: `release-type: simple`, single package at `.`, `include-component-in-tag: false` (tags stay `vX.Y.Z`), PR title `Release blueprint v${version}`, `bootstrap-sha` at the `v1.4.0` release commit.
- Manifest starts at `{ ".": "1.4.0" }`.
- `extra-files` (generic updater, `x-release-please-version` markers):
  - `BLUEPRINT_VERSION.md`: the `Blueprint version: vX.Y.Z` line.
  - `README.md`: the "Latest stable blueprint version" line and the pinned-tag examples in Quick start.
- Release PRs are opened with `GITHUB_TOKEN`, so `blueprint.yml` does not run on them; it runs on `main` after merge. A PAT secret can be added later if PR-level CI is wanted.
- Tags become lightweight (created by the GitHub Release). `scaffold.sh` clones by ref, so this is fine.

### Dependabot

- `.github/dependabot.yml`, weekly:
  - `pub` at `/`
  - `npm` at `/functions` and `/firebase_tests`
  - `github-actions` at `/`
- Minor and patch updates grouped into one PR per ecosystem/directory; majors separate.
- Commit prefix `chore(deps)`, so dependency bumps alone do not trigger a release.

### Init (generated apps)

- Add `.github/workflows/release.yml`, `.github/dependabot.yml`, `release-please-config.json` and `.release-please-manifest.json` to `blueprintOnlyPaths` in `tool/src/manifest.dart`.
- Init strips the release-please version marker comment from `BLUEPRINT_VERSION.md` so apps get a clean `Blueprint version: vX.Y.Z` line. README is already replaced by `tool/app_readme.md`.
- Cover both with tests in `test/tool/`.

### Changelog and docs

- Remove the hand-written `## Unreleased` entry; release-please generates entries from commits. Older prose entries stay as they are.
- Reword the unpushed `chore(make): add project clean targets` commit to `feat(make): …` so it appears in the next release notes.
- Rewrite README section 18 ("Releasing blueprint updates") for the release-PR flow, and update the README sentence on generated-app workflows if needed.
- Note in `CLAUDE.md` that blueprint releases go through the release-please PR.

## Left to the builder

- Exact marker placement in README and `BLUEPRINT_VERSION.md`.
- Changelog section names in the config (`Features`, `Bug Fixes`, plus visible `Performance`, `Refactoring`, `Documentation` as sensible).
- Dependabot open-PR limits and labels.
