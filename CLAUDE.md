# FolioMed — Project Context for Claude

## What is FolioMed
A real-time clinical notes app for hospital ward teams. Flutter app on a
Supabase backend. Targets Android (Play Store), iOS (App Store via
Codemagic or `tools/release_ios.sh`) and Web — see `docs/RELEASING.md`. **Free for everyone** — no paid tier.

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
- **Supabase Realtime** — live lists (`.stream()`) + in-app note alerts (`LiveNoteAlerts`)
- **GitHub Pages** — landing + status + Flutter web app (see `.github/workflows/deploy.yml`)
- **Provider** — state management
- **Codemagic** — iOS → TestFlight on `ios-v*` tags (`codemagic.yaml`)
- **GitHub Actions** — Flutter + database tests on every push; publishes the site from `main`

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
- Alerts: **server push** (migration `20261020030000`, setup in `docs/PUSH_SETUP.md`) — notes trigger and `enqueue_due_reminders()` (pg_cron) fill `push_outbox`; Edge Function `supabase/functions/push-dispatch` sends via FCM to ward members' `push_tokens`. App: `PushRegistration` (Firebase options from env.json `FIREBASE_*`, no google-services file). Until `push_enabled()` is true, `ReminderNotifications` schedules **local** reminder alarms instead (never both). The in-app "has this been done?" prompt comes from `ReminderProvider.onDue`.

