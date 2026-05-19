#!/usr/bin/env bash
# =============================================================================
# flutter-boilerplate-blueprint scaffold
#
# Creates a production-ready Flutter + Firebase app from the blueprint template.
#
# Run remotely (downloads full script before executing; no partial execution):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)"
#
# Run locally (after cloning the repo):
#   bash scaffold.sh
#
# Security note: review this script at the URL above before running it.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This scaffold requires bash." >&2
  echo "Run it with: bash scaffold.sh" >&2
  echo 'Remote usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/loipv/flutter-boilerplate-blueprint/main/scaffold.sh)"' >&2
  exit 1
fi

set -euo pipefail

TEMPLATE_REPO="https://github.com/loipv/flutter-boilerplate-blueprint.git"
BLUEPRINT_VERSION="0.6.0"
FLUTTER_VERSION="3.41.4"
HAS_FVM=false
HAS_FLUTTER=false

# =============================================================================
# Terminal helpers
# =============================================================================
bold()   { printf '\033[1m%s\033[0m' "$*"; }
green()  { printf '\033[0;32m%s\033[0m' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m' "$*"; }
red()    { printf '\033[0;31m%s\033[0m' "$*"; }
cyan()   { printf '\033[0;36m%s\033[0m' "$*"; }

step()  { echo ""; echo "$(cyan '▸') $(bold "$1")"; }
info()  { echo "  $(green '✓') $1"; }
warn()  { echo "  $(yellow '⚠') $1"; }
fatal() { echo "  $(red '✗') $1" >&2; exit 1; }

prompt() {
  local question="$1" default="${2:-}" answer
  if [ -n "$default" ]; then
    printf '  %s [%s]: ' "$question" "$(bold "$default")" >/dev/tty
  else
    printf '  %s: ' "$question" >/dev/tty
  fi
  read -r answer </dev/tty
  echo "${answer:-$default}"
}

prompt_yn() {
  local question="$1" default="${2:-Y}" answer
  local yn_display
  if [ "$default" = "Y" ]; then yn_display="Y/n"; else yn_display="y/N"; fi
  printf '  %s [%s]: ' "$question" "$yn_display" >/dev/tty
  read -r answer </dev/tty
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy] ]]
}

prompt_choice() {
  local question="$1" default="${2:-1}" answer
  printf '  %s [%s]: ' "$question" "$default" >/dev/tty
  read -r answer </dev/tty
  echo "${answer:-$default}"
}

# =============================================================================
# Prerequisites
# =============================================================================
check_prerequisites() {
  step "Checking prerequisites"
  command -v git >/dev/null 2>&1 || fatal "git is required (https://git-scm.com)"
  info "git $(git --version | awk '{print $3}')"

  if command -v fvm >/dev/null 2>&1; then
    info "fvm $(fvm --version 2>/dev/null || echo 'found')"
    HAS_FVM=true
  else
    HAS_FVM=false
    warn "fvm not found; will offer bare flutter as fallback"
  fi

  if command -v flutter >/dev/null 2>&1; then
    info "flutter $(flutter --version --machine 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('frameworkVersion',''))" 2>/dev/null || echo 'found')"
    HAS_FLUTTER=true
  else
    HAS_FLUTTER=false
  fi

  if ! $HAS_FVM && ! $HAS_FLUTTER; then
    fatal "Flutter (or FVM) is required. Install at https://flutter.dev or https://fvm.app"
  fi
}

# =============================================================================
# Color presets
# =============================================================================
apply_color_preset() {
  case "$1" in
    1) # Sage Green
      PRIMARY_LIGHT="3C5A4D"; PRIMARY_DARK="7CA692"
      ACCENT="5BA87F"; BG_LIGHT="F9F9F6"; BG_DARK="121614"; SPLASH_BG="141D21"
      ;;
    2) # Ocean Blue
      PRIMARY_LIGHT="1A5276"; PRIMARY_DARK="5DADE2"
      ACCENT="2E86C1"; BG_LIGHT="F4F6F9"; BG_DARK="0D1117"; SPLASH_BG="0D1117"
      ;;
    3) # Warm Amber
      PRIMARY_LIGHT="B7580D"; PRIMARY_DARK="F0A500"
      ACCENT="E67E22"; BG_LIGHT="FFFBF5"; BG_DARK="1A1209"; SPLASH_BG="1A1209"
      ;;
    4) # Deep Purple
      PRIMARY_LIGHT="5B2C8B"; PRIMARY_DARK="A569BD"
      ACCENT="8E44AD"; BG_LIGHT="F8F4FC"; BG_DARK="12071A"; SPLASH_BG="12071A"
      ;;
    5) # Midnight Slate
      PRIMARY_LIGHT="2C3E50"; PRIMARY_DARK="85929E"
      ACCENT="5D6D7E"; BG_LIGHT="F5F5F5"; BG_DARK="0A0E13"; SPLASH_BG="0A0E13"
      ;;
    *) fatal "Invalid color preset: $1" ;;
  esac
}

