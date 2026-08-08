#!/bin/bash
set -euo pipefail

APP_PATH="${1:-}"
EXPECTED_APP_ID="com.daniele21.trafficmonitoring"
EXPECTED_EXTENSION_ID="com.daniele21.trafficmonitoring.filter"
EXPECTED_MACH_SERVICE="group.com.daniele21.trafficmonitoring.advanced-observability"

if [[ -z "$APP_PATH" ]]; then
  echo "Usage: $0 /path/to/TrafficMonitoring.app" >&2
  exit 64
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: app bundle not found: $APP_PATH" >&2
  exit 66
fi

EXT_PATH="$APP_PATH/Contents/Library/SystemExtensions/${EXPECTED_EXTENSION_ID}.systemextension"
if [[ ! -d "$EXT_PATH" ]]; then
  echo "ERROR: embedded system extension not found: $EXT_PATH" >&2
  exit 65
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

team_id() {
  codesign -d --verbose=4 "$1" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}'
}

entitlements_xml() {
  codesign -d --entitlements :- "$1" 2>/dev/null
}

contains_entitlement_value() {
  local bundle="$1"
  local expected="$2"
  entitlements_xml "$bundle" | grep -q "<string>${expected}</string>"
}

contains_entitlement_key() {
  local bundle="$1"
  local expected="$2"
  entitlements_xml "$bundle" | grep -q "<key>${expected}</key>"
}

echo "== Traffic Monitoring Advanced Observability signed-build preflight =="
echo "App: $APP_PATH"
echo "Extension: $EXT_PATH"

echo "\n[1/7] Verifying code signatures"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --strict --verbose=2 "$EXT_PATH"

echo "\n[2/7] Verifying bundle identifiers"
APP_ID="$(plist_value "$APP_PATH/Contents/Info.plist" CFBundleIdentifier)"
EXT_ID="$(plist_value "$EXT_PATH/Contents/Info.plist" CFBundleIdentifier)"
[[ "$APP_ID" == "$EXPECTED_APP_ID" ]] || { echo "ERROR: app bundle id is $APP_ID" >&2; exit 1; }
[[ "$EXT_ID" == "$EXPECTED_EXTENSION_ID" ]] || { echo "ERROR: extension bundle id is $EXT_ID" >&2; exit 1; }

echo "\n[3/7] Verifying Mach service"
MACH_SERVICE="$(plist_value "$EXT_PATH/Contents/Info.plist" NEMachServiceName)"
[[ "$MACH_SERVICE" == "$EXPECTED_MACH_SERVICE" ]] || { echo "ERROR: unexpected NEMachServiceName: $MACH_SERVICE" >&2; exit 1; }

echo "\n[4/7] Verifying stable Apple Developer Team identity"
APP_TEAM="$(team_id "$APP_PATH")"
EXT_TEAM="$(team_id "$EXT_PATH")"
if [[ -z "$APP_TEAM" || "$APP_TEAM" == "not set" ]]; then
  echo "ERROR: host app has no stable TeamIdentifier (ad-hoc builds cannot pass this gate)." >&2
  exit 1
fi
if [[ -z "$EXT_TEAM" || "$EXT_TEAM" == "not set" ]]; then
  echo "ERROR: system extension has no stable TeamIdentifier." >&2
  exit 1
fi
[[ "$APP_TEAM" == "$EXT_TEAM" ]] || { echo "ERROR: TeamIdentifier mismatch: app=$APP_TEAM extension=$EXT_TEAM" >&2; exit 1; }
echo "TeamIdentifier: $APP_TEAM"

echo "\n[5/7] Verifying host entitlements"
contains_entitlement_key "$APP_PATH" "com.apple.developer.system-extension.install" || { echo "ERROR: host is missing system-extension install entitlement" >&2; exit 1; }
contains_entitlement_value "$APP_PATH" "content-filter-provider-systemextension" || { echo "ERROR: host is missing content-filter Network Extension entitlement" >&2; exit 1; }

echo "\n[6/7] Verifying provider entitlements"
contains_entitlement_value "$EXT_PATH" "content-filter-provider-systemextension" || { echo "ERROR: provider is missing content-filter Network Extension entitlement" >&2; exit 1; }

echo "\n[7/7] Verifying designated requirements"
codesign -d -r- "$APP_PATH" 2>&1 | sed -n 's/^designated => /Host: /p'
codesign -d -r- "$EXT_PATH" 2>&1 | sed -n 's/^designated => /Provider: /p'

echo "\nPASS: bundle structure, signatures, Team ID, entitlements and Mach service are consistent."
echo "Next gate: install/approve the system extension on a real Mac and run the controlled B1 validation matrix."
