# FolioMed 🏥
Real-time clinical notes app for hospital ward teams.
Built with Flutter + Supabase. Free for everyone.

- Landing: https://www.foliomed.com
- Web app: https://www.foliomed.com/app/
- Status: https://www.foliomed.com/status/

## Setup

### 1. Database
Apply the schema to the Supabase project (SQL editor, or the CLI):

```bash
supabase link --project-ref zfnucugpbpyrymyyrary
supabase db push
```

### 2. App configuration
```bash
cp env.example.json env.json   # then paste the anon key etc.
flutter pub get
```

### 3. Run
- Mobile / desktop: `flutter run --dart-define-from-file=env.json`
- Web: `flutter run -d chrome --dart-define-from-file=env.json`

### 4. Test
```bash
flutter test
```
Database smoke tests: see `supabase/tests/README.md`.

## Deploy
Push to `main`. GitHub Actions runs the tests, builds the web app and
publishes landing + status + app to GitHub Pages (`www.foliomed.com`).
Add the `SUPABASE_ANON_KEY` repository secret first.

## Roles
- Doctor: create notes, manage patients
- Nurse: view notes, acknowledge updates
- Admin: manage wards and staff

## Wards
Wards have 5-digit join codes. Members of the same ward see each other's
notes and patients in real time; nobody else can read them (row-level
security).
