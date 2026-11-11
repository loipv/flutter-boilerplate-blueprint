#!/usr/bin/env bash
# End-to-end check for tool/init.dart.
#
# Usage (from the repository root): tool/verify_init.sh [init flags...]
#
# Copies the working tree (tracked and untracked, not ignored) to a temporary
# directory, runs init there with the given flags, checks the result, then runs
# `make setup analyze test`. Prints `OK` on success and deletes the temporary
# directory (set VERIFY_KEEP=1 to keep it); any failed check exits non-zero and
# keeps the directory for inspection.
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  [ -z "${dir:-}" ] || echo "Kept for inspection: $dir" >&2
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

gradle=android/app/build.gradle.kts
pbxproj=ios/Runner.xcodeproj/project.pbxproj
if [[ " $* " == *" --shared-app-id "* ]]; then
  ! grep -q 'applicationIdSuffix' "$gradle" || fail "$gradle still has applicationIdSuffix"
  ! grep -q 'PRODUCT_BUNDLE_IDENTIFIER = .*\.staging;' "$pbxproj" || fail "$pbxproj still has a .staging bundle id"
  echo "App id: shared by staging and production"
else
  grep -q 'applicationIdSuffix = ".staging"' "$gradle" || fail "$gradle lost applicationIdSuffix"
  grep -q 'PRODUCT_BUNDLE_IDENTIFIER = .*\.staging;' "$pbxproj" || fail "$pbxproj lost the .staging bundle id"
  echo "App id: staging uses the .staging suffix"
fi

make setup analyze test || fail "make setup analyze test"

if [ -n "${VERIFY_KEEP:-}" ]; then
  echo "OK: $dir"
else
  cd /
  rm -rf "$dir"
  echo "OK"
fi
