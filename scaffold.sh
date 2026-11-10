#!/usr/bin/env bash
# Creates a new Flutter + Firebase app from flutter-boilerplate-blueprint.
#
# Remote (downloads the full script before executing):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)" _ my_app [init flags]
#   BLUEPRINT_REF=v1.0.0 selects a tag or branch (default: main).
# Local (from a clone of the blueprint):
#   bash scaffold.sh my_app [init flags]
# Init flags: --name --org --title --description --yes --no-notifications|posthog|sentry|functions|apple|google|anon
# Review this script before running it.

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This scaffold requires bash." >&2
  echo "Run it with: bash scaffold.sh" >&2
  exit 1
fi

set -euo pipefail

REPO="https://github.com/loipv/flutter-boilerplate-blueprint.git"
command -v git >/dev/null || { echo "git is required." >&2; exit 1; }
if command -v fvm >/dev/null; then DART="fvm dart"; else
  command -v dart >/dev/null || { echo "fvm or dart is required." >&2; exit 1; }
  DART="dart"
fi

if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then target="$1"; shift; else
  read -r -p "Target directory: " target </dev/tty
fi
[ -n "$target" ] || { echo "Target directory is required." >&2; exit 1; }
[ ! -e "$target" ] || { echo "Directory already exists: $target" >&2; exit 1; }
mkdir -p "$(dirname "$target")"
target="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"

here="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || true)"
if [ -n "$here" ] && [ -f "$here/tool/init.dart" ]; then
  # Clones the committed HEAD of the current branch; uncommitted changes are not included.
  git clone --depth 1 --quiet "file://$here" "$target"
else
  git clone --depth 1 --quiet --branch "${BLUEPRINT_REF:-main}" "$REPO" "$target"
fi
rm -rf "$target/.git"
cd "$target"

command -v fvm >/dev/null && fvm install
rc=0
$DART tool/init.dart "$@" || rc=$?
[ "$rc" -eq 0 ] || exit "$rc"
make setup
echo "Done. Read docs/next_steps.md for the remaining setup steps."