# Convert #RRGGBB or RRGGBB to 0xFFRRGGBB (Dart Color format)
to_dart_color() {
  local hex="${1#'#'}"
  echo "0xFF$(echo "$hex" | tr '[:lower:]' '[:upper:]')"
}

# snake_case → PascalCase
to_pascal() {
  echo "$1" | awk -F'_' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}' OFS=''
}

# Display name → snake_case default
to_snake() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | sed 's/[^a-z0-9_]//g'
}

# =============================================================================
# Token replacement: run on every text file in the output directory
# =============================================================================
replace_tokens() {
  local dir="$1"
  find "$dir" -type f \( \
    -name "*.dart" -o -name "*.yaml" -o -name "*.json" \
    -o -name "*.md" -o -name "*.rules" -o -name "*.plist" \
    -o -name "*.entitlements" -o -name "*.xcprivacy" \
    -o -name "*.pbxproj" -o -name "*.xcscheme" -o -name "*.xml" \
    -o -name "*.kts" -o -name "Makefile" \
    -o -name ".env*" -o -name ".firebaserc" \
  \) | while IFS= read -r file; do
    # Skip binary files (fonts, compiled assets). Use `file -b` so the path
    # itself isn't matched — paths like `lib/.../data/` previously caused
    # text files to be skipped because `file`'s output included the filename.
    if file -b "$file" 2>/dev/null | grep -qE '(font|executable|compiled)'; then continue; fi
    sed -i '' \
      -e "s|__APP_PACKAGE__|${APP_PACKAGE}|g" \
      -e "s|__APP_TITLE__|${APP_TITLE}|g"      \
      -e "s|__APP_ORG__|${APP_ORG}|g"           \
      -e "s|__APP_DESC__|${APP_DESC}|g"          \
      -e "s|__BLUEPRINT_VERSION__|${BLUEPRINT_VERSION}|g" \
      -e "s|__PRIMARY_LIGHT__|${PRIMARY_LIGHT_DART}|g" \
      -e "s|__PRIMARY_DARK__|${PRIMARY_DARK_DART}|g"   \
      -e "s|__ACCENT__|${ACCENT_DART}|g"               \
      -e "s|__BG_LIGHT__|${BG_LIGHT_DART}|g"           \
      -e "s|__BG_DARK__|${BG_DARK_DART}|g"             \
      -e "s|__SPLASH_BG__|${SPLASH_BG_DART}|g"         \
      -e "s|__FLUTTER_CMD__|${FLUTTER_CMD}|g"          \
      "$file" 2>/dev/null || true
  done
}

