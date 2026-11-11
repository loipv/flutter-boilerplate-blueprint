#!/usr/bin/env bash
# Creates a new Flutter + Firebase app from flutter-boilerplate-blueprint.
#
# Remote (downloads the full script before executing):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)" _ my_app [init flags]
#   BLUEPRINT_REF=v1.0.0 selects a tag or branch (default: main). Tags before
#   v1.0.0 have no tool/init.dart; scaffold those with their own scaffold.sh.
# Local (from a clone of the blueprint):
#   bash scaffold.sh my_app [init flags]
#   Clones the clone's committed HEAD, or BLUEPRINT_REF (a tag or branch in the clone).
# Init flags: --name --org --title --description --yes --shared-app-id
#   --no-notifications|posthog|sentry|functions|apple|google|anon
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
top=""; d="$(dirname "$target")"  # top: highest parent that mkdir -p creates
while [ ! -e "$d" ]; do top="$d"; d="$(dirname "$d")"; done
mkdir -p "$(dirname "$target")"
target="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
[ -z "$top" ] || top="$(cd "$top" && pwd)"

keep=0  # until init succeeds, a failure or Ctrl+C removes what this script created
cleanup() {
  [ "$keep" = 0 ] || return 0
  cd /; rm -rf "$target" ${top:+"$top"}; echo "Removed $target; nothing was created." >&2
}
trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM

# Local mode only when run as a file from a blueprint clone. Under
# `bash -c "$(curl ...)"` BASH_SOURCE is empty, so the current directory is
# never mistaken for the blueprint.
src=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$here/tool/init.dart" ]; then src="$here"; fi
fi

ref="${BLUEPRINT_REF:-}"
if [ -n "$src" ] && [ -n "$ref" ]; then
  echo "Using blueprint $ref from $src"
  git -c advice.detachedHead=false clone --depth 1 --quiet --branch "$ref" "file://$src" "$target"
elif [ -n "$src" ]; then
  # The committed HEAD of the current branch; uncommitted changes are not included.
  echo "Using blueprint HEAD ($(git -C "$src" rev-parse --short HEAD)) from $src"
  git clone --depth 1 --quiet "file://$src" "$target"
else
  ref="${ref:-main}"
  echo "Using blueprint $ref from $REPO"
  git -c advice.detachedHead=false clone --depth 1 --quiet --branch "$ref" "$REPO" "$target"
fi
if [ ! -f "$target/tool/init.dart" ]; then
  echo "Blueprint $ref predates v1.0.0 (no tool/init.dart), so this script cannot scaffold it." >&2
  echo "Use that version's own script instead:" >&2
  echo "  git clone --depth 1 --branch $ref $REPO blueprint-$ref && bash blueprint-$ref/scaffold.sh" >&2
  exit 1
fi
rm -rf "$target/.git"
cd "$target"

command -v fvm >/dev/null && fvm install
$DART tool/init.dart "$@"
keep=1
make setup || { echo "make setup failed; your app is in $target. Fix the error and run make setup there." >&2; exit 1; }
echo "Done. Read docs/next_steps.md for the remaining setup steps."
