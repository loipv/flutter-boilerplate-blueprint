#!/usr/bin/env bash
# Writes placeholder staging Firebase config files so the staging flavor
# builds for `make test-integration`, which talks only to the local emulator
# (project demo-test). An existing file is never overwritten, so a real
# flutterfire config always wins. Both paths are gitignored.
#
# Usage (from anywhere): scripts/integration_stubs.sh
set -euo pipefail

cd "$(dirname "$0")/.."

android_json=android/app/src/staging/google-services.json
ios_plist=ios/config/Staging/GoogleService-Info.plist

# Android package: applicationId, plus ".staging" when the staging flavor
# declares that suffix (init --shared-app-id removes it).
gradle=android/app/build.gradle.kts
package_name=$(sed -nE 's/^[[:space:]]*applicationId[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$gradle" | head -n 1)
[ -n "$package_name" ] || { echo "No applicationId in $gradle" >&2; exit 1; }
if grep -q 'applicationIdSuffix = ".staging"' "$gradle"; then
  package_name="$package_name.staging"
fi

# iOS bundle id: the Runner staging id if one exists, else the Runner id.
pbxproj=ios/Runner.xcodeproj/project.pbxproj
bundle_ids=$(sed -nE 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;/\1/p' "$pbxproj" | grep -v 'RunnerTests' || true)
bundle_id=$(printf '%s\n' "$bundle_ids" | grep '\.staging$' | head -n 1 || true)
[ -n "$bundle_id" ] || bundle_id=$(printf '%s\n' "$bundle_ids" | head -n 1)
[ -n "$bundle_id" ] || { echo "No PRODUCT_BUNDLE_IDENTIFIER in $pbxproj" >&2; exit 1; }

if [ ! -e "$android_json" ]; then
  mkdir -p "$(dirname "$android_json")"
  cat > "$android_json" <<EOF
{
  "project_info": {
    "project_number": "1",
    "project_id": "demo-test",
    "storage_bucket": "demo-test.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:1:android:1",
        "android_client_info": {
          "package_name": "$package_name"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "demo"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF
  echo "Wrote stub $android_json (package $package_name)"
fi

if [ ! -e "$ios_plist" ]; then
  mkdir -p "$(dirname "$ios_plist")"
  # CLIENT_ID and REVERSED_CLIENT_ID are read by the "Copy
  # GoogleService-Info.plist" build phase.
  cat > "$ios_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>demo</string>
	<key>GCM_SENDER_ID</key>
	<string>1</string>
	<key>PROJECT_ID</key>
	<string>demo-test</string>
	<key>BUNDLE_ID</key>
	<string>$bundle_id</string>
	<key>GOOGLE_APP_ID</key>
	<string>1:1:ios:1</string>
	<key>CLIENT_ID</key>
	<string>1-demo.apps.googleusercontent.com</string>
	<key>REVERSED_CLIENT_ID</key>
	<string>com.googleusercontent.apps.1-demo</string>
	<key>STORAGE_BUCKET</key>
	<string>demo-test.appspot.com</string>
</dict>
</plist>
EOF
  echo "Wrote stub $ios_plist (bundle $bundle_id)"
fi
