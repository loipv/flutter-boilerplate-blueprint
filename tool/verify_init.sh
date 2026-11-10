#!/usr/bin/env bash
# End-to-end check for tool/init.dart.
#
# Usage (from the repository root): tool/verify_init.sh [init flags...]
#
# Copies the working tree (tracked and untracked, not ignored) to a temporary
# directory, runs init there with the given flags, checks the result, then runs
# `make setup analyze test`. Prints `OK: <dir>` on success; any failed check
# exits non-zero. The temporary directory is kept for inspection.
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f tool/init.dart ] || fail "run this from the repository root (tool/init.dart not found)"

if command -v fvm >/dev/null 2>&1; then
  DART=(fvm dart)
else
  DART=(dart)
fi

dir="$(mktemp -d)"
echo "Copying working tree to $dir"
rsync -a --files-from=<(git ls-files -co --exclude-standard) ./ "$dir/"

cd "$dir"
echo "Running: ${DART[*]} tool/init.dart $*"
"${DART[@]}" tool/init.dart "$@" || fail "init exited with $?"

for path in tool scaffold.sh CHANGELOG.md LICENSE docs/superpowers docs/repo-assets test/tool .github/workflows/blueprint.yml; do
  [ ! -e "$path" ] || fail "$path still exists"
done
for path in .git .env.staging .env.production BLUEPRINT_VERSION.md .github/workflows/ci.yml; do
  [ -e "$path" ] || fail "$path is missing"
done

kotlin=android/app/src/main/kotlin
activities="$(find "$kotlin" -name MainActivity.kt -type f)"
count="$(printf '%s\n' "$activities" | grep -c . || true)"
[ "$count" -eq 1 ] || fail "expected exactly one MainActivity.kt under $kotlin, found $count"
empty="$(find "$kotlin" -type d -empty)"
[ -z "$empty" ] || fail "empty directories under $kotlin: $empty"
echo "MainActivity: $activities"

make setup analyze test || fail "make setup analyze test"

echo "OK: $dir"
