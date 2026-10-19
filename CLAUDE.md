# FolioMed — Project Context for Claude

## What is FolioMed
A real-time clinical notes app for hospital ward teams. Flutter app on a
Supabase backend. Targets Android (Play Store), iOS (App Store via
Codemagic or `tools/ios_release.sh`) and Web. **Free for everyone** — no paid tier.

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
- **Flutter** (Dart) — Android, iOS, Web
- **Supabase Auth** — Google (Supabase-hosted OAuth + `com.foliomed.app://login-callback` deep link) and Apple (iOS, nonce flow) only; no passwords. Admin role is granted only via `set_user_role` (or SQL); new users pick doctor/nurse once (`confirm_my_role`).
- **Supabase Postgres** — data, row-level security, triggers, RPCs
- **Supabase Realtime** — live lists (`.stream()`) + in-app note alerts (`PushService`)
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
- RLS: ward members only for patients / notes / comments; profiles are readable by any signed-in user, writable only by their owner.

- Patients: `patient_code` (FM000123) is assigned by the database, system-wide unique and immutable; `hospital_id` is optional free text; `age` + `age_unit` (days/months/years).
- Lifecycle goes through RPCs only: `discharge_patient`, `readmit_patient`, `transfer_patient` (caller must be in both wards; notes and replies move with the patient). Each writes a timeline note (category Discharge / Admission / Transfer). `status` drives `is_active` via trigger.

- Newborns: `patients.born_at` (date + time of birth) overrides `age` for display (hours in week one).
- `patient_reminders`: ward-shared due-at reminders (RLS = ward members; `ward_id` must match the patient's). `done_by`/`done_by_name`/`created_by` are stamped by triggers; snooze = `snoozed_until`. They move with the patient on transfer.
- Reminder alerts are **local** notifications (`ReminderNotifications`, flutter_local_notifications): each phone schedules its wards' open reminders whenever the list changes; the in-app "has this been done?" prompt comes from `ReminderProvider.onDue`. A phone that hasn't opened the app since a reminder was added won't alert — server push is still TODO.

- Newborn investigations (`newborn_screens`, migration `20261020000000`): planned at 48/72 h of life with an 8/12 h heads-up. RPC-only writes: `plan_newborn_screen`, `mark_newborn_screen_sent`, `remind_newborn_results`, `save_newborn_results` (each also writes reminders with `kind` newborn_prep/send/results and a timeline note, category Investigation). Results are JSON owned by `NewbornResults` (`lib/models/newborn_screen.dart`). UI: `NewbornFlow`, `NewbornSection`, `NewbornResultsScreen`.
- Bilirubin decision support: `lib/clinical/bilirubin.dart` — NICE CG98 Table 1 (≥38 wk, linear interpolation, flat from 96 h). AAP 2022 is a stub that reports "not built in" until its tables are supplied and verified. Never present as diagnosis; UI always shows the disclaimer.

Test the schema locally without Docker: `supabase/tests/README.md` (suites 10–50).

## User Roles & tabs
- **Doctor / Nurse** — Today (`today_screen.dart`: tiles, reminders, collapsible Pending/All/Urgent note feed), Patients (`patients_screen.dart`, grouped by ward), Wards (`wards_screen.dart` → `ward_page.dart`), Profile. Doctors get the New note FAB; nurses acknowledge through the acknowledge sheet (`WiredNoteCard`).
- **Admin** — dashboard analytics, wards, staff list, profile
- Patient edits reuse `AddPatientScreen(existing:)`; the ward is changed only via Transfer.
- List UI uses `InsetGroup` / `SettingsRow` (`lib/widgets/inset_group.dart`) — iOS inset-grouped rows.

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

## Removed / planned
- **Monitoring** (Edge station, AI vitals, HLS camera streams, video calls) and the Pro paywall were removed. The last version with them is the git tag `monitor-v1`; the `monitor_vitals*` tables and `monitor-snapshots` bucket still exist in the database, unused.
- **Photo text scan** (`lib/services/text_scan_service.dart`): image_picker + on-device ML Kit (Latin), Android/iOS only; photos are never uploaded.

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
