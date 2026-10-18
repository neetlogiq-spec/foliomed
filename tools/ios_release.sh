#!/bin/bash
# One-command iOS release: bump build number -> build IPA -> upload to App Store Connect.
#
# Usage:  ./tools/ios_release.sh
#
# Prereqs (one-time):
#   - Apple Distribution cert in Keychain
#   - ~/Library/MobileDevice/Provisioning Profiles/FolioMed_App_Store.mobileprovision
#   - ios/ExportOptions.plist + project.pbxproj with your Team ID
#   - ~/.appstoreconnect/private_keys/AuthKey_ZCU49PSMCN.p8
#     (mkdir -p ~/.appstoreconnect/private_keys && mv ~/Downloads/AuthKey_ZCU49PSMCN.p8 "$_")
#   - env.json with SUPABASE_ANON_KEY (see env.example.json)
#   - APP_STORE_ISSUER_ID exported (App Store Connect → Users and Access →
#     Integrations → App Store Connect API → Issuer ID)
#
# After this finishes: wait ~10 min, the build shows up in App Store
# Connect > TestFlight. Then select it on the version page + Submit.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_KEY_ID="ZCU49PSMCN"
API_ISSUER_ID="${APP_STORE_ISSUER_ID:?Set APP_STORE_ISSUER_ID to your App Store Connect issuer ID}"

cd "$PROJECT_DIR"

echo "==> Bumping build number..."
# version line looks like: version: 1.4.0+17  -> increment the +N
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: //')
NAME="${CURRENT%+*}"      # 1.4.0
BUILD="${CURRENT#*+}"     # 17
NEW_BUILD=$((BUILD + 1))
sed -i '' "s/^version: .*/version: ${NAME}+${NEW_BUILD}/" pubspec.yaml
echo "    ${CURRENT}  ->  ${NAME}+${NEW_BUILD}"

echo "==> Building release IPA (15-30 min on this Mac, be patient)..."
flutter build ipa --release --dart-define-from-file=env.json --export-options-plist=ios/ExportOptions.plist

IPA=$(ls -t build/ios/ipa/*.ipa | head -1)
if [ ! -f "$IPA" ]; then
  echo "!! No IPA produced — build failed. Aborting upload."
  exit 1
fi
echo "==> Built: $IPA"

echo "==> Uploading to App Store Connect..."
xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "$API_KEY_ID" --apiIssuer "$API_ISSUER_ID"

echo ""
echo "============================================================"
echo " UPLOAD DONE. Build ${NAME}+${NEW_BUILD} is processing."
echo " In ~10 min it appears in App Store Connect > TestFlight."
echo " Then: version page -> select build -> Submit for Review."
echo "============================================================"

# Commit the version bump so the next release increments correctly.
git add pubspec.yaml
git commit -m "Release ${NAME}+${NEW_BUILD}" || true