# =============================================================================
# Main
# =============================================================================
main() {
  echo ""
  echo "$(bold '  flutter-boilerplate-blueprint')"
  echo "  $(cyan "Production-ready Flutter + Firebase scaffolder v${BLUEPRINT_VERSION}")"
  echo ""
  echo "  Press Enter to accept defaults. Ctrl+C to cancel."

  check_prerequisites

  # ---------------------------------------------------------------------------
  step "App identity"
  # ---------------------------------------------------------------------------
  APP_TITLE=$(prompt "App display name" "My App")
  DEFAULT_PKG=$(to_snake "$APP_TITLE")
  APP_PACKAGE=$(prompt "Package name (snake_case)" "$DEFAULT_PKG")
  APP_ORG=$(prompt "Organization (reverse domain)" "com.example")
  APP_DESC=$(prompt "Short description" "A new Flutter app")

  DEFAULT_DIR="$(pwd -P)/$APP_PACKAGE"
  OUTPUT_DIR=$(prompt "Output directory" "$DEFAULT_DIR")
  OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

  # ---------------------------------------------------------------------------
  step "Features"
  # ---------------------------------------------------------------------------
  prompt_yn "Include anonymous sign-in? (recommended)" "Y" && USE_ANON=true  || USE_ANON=false
  prompt_yn "Include Apple Sign-In?" "Y"                   && USE_APPLE=true || USE_APPLE=false
  prompt_yn "Include Google Sign-In?" "Y"                  && USE_GOOGLE=true || USE_GOOGLE=false
  prompt_yn "Include push notifications?" "Y"              && USE_NOTIFICATIONS=true || USE_NOTIFICATIONS=false
  prompt_yn "Include PostHog analytics?" "Y"               && USE_POSTHOG=true || USE_POSTHOG=false
  prompt_yn "Include Sentry error monitoring?" "Y"         && USE_SENTRY=true  || USE_SENTRY=false
  prompt_yn "Scaffold Cloud Functions (TypeScript)?" "Y"   && USE_FUNCTIONS=true || USE_FUNCTIONS=false

  if $HAS_FVM; then
    prompt_yn "Use FVM for Flutter version management?" "Y" && USE_FVM=true || USE_FVM=false
    if $USE_FVM; then
      echo "  Which Flutter SDK should FVM manage?"
      echo "    1. Blueprint-tested version (${FLUTTER_VERSION})  $(cyan '[default]')"
      echo "    2. Latest stable channel"
      FLUTTER_VERSION_CHOICE=$(prompt_choice "Choice" "1")
      case "$FLUTTER_VERSION_CHOICE" in
        2) FVM_FLUTTER_REF="stable" ;;
        *) FVM_FLUTTER_REF="$FLUTTER_VERSION" ;;
      esac
    fi
  else
    USE_FVM=false
  fi

  # ---------------------------------------------------------------------------
  step "AI coding assistant"
  # ---------------------------------------------------------------------------
  echo "  Which AI coding assistant will you use?"
  echo "    1. Claude Code  $(cyan '[default]')"
  echo "    2. OpenAI Codex"
  echo "    3. Gemini CLI"
  echo "    4. None"
  AI_CHOICE=$(prompt_choice "Choice" "1")
  case "$AI_CHOICE" in
    2) AI_TOOL="codex"  ;;
    3) AI_TOOL="gemini" ;;
    4) AI_TOOL="none"   ;;
    *) AI_TOOL="claude" ;;
  esac

  # ---------------------------------------------------------------------------
  step "Navigation"
  # ---------------------------------------------------------------------------
  echo "  Bottom nav tab layout:"
  echo "    1. 2 tabs: Home + Profile"
  echo "    2. 3 tabs: Home + Explore + Profile  $(cyan '[default]')"
  echo "    3. 4 tabs: Home + Explore + Library + Profile"
  TAB_CHOICE=$(prompt_choice "Choice" "2")
  case "$TAB_CHOICE" in
    1) TAB_COUNT=2 ;;
    3) TAB_COUNT=4 ;;
    *) TAB_COUNT=3 ;;
  esac

  # ---------------------------------------------------------------------------
  step "Branding"
  # ---------------------------------------------------------------------------
  echo "  Color presets:"
  echo "    1. Sage Green   $(cyan '[default]')"
  echo "    2. Ocean Blue"
  echo "    3. Warm Amber"
  echo "    4. Deep Purple"
  echo "    5. Midnight Slate"
  echo "    6. Custom hex values"
  COLOR_CHOICE=$(prompt_choice "Preset" "1")

  if [ "$COLOR_CHOICE" = "6" ]; then
    PRIMARY_LIGHT=$(prompt "Primary color, light mode hex (no #)" "3C5A4D")
    PRIMARY_DARK=$(prompt "Primary color, dark mode hex  (no #)" "7CA692")
    ACCENT=$(prompt "Accent / secondary color hex  (no #)" "5BA87F")
    BG_LIGHT=$(prompt "Light background hex          (no #)" "F9F9F6")
    BG_DARK=$(prompt "Dark background hex           (no #)" "121614")
    SPLASH_BG=$(prompt "Splash background hex         (no #)" "141D21")
  else
    apply_color_preset "$COLOR_CHOICE"
  fi

  # ---------------------------------------------------------------------------
  # Derived values
  # ---------------------------------------------------------------------------
  FLUTTER_CMD=$( $USE_FVM && echo "fvm flutter" || echo "flutter" )

  PRIMARY_LIGHT_DART=$(to_dart_color "$PRIMARY_LIGHT")
  PRIMARY_DARK_DART=$(to_dart_color  "$PRIMARY_DARK")
  ACCENT_DART=$(to_dart_color        "$ACCENT")
  BG_LIGHT_DART=$(to_dart_color      "$BG_LIGHT")
  BG_DARK_DART=$(to_dart_color       "$BG_DARK")
  SPLASH_BG_DART=$(to_dart_color     "$SPLASH_BG")

  # ---------------------------------------------------------------------------
  step "Summary"
  # ---------------------------------------------------------------------------
  echo ""
  printf '  %-18s %s\n' "Blueprint:"    "v${BLUEPRINT_VERSION}"
  printf '  %-18s %s\n' "App title:"    "$(bold "$APP_TITLE")"
  printf '  %-18s %s\n' "Package:"      "$APP_PACKAGE"

  printf '  %-18s %s\n' "Org:"          "$APP_ORG"
  printf '  %-18s %s\n' "Output:"       "$OUTPUT_DIR"
  printf '  %-18s %s\n' "Tabs:"         "$TAB_COUNT"
  printf '  %-18s %s\n' "AI assistant:" "$AI_TOOL"
  printf '  %-18s %s\n' "Flutter:"      "$FLUTTER_CMD"
  if $USE_FVM; then
    printf '  %-18s %s\n' "FVM SDK:"       "$FVM_FLUTTER_REF"
  fi
  printf '  %-18s Apple=%s  Google=%s  Anon=%s\n' "Auth:" \
    "$($USE_APPLE && echo y || echo n)" \
    "$($USE_GOOGLE && echo y || echo n)" \
    "$($USE_ANON && echo y || echo n)"
  printf '  %-18s PostHog=%s  Sentry=%s  Notifications=%s  Functions=%s\n' "Services:" \
    "$($USE_POSTHOG && echo y || echo n)" \
    "$($USE_SENTRY && echo y || echo n)" \
    "$($USE_NOTIFICATIONS && echo y || echo n)" \
    "$($USE_FUNCTIONS && echo y || echo n)"
  echo ""

  prompt_yn "Proceed?" "Y" || { echo "Aborted."; exit 0; }

  # ---------------------------------------------------------------------------
  step "Locating template"
  # ---------------------------------------------------------------------------
  # When run via bash -c "$(curl -fsSL URL)" the script runs from a temp fd;
  # BASH_SOURCE[0] resolves to /dev/stdin or similar. Fall back to cloning.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo '')"
  if [ -d "${SCRIPT_DIR}/template" ]; then
    TEMPLATE_DIR="${SCRIPT_DIR}/template"
    info "Using local template at $TEMPLATE_DIR"
  else
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    info "Cloning template (depth 1)…"
    git clone --depth 1 --quiet "$TEMPLATE_REPO" "$TEMP_DIR/repo" \
      || fatal "Could not clone $TEMPLATE_REPO; check the URL at the top of scaffold.sh"
    TEMPLATE_DIR="$TEMP_DIR/repo/template"
    info "Template downloaded"
  fi

  # ---------------------------------------------------------------------------
  step "Creating Flutter project"
  # ---------------------------------------------------------------------------
  [ -d "$OUTPUT_DIR" ] && fatal "Directory already exists: $OUTPUT_DIR"

  $FLUTTER_CMD create \
    --org "$APP_ORG" \
    --project-name "$APP_PACKAGE" \
    --description "$APP_DESC"    \
    --platforms ios,android       \
    "$OUTPUT_DIR" >/dev/null
  info "flutter create complete"

  # ---------------------------------------------------------------------------
  step "Overlaying blueprint template"
  # ---------------------------------------------------------------------------
  cp -r "$TEMPLATE_DIR/." "$OUTPUT_DIR/"
  info "Template files copied"
  printf 'Blueprint version: v%s\n' "$BLUEPRINT_VERSION" > "$OUTPUT_DIR/BLUEPRINT_VERSION.md"
  info "Blueprint version stamped: v${BLUEPRINT_VERSION}"

  # Select correct router + scaffold variant for chosen tab count
  for variant in 2 3 4; do
    src_router="$OUTPUT_DIR/lib/core/router/app_router_${variant}tabs.dart"
    src_scaffold="$OUTPUT_DIR/lib/core/presentation/main_scaffold_${variant}tabs.dart"
    if [ "$variant" = "$TAB_COUNT" ]; then
      cp "$src_router"   "$OUTPUT_DIR/lib/core/router/app_router.dart"
      # Fix the part directive to match the canonical filename after copy
      python3 -c "
