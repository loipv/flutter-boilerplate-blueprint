# Blueprint Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate blueprint releases with release-please and dependency updates with Dependabot, for the blueprint repo only.

**Architecture:** A `release.yml` workflow runs release-please on every push to `main`; it keeps a "Release blueprint vX.Y.Z" PR up to date (CHANGELOG, `BLUEPRINT_VERSION.md`, README version lines) and tags + publishes a GitHub Release when that PR merges. `dependabot.yml` opens grouped weekly PRs. Init treats all new files as blueprint-only and strips the release-please version marker from `BLUEPRINT_VERSION.md`.

**Tech Stack:** GitHub Actions, `googleapis/release-please-action@v4`, Dependabot v2 config, Dart (init tool), bash (`tool/verify_init.sh`).

**Spec:** `docs/superpowers/specs/2026-11-15-blueprint-release-automation-design.md`

## Global Constraints

- Blueprint repo only: nothing new may survive in a generated app (`tool/verify_init.sh` must prove it).
- Tags stay `vX.Y.Z` (`include-component-in-tag: false`, v prefix kept).
- Current version `1.4.0`; last release commit `48cb9f89f44602d93010b514671b626b1d185f63`.
- Release PR title: `Release blueprint v${version}`.
- Dependabot commit prefix `chore(deps)`; ecosystems `pub` (`/`), `npm` (`/functions`, `/firebase_tests`), `github-actions` (`/`); weekly; minor+patch grouped.
- Commands via `make` or `fvm flutter` / `fvm dart`, never bare `flutter`.
- Commits follow conventional commits (`feat:`, `fix:`, `ci:`, `docs:`, `chore:`).

## Review Focus

1. Generated app still contains `x-release-please` text or a release/dependabot file → `verify_init.sh` greps the scaffolded tree (Task 2, Task 3).
2. The README version block accidentally covers the `v0.6.0`–`v0.9.0` paragraph, so a release rewrites those to the new version → the block must end before that paragraph (Task 2, Step 4 check).
3. release-please cannot find the v1.4.0 release (no GitHub Release exists for it) and proposes `1.0.0` or the full history → `last-release-sha` pins it (Task 2 config).
4. The release PR is never opened because the repo blocks Actions from creating PRs → README section 18 says to enable it (Task 4).
5. The hand-written `## Unreleased` changelog entry stays above release-please's generated entry → removed in Task 0.

---

### Task 0: Reword the clean-targets commit

The unpushed HEAD on `main` is `cc848e2 chore(make): add project clean targets`. release-please hides `chore`, so reword it to `feat` and drop its hand-written `## Unreleased` changelog entry.

**Files:**
- Modify: `CHANGELOG.md` (remove the `## Unreleased` section, lines 7-12)

- [ ] **Step 1: Confirm HEAD is still unpushed**

Run: `git status -sb | head -1 && git log --oneline -1`
Expected: `## main...origin/main [ahead 1]` and `cc848e2 chore(make): add project clean targets`. If not ahead, stop and ask.

- [ ] **Step 2: Remove the `## Unreleased` section from `CHANGELOG.md`** so the file goes straight from the intro paragraph to `## v1.4.0 - 2026-11-12`.

- [ ] **Step 3: Amend**

```bash
git add CHANGELOG.md
git commit --amend -m "feat(make): add project clean targets

Add clean, clean-codegen, clean-ios, clean-android, clean-node, clean-all
and reset. They only remove gitignored build output, caches and generated
code inside the project."
git show --stat HEAD
```
Expected: only `Makefile` changed in HEAD.

- [ ] **Step 4: Commit the spec and this plan**

```bash
git add docs/superpowers/specs/2026-11-15-blueprint-release-automation-design.md docs/superpowers/plans/2026-11-15-blueprint-release-automation.md
git commit -m "docs: add blueprint release automation design and plan"
```

---

### Task 1: Init strips release-please markers

**Files:**
- Modify: `tool/src/markers.dart`
- Modify: `tool/src/plan.dart` (right after `text = stripMarkerLines(text);`)
- Test: `test/tool/markers_test.dart`

**Interfaces:**
- Produces: `String stripReleaseMarkers(String text)` in `tool/src/markers.dart`. Removes inline `<!-- x-release-please-version -->` comments together with the whitespace before them, and drops lines consisting only of `<!-- x-release-please-start-version -->` or `<!-- x-release-please-end -->`. Text without markers is returned unchanged.

