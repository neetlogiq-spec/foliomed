#!/usr/bin/env bash
# Build FolioMed for iOS on this Mac and send it to TestFlight.
#
#   APP_STORE_ISSUER_ID=<issuer-id> tools/release_ios.sh [build-number]
#
# Without a build number, uses the pubspec's +N plus one. Needs: Xcode with
# the iOS platform installed, the distribution certificate and profile in
# this Mac's keychain, ios/ExportOptions.plist, env.json, and the App Store
# Connect key at ~/.appstoreconnect/private_keys/AuthKey_ZCU49PSMCN.p8.
# Leaves pubspec.yaml changed — review and commit it yourself.
set -euo pipefail

cd "$(dirname "$0")/.."
: "${APP_STORE_ISSUER_ID:?export APP_STORE_ISSUER_ID first (App Store Connect → Users and Access → Integrations)}"
KEY_ID=ZCU49PSMCN

version_line=$(grep -E '^version: ' pubspec.yaml | cut -d' ' -f2)
marketing=${version_line%%+*}
build=${1:-$(( ${version_line##*+} + 1 ))}
perl -pi -e "s/^version: .*/version: ${marketing}+${build}/" pubspec.yaml
echo "FolioMed ${marketing} (${build})"

flutter build ipa --release \
  --dart-define-from-file=env.json \
  --export-options-plist=ios/ExportOptions.plist

ipa=$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -n1 || true)
[[ -n "$ipa" ]] || { echo "No .ipa was produced." >&2; exit 1; }

xcrun altool --upload-app --type ios --file "$ipa" \
  --apiKey "$KEY_ID" --apiIssuer "$APP_STORE_ISSUER_ID"

echo "Uploaded. It shows in TestFlight after Apple finishes processing (usually 5–15 min)."
