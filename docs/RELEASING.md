# Releasing FolioMed

Builds use `env.json` (gitignored; copy `env.example.json`). Bump the
version in `pubspec.yaml` before a store release: the part before `+` is
what people see, the number after `+` must go up with every upload.

## Android (Google Play)

```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console
→ Testing → Internal testing (then promote). Signing uses
`android/key.properties` and the upload keystore (both gitignored; backup
in `~/Public/foliomed/secrets/`).

## iOS (TestFlight / App Store)

Either:

- **Codemagic:** push a tag `ios-v1.0.0` — `codemagic.yaml` builds, numbers
  and uploads to TestFlight (set `ASC_APP_ID` and the secrets group once);
- **this Mac:** `APP_STORE_ISSUER_ID=… tools/release_ios.sh` (needs the iOS
  platform installed in Xcode → Settings → Components).

When the build has processed, add it to the version in App Store Connect
and submit for review.

## Website and web app

Push to `main` (or run `tools/check_and_push.sh`). GitHub Actions runs the
Flutter and database tests, then publishes `landing/`, `status/` and the
web app (`/app/`) to www.foliomed.app.

## Database changes

New files in `supabase/migrations/` must be run in the Supabase SQL
Editor (in order) **before** shipping an app that relies on them. Each has
a matching suite in `supabase/tests/` that CI runs on every push.