- [ ] **Step 1: Write the failing tests** in `test/tool/markers_test.dart`

```dart
test('stripReleaseMarkers removes an inline version marker', () {
  expect(
    stripReleaseMarkers('Blueprint version: v1.4.0 <!-- x-release-please-version -->\n'),
    'Blueprint version: v1.4.0\n',
  );
});

test('stripReleaseMarkers drops block marker lines and keeps content', () {
  expect(
    stripReleaseMarkers(
      'a\n<!-- x-release-please-start-version -->\nv1.4.0\n<!-- x-release-please-end -->\nb\n',
    ),
    'a\nv1.4.0\nb\n',
  );
});

test('stripReleaseMarkers leaves text without markers unchanged', () {
  const input = 'Blueprint version: v1.4.0\n<!-- BEGIN_ADS -->\n';
  expect(stripReleaseMarkers(input), input);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `fvm flutter test test/tool/markers_test.dart`
Expected: compile error, `stripReleaseMarkers` not defined.

- [ ] **Step 3: Implement `stripReleaseMarkers` in `tool/src/markers.dart`** with two `RegExp`s (inline: `\s*<!--\s*x-release-please-version\s*-->`; whole line: `^\s*<!--\s*x-release-please-(start-version|end)\s*-->\s*$`). Call it in `tool/src/plan.dart` on the line after `text = stripMarkerLines(text);`.

- [ ] **Step 4: Run the tool tests**

Run: `fvm flutter test test/tool`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add tool/src/markers.dart tool/src/plan.dart test/tool/markers_test.dart
git commit -m "feat(init): strip release-please version markers"
```

---

### Task 2: release-please workflow and version markers

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Modify: `BLUEPRINT_VERSION.md`
- Modify: `README.md` (Quick start, lines 40-54)
- Modify: `tool/src/manifest.dart` (`blueprintOnlyPaths`)
- Modify: `tool/verify_init.sh` (removed-path loop, line 38, plus a marker grep)

**Interfaces:**
- Consumes: `stripReleaseMarkers` (Task 1) runs on `BLUEPRINT_VERSION.md` during init.

- [ ] **Step 1: Create `.release-please-manifest.json`**: `{ ".": "1.4.0" }`

- [ ] **Step 2: Create `release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-component-in-tag": false,
  "pull-request-title-pattern": "Release blueprint v${version}",
  "last-release-sha": "48cb9f89f44602d93010b514671b626b1d185f63",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance" },
    { "type": "refactor", "section": "Refactoring" },
    { "type": "docs", "section": "Documentation" },
    { "type": "ci", "section": "CI", "hidden": true },
    { "type": "chore", "section": "Chores", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true }
  ],
  "packages": {
    ".": {
      "extra-files": [
        { "type": "generic", "path": "BLUEPRINT_VERSION.md" },
        { "type": "generic", "path": "README.md" }
      ]
    }
  }
}
```

- [ ] **Step 3: Create `.github/workflows/release.yml`**: name `Release`, `on: push: branches: [main]`, `permissions: contents: write, pull-requests: write`, one job running `googleapis/release-please-action@v4` with `config-file: release-please-config.json` and `manifest-file: .release-please-manifest.json`.

- [ ] **Step 4: Add version markers**
  - `BLUEPRINT_VERSION.md`: `Blueprint version: v1.4.0 <!-- x-release-please-version -->`
  - `README.md`: put `<!-- x-release-please-start-version -->` on its own line before `Latest stable blueprint version: \`v1.4.0\`` and `<!-- x-release-please-end -->` after the paragraph ending "…instead of its `HEAD`." (line 54). It must end before the `The \`v0.x\` one-liners` paragraph.

  Check: `awk '/x-release-please-start-version/,/x-release-please-end/' README.md | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -u`
  Expected: only `v1.4.0`.

- [ ] **Step 5: Mark as blueprint-only** — append `.github/workflows/release.yml`, `release-please-config.json`, `.release-please-manifest.json` to `blueprintOnlyPaths`; add the same three to the "still exists" loop in `tool/verify_init.sh`; after that loop add:

```bash
! grep -rIl 'x-release-please' . --exclude-dir=.git || fail "release-please markers left in the app"
```

- [ ] **Step 6: Validate**

