# FolioMed code provenance audit

**Date:** 2026-10-20 · **Status:** technical comparison only — not a legal
opinion. Review with an Indian software/IP lawyer before public release.

## Background

FolioMed began as a full copy of **Wardly** —
<https://github.com/mulgundsunil1918/wardly> (author Sunil Mulgund, 182
commits, latest `d374515`, 2026-08-08). The repository has **no licence
file**, so by default all rights are reserved by its author. The copy was
renamed to FolioMed, given a fresh Git history and a new author name, then
extensively rewritten (Firebase → Supabase, new design, new clinical
features). A fresh history does not change where the code came from; this
document is the provenance record.

## Method

`compare.py` (in this folder): for every tracked FolioMed file, the share
of its non-trivial code lines (after undoing the Wardly→FolioMed rename,
ignoring imports, comments and short lines) that also appear in the original
Wardly — matched to the same path, or to the best-matching file if moved.
Platform folders were also compared with a fresh `flutter create` template
to separate Flutter's own (BSD-licensed) boilerplate from Wardly's work.
Full per-file results: `file_provenance.csv`.

Limits: line matching misses code that was copied and then reformatted or
refactored, and counts common one-liners as matches. Treat percentages as
indicators, not proof either way.

## Results

| Area | Finding |
|---|---|
| `lib/` (app code) | 107 files, 13,165 code lines. **~47% of lines also appear in Wardly.** 33 files largely retained (≥70%), 17 modified (35–69%), 34 mostly rewritten (10–34%), 23 new. |
| `supabase/`, `test/`, `landing/`, `docs/` (except one), `assets/clinical/` | New. |
| App icons | New (not Wardly's). |
| Platform folders | 54 files match the Flutter template (no Wardly issue). 25 are config/generated files closer to Wardly (build.gradle, manifests, Info.plist, Xcode project, plugin registrants, Podfile.lock) — low creative content, easy to regenerate. |
| Other | `codemagic.yaml` 84%, `tools/ios_release.sh` 85%, `docs/APP_STORE_DEPLOY_PROMPT.md` 98%, `pubspec.yaml` 82%, `deploy.yml` 59%. |

### `lib/` files largely retained from Wardly (≥70% of lines)

Onboarding, tutorial, help, splash, background-setup and OEM-autostart
screens; note composer (`add_note_screen`), note card, comments sheet,
notifications panel, acknowledge sheet, filtered-notes screen; admin home,
staff, ward-detail and add-ward screens; providers (auth, note, patient,
ward, notification, theme, text scale); `app_user`, `patient_card`,
`role_badge`, `empty_state`, `theme_toggle_button`; utils (routes,
constants, rate prompt, web notice, app utils). See the CSV for each file's
percentage and line count.

### Modified from Wardly (35–69%)

`profile_screen`, `patient_detail_screen`, `main_scaffold`,
`login_screen`, `role_choice_screen`, `add_staff_bottom_sheet`,
`note_service`, `metrics_service`, `friendly_error`, `share_helper`,
`main.dart`, models `note`, `ward`, `note_comment`, `foliomed_brand`, and
two newer files that reuse Wardly dialog text/structure (`ward_actions`,
`note_list_items`).

## Rewrite progress

Measured with the refined metric (distinctive lines only — lines found in
at most two original files; framework idiom is excluded):

| Date | Stage | `lib/` distinctive overlap |
|---|---|---|
| 2026-10-20 | Baseline | ~24% |
| 2026-10-20 | Stage 1 — start flow (launch, welcome, alert setup), help, tips, tab shell, routes, brand mark, review request; onboarding/tutorial/coachmarks removed | ~18% |
| 2026-10-20 | Stage 2 — notes: NotesRepository, WardFeed, Note/NoteReply models, NoteTile, compose sheet, reply thread, confirm sheet, alerts inbox; "acknowledge" → "confirm" in the UI | ~14% |
| 2026-10-20 | Stage 3a — admin: Overview, People, admin Ward page (team / patients / notes); WardProvider, add-ward, staff sheet, patient card, role badge, theme toggle removed | ~12% |

## Remediation plan

1. **Ask for permission first (cheapest).** Written permission or a licence
   (e.g. MIT) from Sunil Mulgund covering use, modification, redistribution
   and app-store distribution of Wardly — and of `pediaid-flutter`, whose
   AAP data was imported (see `docs/AAP_DATA_VERIFICATION.md`). Keep the
   reply with these records.
2. **Until then, credit the origin honestly** (e.g. a `NOTICE` file). Do not
   rewrite history or disguise the code.
3. **If permission is refused or unavailable, replace in this order:**
   - *Tier A — largely retained `lib/` files (~33 files, ~4,500 lines).*
     Several are already earmarked for redesign (onboarding, tutorial,
     help, admin screens, note composer). Others are small (providers,
     utils).
   - *Tier B — modified files (~17 files, ~2,000 lines),* rewriting the
     remaining Wardly-derived parts.
   - *Tier C — platform/config files,* regenerated with `flutter create`
     and re-applied settings; deploy scripts and `codemagic.yaml` rewritten.
   Each replacement: write the requirement first (what the screen/module
   must do), implement from that, keep the existing tests passing, add
   tests for the requirement, and re-run `compare.py` to confirm.
4. **"Clean room" caveat.** The person (or AI assistant) rewriting a module
   has read the original code, so a rewrite is an independent
   re-implementation from specifications, not a strict clean-room process.
   Ask the lawyer whether that is sufficient or whether a separate
   implementer is needed for any parts.
5. **Clinical data:** AAP/NICE thresholds are taken from the published
   guidelines and verified against them (see
   `test/guideline_reference_test.dart`), not from Wardly.
