# Legacy FolioMed (Next.js + Capacitor) — what was kept

Before this Flutter codebase replaced `main`, the repo held an earlier
FolioMed web app (Next.js 16 + Capacitor 8 + Supabase, package name
`paedia`). Its full history is preserved on the branch
**`archive/nextjs-app`** — check it out to read or restore any file.

## Facts worth carrying forward

| Item | Value |
|---|---|
| Bundle / app ID | `com.foliomed.app` (same as this app) |
| Old web domain | `https://foliomed.app` (Capacitor `server.url`) |
| Old Supabase project ref | `gyzyrwdkcjgxuxsvitwf` (from `.mcp.json`) |
| New Supabase project | `https://zfnucugpbpyrymyyrary.supabase.co` |
| OCR | Gemini 2.0 Flash via a Supabase Edge Function, Tesseract.js fallback |
| Realtime | Supabase Realtime presence + block-level locking for collaborative docs |
| Offline | Service Worker + IndexedDB cache + sync queue |

## Data model (Supabase tables the old app used)

`profiles`, `departments`, `patients`, `vitals`, `investigations`,
`medications`, `progress_notes`, `case_documents`,
`case_document_versions`, `document_templates`, `patient_images`,
`handover_notes`, `department_feed`, `comments`, `case_log`,
`audit_logs`.

If the new Supabase project already contains these tables, check for
name clashes with this app's schema (`supabase/migrations/`) before
running migrations — `profiles`, `patients` and `comments` overlap.

## Roles (richer than this app's doctor / nurse / admin)

`pg`, `senior_pg`, `intern`, `consultant`, `senior_consultant`, `hod`,
`nurse`, `admin`. Admin access = `admin` or `hod`. Only PGs/interns
create patients; nurses can add vitals but not feed posts.

## Patient fields with paediatric focus

Gestational age, birth weight, APGAR 1/5 min, head circumference,
immunisation status, mother/father names, `consent_for_teaching`,
visibility (`private` | `department`), status (`admitted`,
`discharged`, `lama`, `referred`, `expired`) and case tags
(interesting, rare, teaching, critical, follow_up, research, …).
