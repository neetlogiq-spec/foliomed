#!/bin/bash
# One-command iOS release: bump build number -> build IPA -> upload to App Store Connect.
#
# Usage:  ./tools/ios_release.sh
#
# Prereqs (all already set up — one-time, do not need to redo):
#   - Distribution cert in Keychain
#   - ~/Library/MobileDevice/Provisioning Profiles/FolioMed_App_Store.mobileprovision
#   - ios/ExportOptions.plist (manual signing, committed)
#   - project.pbxproj Release config = Manual signing (committed)
#   - ~/.appstoreconnect/private_keys/AuthKey_SDMDVN88HB.p8
#
# After this finishes: wait ~10 min, the build shows up in App Store
# Connect > TestFlight. Then select it on the version page + Submit.

set -e

PROJECT_DIR="/Users/kashyapanand/Public/foliomed"
API_KEY_ID="SDMDVN88HB"
API_ISSUER_ID="d74c90c0-e215-495a-b937-27d3619b1874"

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
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

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
