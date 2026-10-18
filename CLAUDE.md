# FolioMed — Project Context for Claude

## What is FolioMed
A real-time clinical notes app for hospital ward teams. Flutter app on a
Supabase backend. Targets Android (Play Store), iOS (App Store via
Codemagic or `tools/ios_release.sh`), macOS desktop (FolioMed Edge
station) and Web. **Free for everyone** — `SubscriptionProvider.freeForEveryone`.

**Developer:** Kashyap Anand (kashyap2k007@gmail.com)
**Landing page:** https://www.foliomed.app
**Web app:** https://www.foliomed.app/app/
**Status page:** https://www.foliomed.app/status/
**Support link:** https://www.foliomed.app/support
**GitHub:** https://github.com/neetlogiq-spec/foliomed (legacy Next.js app on branch `archive/nextjs-app`)
**Supabase project:** https://zfnucugpbpyrymyyrary.supabase.co
**Bundle ID (Android + iOS):** com.foliomed.app

---

## Tech Stack
- **Flutter** (Dart) — Android, iOS, macOS, Web
- **Supabase Auth** — email/password, Google (Supabase-hosted OAuth + `com.foliomed.app://login-callback` deep link), Apple (iOS/macOS, nonce flow)
- **Supabase Postgres** — data, row-level security, triggers, RPCs
- **Supabase Realtime** — live lists (`.stream()`) + in-app note alerts (`PushService`)
- **Supabase Storage** — bucket `monitor-snapshots`
- **GitHub Pages** — landing + status + Flutter web app (see `.github/workflows/deploy.yml`)
- **Provider** — state management
- **Codemagic** — iOS CI/CD

## Configuration
Build-time values come from `--dart-define-from-file=env.json` (gitignored;
template in `env.example.json`), read in `lib/config/supabase_config.dart`.
Without `SUPABASE_ANON_KEY` the app shows a "missing configuration" screen.

```bash
flutter run --dart-define-from-file=env.json
```

The landing/status pages read public counters with the anon key set in
`landing/supabase-public.js`.

---

## Database (supabase/migrations/)
Firestore → Postgres mapping: `users`→`profiles`, `wards`, `patients`,
`notes`, `notes/*/comments`→`note_comments`, `monitor_vitals` (+`_history`),
`metrics`, `recent_activity`. Columns are snake_case; models map them in
`fromRow` / `toRow`.

- Profiles are created by the `handle_new_user` trigger from sign-up metadata (`name`, `role`, `ward_id`).
- Ward codes are random 5-digit strings (PK collision → retry in `WardService.createWard`).
- Join / leave go through `join_ward()` / `leave_ward()` RPCs (keep `profiles.ward_ids` and `wards.member_ids` in sync).
- Deleting a ward / patient / note cascades in Postgres; a trigger strips deleted ward codes from profiles.
- `delete_my_account()` deletes the auth user and cascades everything they own.
- `dashboard_counts()` is admin-only; `public_activity()` exposes type + time only (summaries can contain patient names).
- RLS: ward members only for patients / notes / comments / vitals; profiles are readable by any signed-in user, writable only by their owner.

Test the schema locally without Docker: `supabase/tests/README.md`.

## User Roles
- **Doctor** — home, wards, patients, notes feed, profile
- **Nurse** — home, wards, patients, profile
- **Admin** — dashboard analytics, wards, staff list, profile

---

## Important File Locations
- `lib/main.dart` — `Supabase.initialize`, providers
- `lib/config/supabase_config.dart` — dart-define config
- `lib/services/supabase_service.dart` — `supabase` client getter, table/bucket names
- `lib/services/auth_service.dart` — email, Google, Apple sign-in; reset; delete account
- `lib/services/{note,patient,ward}_service.dart` — CRUD + realtime streams
- `lib/services/push_service.dart` — realtime in-app alerts (background push TODO)
- `lib/services/metrics_service.dart` — `bump_metric` RPC
- `lib/utils/stream_cache.dart` — keep one realtime stream per key across rebuilds
- `lib/utils/friendly_error.dart` — maps Supabase errors to plain English
- `lib/models/row_parsing.dart` — timestamp / list helpers for rows
- `landing/`, `status/` — static pages; `landing/supabase-public.js` shared reader

## Design system (Apple HIG)
- Text: `appText(...)` / `appMonoText(...)` (`lib/utils/app_typography.dart`) — system font + size-specific tracking. Don't add Google Fonts.
- Sheets: `showAppSheet(...)` (`lib/widgets/app_sheet.dart`), never `showModalBottomSheet` — finger-tracking, velocity-projected dismiss, spring settle.
- Dialogs: `showAdaptiveDialog` + `AppAlertDialog` (`lib/widgets/app_alert_dialog.dart`) — native Cupertino alerts on iOS/macOS; filled button = default action, danger-coloured = destructive.
- Tab screens: content scrolls under the frosted tab bar (`extendBody`). Vertical scroll views in a tab screen must use `withBottomBarInset(context, padding)` (`lib/utils/layout.dart`); `CustomScrollView`s need a bottom spacer sliver.
- Taps on cards: `Pressable`. Haptics: `Haptics.selection/commit/success/destructive/error` only at meaningful moments.
- Honour `AppMotion.reduced(context)` (Reduce Motion) in any new animation.

## Known Gotchas
- Realtime `.stream()` accepts **one** filter — extra filters (e.g. `is_active`) are applied client-side.
- Create streams once per key (`StreamCache` or `late final`), never inline in `build`, or every rebuild opens a new channel.
- An UPDATE/DELETE blocked by RLS returns **zero rows, not an error** — use `.select()` and check the result where it matters (see `admin_staff_screen.dart`).
- Note comments sheet uses `resizeToAvoidBottomInset: false` — keyboard handling is manual.
- SharedPreferences keys are versioned (`onboarding_complete_v2`, …) — renaming re-shows that tutorial.
- Apple Sign-In button is gated to iOS — never show on Android/Web.
- `ios/Runner/Runner.entitlements` → `aps-environment` must stay `production` for TestFlight/App Store builds.

---

## Android Signing
- Upload keystore: `android/app/foliomed-upload-key.jks`, credentials in `android/key.properties` (both gitignored; backup in `~/Public/foliomed/secrets/`).
- Upload key SHA-1 `43:79:9C:B3:F1:5C:C7:80:2C:40:2E:68:84:42:FF:DD:26:FD:1B:26`
- Google sign-in runs through Supabase OAuth, so no Android OAuth client / SHA-1 registration is needed for it.

## iOS Signing
- App Store Connect API key: Key ID `ZCU49PSMCN` (`AuthKey_ZCU49PSMCN.p8`, keep out of git).
- Team ID (App ID Prefix): `A6787TZ6CR`. App Store Apple ID is still a placeholder (`YOUR_APP_STORE_APPLE_ID`).
- Build number must increase on every upload (`+N` in pubspec).