import sys
path = sys.argv[1]
content = open(path).read()
content = content.replace(\"part 'app_router_${variant}tabs.g.dart';\", \"part 'app_router.g.dart';\")
open(path, 'w').write(content)
" "$OUTPUT_DIR/lib/core/router/app_router.dart"
      cp "$src_scaffold" "$OUTPUT_DIR/lib/core/presentation/main_scaffold.dart"
    fi
    rm -f "$src_router" "$src_scaffold"
  done
  info "Navigation layout: ${TAB_COUNT} tabs"

  # Rename the single AGENT.md template to the tool-specific filename
  case "$AI_TOOL" in
    claude) mv "$OUTPUT_DIR/AGENT.md" "$OUTPUT_DIR/CLAUDE.md"
            sed -i '' 's|__AI_TOOL_NAME__|CLAUDE.md|g' "$OUTPUT_DIR/CLAUDE.md"
            info "AI agent bootloader: CLAUDE.md" ;;
    codex)  mv "$OUTPUT_DIR/AGENT.md" "$OUTPUT_DIR/CODEX.md"
            sed -i '' 's|__AI_TOOL_NAME__|CODEX.md|g' "$OUTPUT_DIR/CODEX.md"
            info "AI agent bootloader: CODEX.md" ;;
    gemini) mv "$OUTPUT_DIR/AGENT.md" "$OUTPUT_DIR/GEMINI.md"
            sed -i '' 's|__AI_TOOL_NAME__|GEMINI.md|g' "$OUTPUT_DIR/GEMINI.md"
            info "AI agent bootloader: GEMINI.md" ;;
    none)   rm -f "$OUTPUT_DIR/AGENT.md"
            info "No AI agent bootloader" ;;
  esac

  # ---------------------------------------------------------------------------
  step "Applying configuration tokens"
  # ---------------------------------------------------------------------------
  replace_tokens "$OUTPUT_DIR"
  info "Tokens replaced"

  # ---------------------------------------------------------------------------
  step "Configuring optional features"
  # ---------------------------------------------------------------------------
  PUBSPEC="$OUTPUT_DIR/pubspec.yaml"

  strip_marked_block() {
    local file="$1"
    local marker="$2"
    sed -i '' "/BEGIN_${marker}/,/END_${marker}/d" "$file"
  }

  if ! $USE_NOTIFICATIONS; then
    sed -i '' '/flutter_local_notifications/d; /timezone:/d; /flutter_timezone/d; /workmanager/d' "$PUBSPEC"
    rm -f "$OUTPUT_DIR/lib/core/services/notification_service.dart"
    rm -f "$OUTPUT_DIR/lib/core/services/timezone_lifecycle_observer.dart"
    rm -f "$OUTPUT_DIR/lib/core/services/timezone_sync_service.dart"
    rm -rf "$OUTPUT_DIR/lib/features/notifications"
    strip_marked_block "$OUTPUT_DIR/lib/app.dart" "NOTIFICATIONS"
    strip_marked_block "$OUTPUT_DIR/lib/main_staging.dart" "NOTIFICATIONS"
    strip_marked_block "$OUTPUT_DIR/lib/main_production.dart" "NOTIFICATIONS"
    strip_marked_block "$OUTPUT_DIR/lib/features/settings/presentation/settings_screen.dart" "NOTIFICATIONS_IMPORTS"
    strip_marked_block "$OUTPUT_DIR/lib/features/settings/presentation/settings_screen.dart" "NOTIFICATIONS_SECTION"
    strip_marked_block "$OUTPUT_DIR/lib/features/settings/presentation/settings_screen.dart" "NOTIFICATIONS_HELPERS"
    strip_marked_block "$OUTPUT_DIR/android/app/src/main/AndroidManifest.xml" "NOTIFICATIONS"
    strip_marked_block "$OUTPUT_DIR/ios/Runner/Info.plist" "NOTIFICATIONS"
    warn "Notifications removed from code scaffold and platform config"
  fi
  if ! $USE_POSTHOG; then
    sed -i '' '/posthog_flutter/d' "$PUBSPEC"
    warn "PostHog removed. Replace AnalyticsRepository impl or leave as no-op stub"
  fi
  if ! $USE_SENTRY; then
    sed -i '' '/sentry_flutter/d; /sentry_dart_plugin/d' "$PUBSPEC"
    sed -i '' '/sentry/Id' "$OUTPUT_DIR/lib/core/utils/app_logger.dart" 2>/dev/null || true
    warn "Sentry removed. AppLogger will no longer forward errors to Sentry"
  fi
  if ! $USE_APPLE; then
    sed -i '' '/sign_in_with_apple/d' "$PUBSPEC"
    warn "Apple Sign-In removed. Delete signInWithApple() calls from auth_controller.dart"
  fi
  if ! $USE_GOOGLE; then
    sed -i '' '/google_sign_in/d' "$PUBSPEC"
    warn "Google Sign-In removed. Delete signInWithGoogle() calls from auth_controller.dart"
  fi

  if $USE_FUNCTIONS; then
    info "Cloud Functions scaffold included (functions/)"
    # Replace the generic package name in package.json
    sed -i '' "s|__APP_PACKAGE__-functions|${APP_PACKAGE}-functions|g" "$OUTPUT_DIR/functions/package.json"
    sed -i '' "s|__APP_TITLE__|${APP_TITLE}|g"                         "$OUTPUT_DIR/functions/package.json"
  else
    rm -rf "$OUTPUT_DIR/functions"
    # Remove functions block from firebase.json so `firebase deploy` doesn't error
    python3 -c "
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data.pop('functions', None)
json.dump(data, open(path, 'w'), indent=2)
print()
" "$OUTPUT_DIR/firebase.json"
    info "Cloud Functions scaffold removed"
  fi

  if $USE_FVM; then
    printf '{"flutter": "%s"}\n' "$FVM_FLUTTER_REF" > "$OUTPUT_DIR/.fvmrc"
    info "FVM config written (.fvmrc)"
  else
    rm -f "$OUTPUT_DIR/.fvmrc"
    sed -i '' 's|fvm flutter|flutter|g' "$OUTPUT_DIR/Makefile"
  fi

  # ---------------------------------------------------------------------------
  step "Creating environment stubs"
  # ---------------------------------------------------------------------------
  # Copy the documented example files and name them as the live env files.
  # They ship with placeholder values — the user fills them in before running.
  cp "$OUTPUT_DIR/.env.staging.example"    "$OUTPUT_DIR/.env.staging"
  cp "$OUTPUT_DIR/.env.production.example" "$OUTPUT_DIR/.env.production"
  info ".env.staging and .env.production stubs created (from .example files)"

  # ---------------------------------------------------------------------------
  step "Installing dependencies"
  # ---------------------------------------------------------------------------
  cd "$OUTPUT_DIR"
  $FLUTTER_CMD pub get
  info "pub get complete"

  if $USE_FUNCTIONS; then
    info "Installing Cloud Functions dependencies..."
    cd "$OUTPUT_DIR/functions" && npm install --silent && cd "$OUTPUT_DIR"
    info "npm install complete"
  fi

  # ---------------------------------------------------------------------------
  step "Running code generation"
  # ---------------------------------------------------------------------------
  $FLUTTER_CMD pub run build_runner build --delete-conflicting-outputs
  info "build_runner complete"

  # ---------------------------------------------------------------------------
  step "Done"
  # ---------------------------------------------------------------------------
  echo ""
  echo "  $(green "$(bold "$APP_TITLE")") created at $(bold "$OUTPUT_DIR")"
  echo ""
  echo "  $(bold 'Next steps:')"
  echo ""
  echo "  1. $(bold 'Add your app logo')"
  echo "     Replace: $OUTPUT_DIR/assets/icons/app_logo.png"
  echo "     (1024×1024 PNG, used by flutter_launcher_icons)"
  echo ""
  echo "  2. $(bold 'Create two Firebase projects')  (staging + production)"
  echo "     https://console.firebase.google.com"
  echo ""
  echo "  3. $(bold 'Generate Firebase config files')"
  echo "     cd $OUTPUT_DIR"
  echo "     flutterfire configure --project=<staging-id>    --out=lib/firebase_options_staging.dart"
  echo "     flutterfire configure --project=<production-id> --out=lib/firebase_options_production.dart"
  echo ""
  echo "  4. $(bold 'Fill in environment variables')"
  echo "     $OUTPUT_DIR/.env.staging"
  echo "     $OUTPUT_DIR/.env.production"
  echo ""
  if $USE_FUNCTIONS; then
  echo "  5. $(bold 'Deploy Cloud Functions')"
  echo "     cd $OUTPUT_DIR && make deploy-functions-staging"
  echo "     Edit functions/src/index.ts — remove the hello-world starters"
  echo ""
  echo "  6. $(bold 'Run the app')"
  else
  echo "  5. $(bold 'Run the app')"
  fi
  echo "     cd $OUTPUT_DIR && make run-staging"
  echo ""
  echo "  See $(bold 'docs/next_steps.md') for the full checklist and use-case guide."
  echo "  See $(bold 'docs/setup.md') for detailed Firebase setup."
  echo ""
}

main "$@"