- Newborn investigations (`newborn_screens`, migration `20261020000000`): planned at 48/72 h of life with an 8/12 h heads-up. RPC-only writes: `plan_newborn_screen`, `mark_newborn_screen_sent`, `remind_newborn_results`, `save_newborn_results` (each also writes reminders with `kind` newborn_prep/send/results and a timeline note, category Investigation). Results are JSON owned by `NewbornResults` (`lib/models/newborn_screen.dart`). UI: `NewbornFlow`, `NewbornSection`, `NewbornResultsScreen`.
- Birth details (migration `20261020010000`): birth weight, AGA/SGA/LGA (manual — no growth-chart data built in), delivery mode + indication, APGAR 1/5, resuscitation, mother's blood group. `birthSummaryLine()` (`lib/clinical/birth_summary.dart`) composes "TERM/MALE/AGA/LSCS (CPD) on 19/10/2026 at 10:19pm with birth weight of 3.1kgs"; maturity is derived from gestation (WHO bands). It fills the diagnosis when that is blank or was the previous composed line.
- Units (teams) inside a ward (migration `20261020020000`): `ward_units` (owner writes, members read), `patients.unit_id` (trigger keeps it in the patient's ward; transfer clears it), `move_patient_unit` RPC logs "Moved from Unit A to Unit B". App: `UnitProvider` (units + shared `PatientScope` filter + per-device "My unit"), `ScopeButton` / `UnitCountsLine` (`lib/widgets/scope_button.dart`), `ScopeFilter` maps notes/reminders to units via their patient.
- Bilirubin decision support: `lib/clinical/bilirubin.dart` — NICE CG98 Table 1 (≥38 wk, linear interpolation, flat from 96 h) + preterm graphs (23–37 wk) and AAP 2022 (≥35 wk; hourly tables in `assets/clinical/aap2022_bilirubin.json`, completed-hour lookup, plateau after the table, "at or above", escalation = exchange − 2 mg/dL; needs `patients.neuro_risk_factors` — null = not assessed → AAP refuses). The AAP dataset is `verified: false` until checked against the supplemental tables (`docs/AAP_DATA_VERIFICATION.md`); flip it only after that check. `test/guideline_reference_test.dart` pins every NICE table cell and 120 AAP anchor values — update it together with any data change. `lib/clinical/bilirubin_assess.dart`: guideline chosen by gestation — NICE below 35 weeks, AAP 2022 from 35, no fallback (`guidelineForGestation`, `assessReading`/`assessForPatient`) — and chart lines (`linesForPatient`). NICE below 38 weeks uses the preterm graph lines (40→weeks×10−100 phototherapy, 80→weeks×10 exchange, linear to 72 h then flat, 23 weeks up); `NiceCg98.pretermVerified = false` until checked against the NICE graphs. Neurotoxicity risk factors are picked in `showRiskFactorsSheet` (`lib/widgets/risk_factors_sheet.dart`) from the Bilirubin section and from the results screen (saved with the results). Rate of rise from the last two serum readings (AAP rapid rise ≥0.3/≥0.2 mg/dL/h). Never present as diagnosis; UI always shows the disclaimer.

- Newborn tracking (migration `20261021000000`): `bilirubin_readings` (results add one per screen), `phototherapy_sessions` (one running per baby; start/stop on timeline), `weights`, mother name/age/G-P. UI: `NewbornTrackingSection`, `BilirubinChart` (CustomPainter vs NICE lines), `CensusScreen` (census + shareable handover; logic in `lib/clinical/handover.dart`). Lab-report OCR → results fields: `lib/clinical/lab_report_parser.dart`.

- Ward jobs (migration `20261023000000`): `ward_jobs` (patient required; optional `due_by`, `assigned_to`; creator/assignee/completer names stamped by trigger `stamp_ward_job`; assignee must be a ward member; jobs follow the patient's ward via a `patients` trigger, dropping non-member assignees). Assigning someone else queues a push with `push_outbox.only_user` (push-dispatch honours it). App: `WardJob`, `JobService`, `JobBoard` (live, done-since-midnight), `JobRow`, `JobsScreen` (Mine/Ward/Done), `showAddJob`, `PatientJobsSection`, Today Up Next. `ScopeFilter.job` hides jobs of patients no longer admitted. Notification taps open the patient (`PushRegistration.onOpenPatient`).

- Discharge checklist (migration `20261024000000`): `discharge_checks` stores only staff-ticked items (key per `kManualDischargeItems`; who/when stamped; untick = delete). Worked-out lines (investigations, TSH, blood group, OAE, bilirubin ≤24 h vs guideline, phototherapy, weight ≤24 h) come from `dischargeChecklist()` in `lib/clinical/discharge_checklist.dart` (pure, tested). `DischargeCheckService.watch(patient)` combines the live sources. UI: `DischargeReadinessRow` on newborn pages → `DischargeChecklistScreen`; discharging a newborn lists open items first (Review / Discharge Anyway).

- Patient status dots (migration `20261026000000`): `wards.kind` (pnc/nicu/picu/paeds/adult/other → `WardKind`, chosen when the ward is set up (`WardActions.create`, pre-selected by `WardKind.guessFrom(name)`), owner changes it on the ward page via `WardService.setKind`; `Ward.toRow` never writes it), `patients.acuity` (stable/watch/sick, null = not set) + `acuity_reason`, `support_tags` (PICU; `SupportTag`); who/when stamped by trigger `stamp_patient_status` (ordinary patient edits keep the stamp). Writes go through `set_patient_status` RPC (same status again = review; null clears), which logs a timeline note (category Status). Logic: `patientStatus()` in `lib/clinical/patient_status.dart` (pure, tested) — the most serious of hand-set status, ward tasks (urgent unconfirmed notes, overdue reminders, urgent/overdue jobs → red) and ward-type rules (PNC/NICU and Other under 28 days: bilirubin vs `assessForPatient` with readings ≤72 h, phototherapy, weight loss 7/10%, missing GA/risk factors, NICU birth weight not regained by day 14; PICU: ventilated/inotropes while Stable → amber). Staff-led wards (PICU/paeds/adult) show grey with no status; a hand-set status older than 12 h (PICU) / 24 h is drawn faded (`needsReview`). Board: `withStatuses()` in `patient_board.dart` (drives Needs Attention filter/sort/count), `StatusDot` / `StatusLegend` (`lib/widgets/status_dot.dart`), `PatientRow`; patient page: `PatientStatusCard`. Observations (migration `20261027000000`): `observations` table (ward-scoped like weights, recorder stamped, follows the patient on transfer; all vitals optional + PEWS parts 0–3). `lib/clinical/early_warning.dart` (pure, tested in `test/early_warning_test.dart`): NEWS2 (RCP 2017) from 16 years, Brighton PEWS (staff score each part from the chart; no built-in normal ranges) from 28 days, none for newborns; `kEarlyWarningVerified = false` until sign-off (`docs/EARLY_WARNING_VERIFICATION.md`). On paeds/adult/Other wards the latest set (≤12 h) colours the dot: NEWS2 ≥5 / PEWS ≥4 or any 3 red, single NEWS2 3 / PEWS 3 amber; incomplete sets only raise it. App: `Observation`, `ObservationService`, `ObservationsSection` + `ObservationSheet` (`lib/widgets/observations_section.dart`); the board gets latest observations from `TrackingService.snapshot`.

- Tools tab (`lib/screens/tools/`, doctors/nurses): Fluids & Glucose, Low Blood Glucose, Electrolytes, Corrected Age, Blood Pressure (Dionne 2012 table in `bp_centiles.dart`), Vaccines (NIS in `vaccines.dart`), Exchange Transfusion, Lines & Tubes, Infusion Rate, New Ballard (`ballard.dart`), plus scores (Apgar, Downes, Silverman-Anderson, Thompson, LATCH — data in `lib/tools/newborn_scores.dart`, one `ScoreTool` screen; finished scores copy or open compose prefilled). All maths in `lib/tools/neonatal_formulas.dart` (pure, tested; each constant cites its source). `kToolsVerified = false` shows the "not yet checked" banner — flip only after clinical sign-off (`docs/TOOLS_VERIFICATION.md`). Shared frame: `ToolPage`, `BabyRow` (prefill from a patient), `NumberRow`, `ResultCard`. No drug list on purpose (pediaid's formulary is NeoFax/Harriet Lane-derived — don't import it).

Test the schema locally without Docker: `supabase/tests/README.md` (suites 10–99b).

## User Roles & tabs
- **Doctor / Nurse** — Today (`lib/screens/today/`: Up Next list from `upNext()` — overdue/soon reminders, urgent unconfirmed notes, my + urgent/overdue jobs; At a Glance rows; Latest Notes → `WardNotesScreen` with To Confirm/All/Urgent; one + menu), Patients (`lib/screens/patients/patients_screen.dart`: ward board — `PatientRow` with bed column + `PatientSignals` marks, filter chips Admitted/Needs Attention/Newborns/Phototherapy/Discharged, sort menu; logic in `patient_board.dart`), Wards (`wards_tab.dart` → `ward_page.dart`), Profile. Doctors get the compose button in the nav bar; nurses confirm through the confirm sheet (`FeedNote`). UI says "confirm"; the DB column is still `is_acknowledged`.
- **Admin** — dashboard analytics, wards, staff list, profile
- Patient edits reuse `PatientFormScreen(existing:)`; the ward is changed only via Transfer.
- List UI uses `InsetGroup` / `SettingsRow` (`lib/widgets/inset_group.dart`) — iOS inset-grouped rows.

---

## Important File Locations
- `lib/main.dart` → `lib/app/startup.dart` (`prepareApp`, each step isolated) and `lib/app/foliomed_app.dart` (providers, theme, routes)
- `lib/app/routes.dart` — `Routes` (launch, welcome, sign-in, role, alert setup, home); `lib/app/home_shell.dart` — tab bar (`HomeShell`)
- `lib/screens/start/` — launch decision (`decideLaunch`), welcome, sign in, role, alert setup
- `lib/screens/patients/` — `PatientScreen` (contact-card header + Note/Job/Reminder buttons; Overview | Timeline), `PatientFormScreen` (add/edit)
- `lib/screens/notes/` — compose sheet, reply thread, confirm sheet, note actions (`FeedNote`, `NoteLine`)
- `lib/screens/account/` — `AccountScreen` (Profile tab), edit sheet; `lib/screens/help/` — help centre + topics; `lib/screens/admin/` — Overview, People, admin ward page
- Providers: `AccountProvider`, `PatientRoster`, `WardFeed`, `ReminderProvider`, `UnitProvider`, `AlertInbox`, `AppearanceProvider` (theme + extra text size on top of the phone's)
- Services: `AccountService` (Google/Apple via Supabase), `NotesRepository`, `PatientService`, `WardService`, `ReminderService`, `TrackingService`, `NewbornScreenService`, `UnitService`, `LiveNoteAlerts` (in-app realtime alerts), `PushRegistration` (FCM)
- `lib/config/supabase_config.dart` / `firebase_config.dart` — dart-define config
- `lib/utils/formatting.dart`, `friendly_error.dart` (all UI errors go through it), `stream_cache.dart`, `app_theme.dart` (palette-based Apple semantic colours)
- `landing/`, `status/` — static pages; `landing/supabase-public.js` shared reader
- `docs/provenance/` — Wardly provenance audit, per-file CSV, `compare.py` (lines) and `deep_compare.py` (structure + wording) (re-run after big rewrites)

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
- SharedPreferences keys are versioned (`welcome_seen_v1`, `tips_dismissed_v1`, …) — bumping one re-shows that screen/tip.
- Apple Sign-In button is gated to iOS — never show on Android/Web. There are no desktop targets (macOS/Windows/Linux folders were removed).
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
