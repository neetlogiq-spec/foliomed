-- Server push (FCM) for closed-app alerts.
--
--   notes insert ──trigger──▶ push_outbox ◀── enqueue_due_reminders() (cron)
--                                  │
--                     push-dispatch Edge Function (cron + instant kick)
--                                  │
--                          FCM → every ward member's devices
--
-- Everything up to the outbox is plain SQL (tested locally). The Edge
-- Function and the cron schedule are set up once — docs/PUSH_SETUP.md.
-- Until `push_enabled` is switched on, phones keep using local reminder
-- notifications, so nothing is lost before setup.

-- ── Device tokens ──────────────────────────────────────────────────────
create table if not exists public.push_tokens (
  token       text primary key check (length(token) between 20 and 4096),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text not null check (platform in ('android', 'ios', 'web')),
  updated_at  timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
drop policy if exists push_tokens_own_read on public.push_tokens;
create policy push_tokens_own_read on public.push_tokens
  for select to authenticated using (user_id = auth.uid());
grant select on public.push_tokens to authenticated;

-- A token belongs to whoever registered it last on that device.
create or replace function public.register_push_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.push_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
     set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql security definer set search_path = public
as $$ delete from public.push_tokens where token = p_token and user_id = auth.uid() $$;

-- ── Settings readable by the app ───────────────────────────────────────
create table if not exists public.app_settings (
  key    text primary key,
  value  jsonb not null
);
alter table public.app_settings enable row level security;
-- No client policies: only the functions below read it.

create or replace function public.push_enabled()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select (value)::text = 'true' from public.app_settings
                        where key = 'push_enabled'), false) $$;

-- ── Outbox ─────────────────────────────────────────────────────────────
create table if not exists public.push_outbox (
  id             bigserial primary key,
  ward_id        text not null references public.wards (id) on delete cascade,
  exclude_user   uuid,
  title          text not null,
  body           text not null,
  data           jsonb not null default '{}'::jsonb,
  high_priority  boolean not null default false,
  channel        text not null default 'ward_notes',
  created_at     timestamptz not null default now(),
  sent_at        timestamptz,
  attempts       smallint not null default 0,
  last_error     text
);
create index if not exists push_outbox_pending_idx
  on public.push_outbox (id) where sent_at is null;
alter table public.push_outbox enable row level security;
-- No client policies: only the service role (Edge Function) reads it.

-- Wake the dispatcher right away when configured (pg_net + settings);
-- otherwise the per-minute cron picks the row up.
create or replace function public._kick_push_dispatch()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_url text := (select value #>> '{}' from public.app_settings where key = 'dispatch_url');
  v_secret text := (select value #>> '{}' from public.app_settings where key = 'dispatch_secret');
begin
  if v_url is null or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    return;
  end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3)'
    using v_url, '{}'::jsonb,
          jsonb_build_object('Content-Type', 'application/json',
                             'x-dispatch-secret', coalesce(v_secret, ''));
exception when others then
  raise warning 'push kick failed: %', sqlerrm;  -- never block the insert
end;
$$;

-- New note → alert the ward (not the author). System timeline lines
-- (discharge, transfer, results…) are inserted acknowledged and skipped.
create or replace function public.enqueue_note_push()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.is_acknowledged then return new; end if;
  insert into public.push_outbox (ward_id, exclude_user, title, body, data,
                                  high_priority, channel)
  values (
    new.ward_id, new.author_id,
    case when new.priority = 'Urgent' then 'Urgent · ' else '' end ||
      coalesce(nullif(new.patient_name, ''), 'Ward note'),
    coalesce(nullif(new.author_name, '') || ': ', '') || left(new.content, 160),
    jsonb_build_object('type', 'note', 'note_id', new.id::text,
                       'patient_id', coalesce(new.patient_id::text, '')),
    new.priority = 'Urgent', 'ward_notes');
  perform public._kick_push_dispatch();
  return new;
end;
$$;

drop trigger if exists notes_enqueue_push on public.notes;
create trigger notes_enqueue_push
  after insert on public.notes
  for each row execute function public.enqueue_note_push();

-- ── Due reminders ──────────────────────────────────────────────────────
alter table public.patient_reminders
  add column if not exists pushed_for timestamptz;

-- Queues one push per reminder each time it falls due (again after a
-- snooze ends). Run every minute by cron. Returns how many were queued.
create or replace function public.enqueue_due_reminders()
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  r record;
  v_alert timestamptz;
  v_count integer := 0;
begin
  for r in
    select * from public.patient_reminders
     where done_at is null
       and greatest(due_at, coalesce(snoozed_until, due_at)) <= now()
       and (pushed_for is null
            or pushed_for < greatest(due_at, coalesce(snoozed_until, due_at)))
     for update skip locked
  loop
    v_alert := greatest(r.due_at, coalesce(r.snoozed_until, r.due_at));
    insert into public.push_outbox (ward_id, title, body, data, high_priority, channel)
    values (
      r.ward_id, r.title,
      coalesce(nullif(r.patient_name, ''), 'Patient') || ' — ' ||
        case r.kind
          when 'newborn_prep' then 'get ready: CBC, TSH, blood grouping, TSB, RFT and OAE.'
          when 'newborn_send' then 'have the investigations been sent?'
          when 'newborn_results' then 'are the investigation results back?'
          else 'has this been done?'
        end,
      jsonb_build_object('type', 'reminder', 'reminder_id', r.id::text,
                         'patient_id', r.patient_id::text),
      true, 'patient_reminders');
    update public.patient_reminders set pushed_for = v_alert where id = r.id;
    v_count := v_count + 1;
  end loop;
  if v_count > 0 then perform public._kick_push_dispatch(); end if;
  return v_count;
end;
$$;

-- ── Grants ─────────────────────────────────────────────────────────────
revoke execute on function public.register_push_token(text, text) from public, anon;
revoke execute on function public.unregister_push_token(text) from public, anon;
revoke execute on function public.push_enabled() from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
grant execute on function public.push_enabled() to authenticated;
revoke execute on function public._kick_push_dispatch() from public, anon, authenticated;
revoke execute on function public.enqueue_note_push() from public, anon, authenticated;
revoke execute on function public.enqueue_due_reminders() from public, anon, authenticated;
