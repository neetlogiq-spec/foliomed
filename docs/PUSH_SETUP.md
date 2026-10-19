# Server push (closed-app alerts) — one-time setup

Until this is done FolioMed still works: reminders alert through on-device
notifications, and new notes alert only while the app is open. After it,
notes and due reminders reach every ward member's phone even when FolioMed
is closed.

How it works: `notes` inserts and due reminders are queued in
`push_outbox` (migration `20261020030000_push_notifications.sql`); the
`push-dispatch` Edge Function sends them through Firebase Cloud Messaging.
A cron job runs every minute; new notes also wake the function instantly.

## 1. Firebase project (≈10 min)

1. <https://console.firebase.google.com> → **Add project** → name it
   `foliomed` (Analytics not needed).
2. **Add app → Android**, package name `com.foliomed.app`. Download
   `google-services.json` (keep it out of git) and note:
   - `project_info.project_number` → `FIREBASE_MESSAGING_SENDER_ID`
   - `project_info.project_id` → `FIREBASE_PROJECT_ID`
   - `client[0].client_info.mobilesdk_app_id` → `FIREBASE_ANDROID_APP_ID`
   - `client[0].api_key[0].current_key` → `FIREBASE_ANDROID_API_KEY`
3. **Add app → iOS**, bundle ID `com.foliomed.app`. Download
   `GoogleService-Info.plist` and note `GOOGLE_APP_ID` →
   `FIREBASE_IOS_APP_ID`, `API_KEY` → `FIREBASE_IOS_API_KEY`.
4. iOS push needs an **APNs key** (different from the App Store Connect key
   `ZCU49PSMCN`): <https://developer.apple.com/account/resources/authkeys>
   → **+** → tick *Apple Push Notifications service (APNs)* → download the
   `.p8`. In Firebase → Project settings → **Cloud Messaging** → Apple app →
   upload it with its Key ID and Team ID `A6787TZ6CR`.
5. Firebase → Project settings → **Service accounts** → **Generate new
   private key**. This JSON is a secret — never commit it.

Put the six values in `env.json` (see `env.example.json`).

## 2. Supabase (≈5 min)

Run the migration `20261020030000_push_notifications.sql` in the SQL
Editor first.

**Deploy the function** — either:

- CLI (log in to the account that owns the project first):
  ```bash
  supabase login
  supabase functions deploy push-dispatch --no-verify-jwt \
    --project-ref zfnucugpbpyrymyyrary
  ```
- or Dashboard → **Edge Functions** → **Deploy a new function** → name
  `push-dispatch`, paste `supabase/functions/push-dispatch/index.ts`, and
  turn **Verify JWT** off (it checks its own secret instead).

**Secrets** (Dashboard → Edge Functions → Secrets, or CLI):

```bash
supabase secrets set --project-ref zfnucugpbpyrymyyrary \
  DISPATCH_SECRET="$(openssl rand -hex 24)" \
  FCM_SERVICE_ACCOUNT="$(jq -c . path/to/service-account.json)"
```

Copy the `DISPATCH_SECRET` value you set; it goes in the SQL below.

**Database** — Dashboard → Database → Extensions: enable **pg_cron** and
**pg_net**. Then in the SQL Editor (replace `<secret>`):

```sql
insert into public.app_settings (key, value) values
  ('dispatch_url', '"https://zfnucugpbpyrymyyrary.supabase.co/functions/v1/push-dispatch"'),
  ('dispatch_secret', '"<secret>"')
on conflict (key) do update set value = excluded.value;

select cron.schedule('foliomed-push', '* * * * *',
  $$ select public.enqueue_due_reminders(); select public._kick_push_dispatch(); $$);

-- Last: tells the apps to rely on server push.
insert into public.app_settings (key, value) values ('push_enabled', 'true')
on conflict (key) do update set value = excluded.value;
```

## 3. Rebuild the app

Push needs a build with the Firebase values from `env.json`:

```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

## Check it works

```sql
-- Queued and sent alerts (sent_at filled, last_error empty)
select id, title, sent_at, attempts, last_error
from public.push_outbox order by id desc limit 20;

-- Registered devices
select platform, count(*) from public.push_tokens group by 1;
```

To switch server push off again (apps fall back to local notifications):
`update public.app_settings set value = 'false' where key = 'push_enabled';`
