# Reusable Prompt — Ship a Flutter App to the iOS App Store

Copy everything in the box below into a new Claude Code session, **at the
root of the Flutter project you want to ship**. Fill in the five `<...>`
values at the top first. Works for any Flutter app.

---

```
You are helping me ship this Flutter app to the iOS App Store. Use the
EXACT method below — it is battle-tested. Do NOT improvise an alternative
signing flow and do NOT send me down the Codemagic automatic-signing path
(it fails with "No matching profiles found" unless a device is registered,
which is a dead end — see Gotchas).

PROJECT VARIABLES (I fill these in):
- App display name:        <e.g. FolioMed>
- Desired bundle ID:       <e.g. com.mycompany.app  — must be unique in Apple's registry>
- Apple Developer Team ID: <10-char, e.g. YOUR_APPLE_TEAM_ID — find at developer.apple.com/account → Membership>
- Support URL:             <e.g. https://mysite.com/support>
- Privacy Policy URL:      <must be a real, live page>

=== PHASE 0: PRE-FLIGHT (you do this, report findings) ===
1. Read pubspec.yaml for version+build number.
2. Run `dart analyze lib/` — fix any errors before building.
3. Confirm the bundle ID is consistent across:
   ios/Runner.xcodeproj/project.pbxproj (PRODUCT_BUNDLE_IDENTIFIER),
   ios/Runner/GoogleService-Info.plist (if Firebase),
   lib/firebase_options.dart (if Firebase),
   ios/Runner/Info.plist (URL schemes if Google Sign-In).
   If the desired bundle ID differs, update ALL of them consistently.
4. Check ios/Runner/Runner.entitlements — note capabilities
   (push, sign-in-with-apple, etc.). Every capability here MUST be
   enabled on the App ID in the Developer Portal or signing fails.
5. Check the launch screen is NOT the default Flutter placeholder
   (Apple rejects for this). Flag it if it is.

=== PHASE 1: APPLE-SIDE SETUP (guide me click-by-click, I do these in browser) ===
1. App Store Connect → My Apps → + → New App. Bundle ID from dropdown,
   SKU = <appname>-ios-<year>, Full Access. Have me read back the
   10-digit Apple ID number.
2. App Store Connect → Users and Access → Integrations →
   App Store Connect API → generate key, Access = ADMIN (NOT App
   Manager — App Manager can't always create profiles). Have me give
   you: Key ID, Issuer ID, and confirm the AuthKey_XXXX.p8 download
   location (~/Downloads).
3. developer.apple.com → Identifiers → confirm/create the App ID with
   the SAME capabilities as Runner.entitlements. Save.
4. Xcode → Settings → Accounts → add Apple ID → Manage Certificates
   → + → Apple Distribution. (Creates the distribution cert in Keychain.)
5. developer.apple.com/account/resources/profiles/add → Distribution →
   App Store Connect → pick the App ID → pick the Apple Distribution
   cert → name it "<AppName> App Store" → Generate → Download the
   .mobileprovision to ~/Downloads.

=== PHASE 2: LOCAL SIGNING CONFIG (you do this) ===
1. Install + introspect the profile:
   mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
   cp ~/Downloads/<Name>.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
   security cms -D -i <path> | plutil -extract UUID raw -
   security cms -D -i <path> | plutil -extract Name raw -
   security cms -D -i <path> | plutil -extract TeamIdentifier.0 raw -
2. Write ios/ExportOptions.plist:
   method=app-store, signingStyle=manual, teamID=<Team ID>,
   provisioningProfiles={ <bundleID> : "<profile Name>" },
   uploadSymbols=true, stripSwiftSymbols=true, destination=export.
3. In ios/Runner.xcodeproj/project.pbxproj, find the Runner target's
   *Release* XCBuildConfiguration (the one with DEVELOPMENT_TEAM and
   PRODUCT_BUNDLE_IDENTIFIER, NOT the project-level or Tests one) and
   add inside buildSettings:
     CODE_SIGN_IDENTITY = "Apple Distribution";
     "CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";
     CODE_SIGN_STYLE = Manual;
     DEVELOPMENT_TEAM = <Team ID>;
     PROVISIONING_PROFILE_SPECIFIER = "<profile Name>";
   Back up project.pbxproj first; delete the backup after success.

=== PHASE 3: BUILD + UPLOAD (you do this) ===
1. cd <project root> && flutter build ipa --release \
     --export-options-plist=ios/ExportOptions.plist
   Run it in the BACKGROUND (slow Macs take 15-30 min for the archive
   step). Poll, don't block.
2. On success, verify build/ios/ipa/*.ipa exists.
3. Upload via API key (no Transporter needed):
   mkdir -p ~/.appstoreconnect/private_keys
   cp ~/Downloads/AuthKey_<KeyID>.p8 ~/.appstoreconnect/private_keys/
   xcrun altool --upload-app --type ios -f build/ios/ipa/<App>.ipa \
     --apiKey <KeyID> --apiIssuer <IssuerID>
   Look for "UPLOAD SUCCEEDED".
4. git commit the ExportOptions.plist + project.pbxproj changes so the
   working signing config is preserved.

=== PHASE 4: STORE METADATA (you draft, I paste) ===
Generate, tailored to THIS app's actual feature set (read the code/CLAUDE.md
to get features right — do not invent roles/features the app lacks):
- Subtitle (≤30 chars)
- Promotional text (≤170 chars)
- Description (≤4000 chars)
- Keywords (≤100 chars, comma-separated, no spaces after commas)
- Copyright (e.g. "© <year> <name>. All rights reserved.")
- App Review notes incl. a DEMO ACCOUNT (email+password) if the app
  requires login — create/seed this account if a backend exists.
Remind me: screenshots required for 6.5"/6.9" iPhone (1242x2688 /
1284x2778 / 1320x2868). Largest simulator (e.g. iPhone Pro Max) →
`xcrun simctl io booted screenshot out.png` → frame in Canva/AppLaunchpad.

=== GOTCHAS (lessons learned the hard way — do NOT repeat) ===
- Codemagic "automatic" iOS signing FAILS with "No matching profiles
  found for bundle identifier ... distribution type app_store" unless a
  Distribution cert + device-registered dev profile already exist.
  Without a physical test device this is unfixable via YAML. The manual
  flow above is the reliable path. Don't loop on Codemagic.
- `flutter build ipa` with Xcode AUTOMATIC signing fails the same way
  ("team has no devices") because the archive step tries to mint a
  *development* profile. Manual signing on the Release config skips this.
- App Store Connect API key MUST be Admin role, not App Manager.
- The integration name / profile name must match EXACTLY (case + spaces)
  wherever it's referenced.
- Strip non-ASCII (→, •, em-dash) from codemagic.yaml / plists — some
  parsers choke.
- `flutter: <version>` in any CI yaml must be a real released version
  (check `flutter --version` locally).
- Modify ONLY the Runner-target Release block in project.pbxproj. There
  are usually 3 "Release" blocks (project, Runner, RunnerTests) — wrong
  one = silent signing failure.
- Apple build processing after upload takes 5-15 min before it appears
  in TestFlight; that part is on Apple's servers, not pollable locally —
  hand it back to me, don't busy-wait.

Start with Phase 0 and report before proceeding to Phase 1.
```