Run: `python3 -m json.tool release-please-config.json >/dev/null && python3 -m json.tool .release-please-manifest.json >/dev/null && ruby -ryaml -e 'YAML.load_file(".github/workflows/release.yml")' && fvm flutter test test/tool`
Expected: no output from the parsers, tests pass.

Run: `tool/verify_init.sh --yes --name blueprint_ci`
Expected: completes without `fail` (the new marker grep included).

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/release.yml release-please-config.json .release-please-manifest.json BLUEPRINT_VERSION.md README.md tool/src/manifest.dart tool/verify_init.sh
git commit -m "ci: release blueprint versions with release-please"
```

---

### Task 3: Dependabot

**Files:**
- Create: `.github/dependabot.yml`
- Modify: `tool/src/manifest.dart` (`blueprintOnlyPaths`)
- Modify: `tool/verify_init.sh` (removed-path loop)

- [ ] **Step 1: Create `.github/dependabot.yml`** (`version: 2`) with four `updates` entries: `pub` at `/`, `npm` at `/functions`, `npm` at `/firebase_tests`, `github-actions` at `/`. Each: `schedule: interval: weekly`, `commit-message: prefix: "chore(deps)"`, and a `groups` entry `<ecosystem>-minor-patch` with `update-types: [minor, patch]` (majors stay ungrouped). `open-pull-requests-limit: 5`.

- [ ] **Step 2: Mark as blueprint-only** — append `.github/dependabot.yml` to `blueprintOnlyPaths` and to the "still exists" loop in `tool/verify_init.sh`.

- [ ] **Step 3: Validate**

Run: `ruby -ryaml -e 'YAML.load_file(".github/dependabot.yml")' && fvm flutter test test/tool && tool/verify_init.sh --yes --name blueprint_ci --no-functions`
Expected: parser silent, tests pass, verify completes.

- [ ] **Step 4: Commit**

```bash
git add .github/dependabot.yml tool/src/manifest.dart tool/verify_init.sh
git commit -m "ci: add Dependabot for pub, npm and GitHub Actions"
```

---

### Task 4: Release docs

**Files:**
- Modify: `README.md` section 18 "Releasing blueprint updates" and the generated-app workflows sentence (~line 317)
- Modify: `AGENTS.md` section 2.1.1 (lines 41-67)
- Modify: `CLAUDE.md` blueprint block (lines 60-63)

- [ ] **Step 1: Rewrite README section 18.** Content to cover:
  - Version source of truth is `.release-please-manifest.json`; release-please keeps `BLUEPRINT_VERSION.md`, the Quick start version lines and `CHANGELOG.md` in sync.
  - Flow: merge conventional commits to `main` → the "Release blueprint vX.Y.Z" PR updates itself → edit its CHANGELOG text if needed → merge → tag `vX.Y.Z` + GitHub Release.
  - `feat:` → minor, `fix:` → patch, `!`/`BREAKING CHANGE:` → major; `chore`/`ci`/`test` (including Dependabot's `chore(deps)`) don't release on their own. Force a version with a `Release-As: x.y.z` commit footer.
  - One-time repo setting: Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests".
  - CI (`blueprint.yml`) does not run on the release PR (it's opened with `GITHUB_TOKEN`); it runs on `main` after merge.
  - Dependabot opens weekly grouped PRs; `blueprint.yml` validates them.
  - Remove the manual `git tag -a` example.

- [ ] **Step 2: Update `AGENTS.md` 2.1.1** — blueprint version source is `.release-please-manifest.json` (mirrored to `BLUEPRINT_VERSION.md`); replace list item 4 with "Do not edit versions or CHANGELOG by hand; merge the release-please PR"; keep item 5.

- [ ] **Step 3: Update `CLAUDE.md` line 61** — "For blueprint releases, follow README section 18 (release-please PR); `.release-please-manifest.json` is the version source of truth."

- [ ] **Step 4: Verify markers still balance and nothing else broke**

Run: `make analyze && fvm flutter test test/tool`
Expected: no issues, tests pass.

- [ ] **Step 5: Commit**

```bash
git add README.md AGENTS.md CLAUDE.md
git commit -m "docs: describe the release-please blueprint release flow"
```

---

### After the plan (needs the user)

Pushing `main` is outward-facing: ask before `git push origin main`. After pushing, the user enables the Actions PR setting, then confirm the `Release` workflow run succeeds and opens a "Release blueprint v1.5.0" PR whose CHANGELOG includes the clean targets and init marker features.
