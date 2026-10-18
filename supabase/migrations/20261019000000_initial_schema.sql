-- FolioMed initial schema (replaces Firestore collections + Cloud Functions).
--
-- Mapping from the old Firestore layout:
--   users/{uid}                     → public.profiles
--   wards/{wardId}                  → public.wards      (id = 5-digit code)
--   patients/{id}                   → public.patients
--   notes/{id}                      → public.notes
--   notes/{id}/comments/{id}        → public.note_comments
--   monitor_vitals/{patientId}      → public.monitor_vitals
--   monitor_vitals/{id}/history     → public.monitor_vitals_history
--   metrics/totals, recent_activity → public.metrics, public.recent_activity
--   storage monitor_snapshots/      → storage bucket "monitor-snapshots"
--
-- Cloud Functions replaced here:
--   onWardDeleted          → trigger wards_after_delete
--   onUserDeletedCleanup   → trigger profiles_before_delete + delete_my_account()
--   backfillMetrics        → not needed (metrics are counted in SQL)
--   sendPasswordResetEmail → Supabase Auth built-in reset (custom SMTP)
--   onNoteCreated (push)   → TODO: Edge Function once a push provider is chosen

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────── tables

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  name          text not null default '',
  email         text not null default '',
  role          text not null default 'doctor'
                check (role in ('doctor', 'nurse', 'admin')),
  ward_id       text not null default '',
  ward_ids      text[] not null default '{}',
  avatar_url    text,
  avatar_emoji  text,
  specialty     text,
  push_tokens   text[] not null default '{}',
  created_at    timestamptz not null default now()
);

create table public.wards (
  id                text primary key check (id ~ '^[0-9]{5}$'),
  name              text not null,
  floor             text not null default '',
  capacity          integer not null default 0 check (capacity >= 0),
  head_doctor_name  text not null default '',
  creator_id        uuid references public.profiles (id) on delete cascade,
  creator_email     text not null default '',
  member_ids        uuid[] not null default '{}',
  created_at        timestamptz not null default now()
);

create table public.patients (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  age             integer not null default 0 check (age >= 0),
  gender          text not null default '',
  ward_id         text not null references public.wards (id) on delete cascade,
  bed_number      text not null default '',
  diagnosis       text not null default '',
  blood_group     text,
  admitted_at     timestamptz not null default now(),
  is_active       boolean not null default true,
  hls_stream_url  text not null default '',
  created_at      timestamptz not null default now()
);

create table public.notes (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  patient_name     text not null default '',
  ward_id          text not null references public.wards (id) on delete cascade,
  author_id        uuid references public.profiles (id) on delete set null,
  author_name      text not null default '',
  author_role      text not null default '',
  content          text not null,
  category         text not null default 'General',
  priority         text not null default 'Normal',
  is_acknowledged  boolean not null default false,
  acknowledged_by  text,
  acknowledged_at  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.note_comments (
  id                 uuid primary key default gen_random_uuid(),
  note_id            uuid not null references public.notes (id) on delete cascade,
  text               text not null,
  author_id          uuid references public.profiles (id) on delete set null,
  author_name        text not null default '',
  author_role        text not null default '',
  is_acknowledgement boolean not null default false,
  created_at         timestamptz not null default now()
);

create table public.monitor_vitals (
  patient_id  uuid primary key references public.patients (id) on delete cascade,
  sender_id   uuid references public.profiles (id) on delete set null,
  source      text not null default 'ocr',
  confidence  double precision,
  vitals      jsonb not null default '{}',
  recorded_at timestamptz not null default now()
);

create table public.monitor_vitals_history (
  id          bigint generated always as identity primary key,
  patient_id  uuid not null references public.patients (id) on delete cascade,
  sender_id   uuid references public.profiles (id) on delete set null,
  source      text not null default 'ocr',
  confidence  double precision,
  vitals      jsonb not null default '{}',
  recorded_at timestamptz not null default now()
);

create table public.metrics (
  type        text primary key,
  count       bigint not null default 0,
  last_at     timestamptz
);

create table public.recent_activity (
  id       bigint generated always as identity primary key,
  type     text not null,
  summary  text not null default '',
  at       timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────── indexes

create index notes_ward_created_idx    on public.notes (ward_id, created_at desc);
create index notes_patient_created_idx on public.notes (patient_id, created_at desc);
create index notes_ward_unack_idx      on public.notes (ward_id, created_at desc)
  where not is_acknowledged;
create index patients_ward_active_idx  on public.patients (ward_id, is_active, admitted_at desc);
create index note_comments_note_idx    on public.note_comments (note_id, created_at);
create index profiles_ward_ids_idx     on public.profiles using gin (ward_ids);
create index wards_member_ids_idx      on public.wards using gin (member_ids);
create index vitals_history_patient_idx
  on public.monitor_vitals_history (patient_id, recorded_at desc);

-- ─────────────────────────────────────────────────────────────── helpers

create or replace function public.is_ward_member(p_ward_id text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and p_ward_id = any (ward_ids)
  ) or exists (
    select 1 from public.wards
    where id = p_ward_id and creator_id = auth.uid()
  );
$$;

create or replace function public.patient_ward(p_patient_id uuid)
returns text
language sql stable security definer set search_path = public
as $$ select ward_id from public.patients where id = p_patient_id; $$;

create or replace function public.note_ward(p_note_id uuid)
returns text
language sql stable security definer set search_path = public
as $$ select ward_id from public.notes where id = p_note_id; $$;

-- ─────────────────────────────────────────────────────────────── triggers

-- Create the profile row as soon as an auth user exists. Email sign-up
-- passes name / role / ward_id in user metadata; OAuth users default to
-- doctor with no ward (same as the Firebase version).
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  meta     jsonb := coalesce(new.raw_user_meta_data, '{}');
  v_role   text  := coalesce(meta ->> 'role', 'doctor');
  v_ward   text  := coalesce(meta ->> 'ward_id', '');
  v_name   text  := coalesce(
                      nullif(meta ->> 'name', ''),
                      nullif(meta ->> 'full_name', ''),
                      split_part(coalesce(new.email, 'User'), '@', 1));
begin
  if v_role not in ('doctor', 'nurse', 'admin') then
    v_role := 'doctor';
  end if;
  insert into public.profiles (id, name, email, role, ward_id, ward_ids, avatar_url)
  values (
    new.id, v_name, coalesce(new.email, ''), v_role, v_ward,
    case when v_ward = '' then '{}'::text[] else array[v_ward] end,
    meta ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  perform public.bump_metric('user', 'New account: ' || v_name);
  return new;
end;
$$;

-- Remove a deleted ward's id from every member's profile.
create or replace function public.handle_ward_deleted()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.profiles
     set ward_ids = array_remove(ward_ids, old.id),
         ward_id  = case when ward_id = old.id then '' else ward_id end
   where old.id = any (ward_ids) or ward_id = old.id;
  return old;
end;
$$;

-- When a profile goes away, drop it from member lists of joined wards.
-- Owned wards cascade via wards.creator_id.
create or replace function public.handle_profile_deleted()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.wards
     set member_ids = array_remove(member_ids, old.id)
   where old.id = any (member_ids);
  return old;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────── metrics

create or replace function public.bump_metric(p_type text, p_summary text default '')
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_type not in ('note', 'patient', 'ward', 'user', 'ack', 'comment') then
    raise exception 'unknown metric type %', p_type;
  end if;
  insert into public.metrics (type, count, last_at)
  values (p_type, 1, now())
  on conflict (type) do update
    set count = public.metrics.count + 1, last_at = now();
  insert into public.recent_activity (type, summary)
  values (p_type, left(coalesce(p_summary, ''), 200));
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger wards_after_delete
  after delete on public.wards
  for each row execute function public.handle_ward_deleted();

create trigger profiles_before_delete
  before delete on public.profiles
  for each row execute function public.handle_profile_deleted();

create trigger notes_touch_updated_at
  before update on public.notes
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────── RPCs

-- Join a ward by its 5-digit code. Returns false if the code is unknown.
create or replace function public.join_ward(p_ward_id text)
returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.wards where id = p_ward_id) then
    return false;
  end if;
  update public.wards
     set member_ids = array_append(array_remove(member_ids, auth.uid()), auth.uid())
   where id = p_ward_id;
  update public.profiles
     set ward_ids = array_append(array_remove(ward_ids, p_ward_id), p_ward_id),
         ward_id  = case when ward_id = '' then p_ward_id else ward_id end
   where id = auth.uid();
  return true;
end;
$$;

create or replace function public.leave_ward(p_ward_id text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  update public.wards
     set member_ids = array_remove(member_ids, auth.uid())
   where id = p_ward_id;
  update public.profiles
     set ward_ids = array_remove(ward_ids, p_ward_id),
         ward_id  = case when ward_id = p_ward_id then '' else ward_id end
   where id = auth.uid();
end;
$$;

-- Number of members in a ward the caller belongs to (for the Wards tab).
create or replace function public.ward_member_count(p_ward_id text)
returns integer
language sql stable security definer set search_path = public
as $$
  select case when public.is_ward_member(p_ward_id)
    then (select count(*)::int from public.profiles where p_ward_id = any (ward_ids))
    else 0 end;
$$;

-- Self-service account deletion (Apple requires it). Deleting the auth
-- user cascades to profiles → owned wards → patients → notes → comments.
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public, auth
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Admin dashboard counts in one round trip (admins only).
create or replace function public.dashboard_counts(p_since timestamptz default date_trunc('day', now()))
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'staff',            (select count(*) from public.profiles),
    'wards',            (select count(*) from public.wards),
    'active_patients',  (select count(*) from public.patients where is_active),
    'patients',         (select count(*) from public.patients),
    'notes',            (select count(*) from public.notes),
    'notes_today',      (select count(*) from public.notes where created_at >= p_since),
    'acked_notes',      (select count(*) from public.notes where is_acknowledged),
    'urgent_notes',     (select count(*) from public.notes where priority = 'Urgent'),
    'comments',         (select coalesce(sum(count), 0) from public.metrics where type = 'comment')
  );
end;
$$;

revoke execute on function public.delete_my_account() from anon, public;
revoke execute on function public.join_ward(text)      from anon, public;
revoke execute on function public.leave_ward(text)     from anon, public;
revoke execute on function public.bump_metric(text, text) from anon, public;
revoke execute on function public.dashboard_counts(timestamptz) from anon, public;
grant execute on function public.delete_my_account()   to authenticated;
grant execute on function public.join_ward(text)       to authenticated;
grant execute on function public.leave_ward(text)      to authenticated;
grant execute on function public.ward_member_count(text) to authenticated;
grant execute on function public.bump_metric(text, text) to authenticated;
grant execute on function public.dashboard_counts(timestamptz) to authenticated;

-- ─────────────────────────────────────────────────────────────── RLS

alter table public.profiles               enable row level security;
alter table public.wards                  enable row level security;
alter table public.patients               enable row level security;
alter table public.notes                  enable row level security;
alter table public.note_comments          enable row level security;
alter table public.monitor_vitals         enable row level security;
alter table public.monitor_vitals_history enable row level security;
alter table public.metrics                enable row level security;
alter table public.recent_activity        enable row level security;

-- profiles: signed-in users can look each other up; only edit yourself.
create policy profiles_select on public.profiles
  for select to authenticated using (true);
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_delete_own on public.profiles
  for delete to authenticated using (id = auth.uid());

-- wards: creator or member can see; creator manages. Joining goes via join_ward().
create policy wards_select on public.wards
  for select to authenticated
  using (creator_id = auth.uid() or auth.uid() = any (member_ids)
         or public.is_ward_member(id));
create policy wards_insert on public.wards
  for insert to authenticated with check (creator_id = auth.uid());
create policy wards_update on public.wards
  for update to authenticated
  using (creator_id = auth.uid()) with check (creator_id = auth.uid());
create policy wards_delete on public.wards
  for delete to authenticated using (creator_id = auth.uid());

-- patients / notes: ward members only (tighter than the old Firestore rules,
-- which let any signed-in user write).
create policy patients_all on public.patients
  for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (public.is_ward_member(ward_id));

create policy notes_all on public.notes
  for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (public.is_ward_member(ward_id));

create policy note_comments_all on public.note_comments
  for all to authenticated
  using (public.is_ward_member(public.note_ward(note_id)))
  with check (public.is_ward_member(public.note_ward(note_id)));

create policy monitor_vitals_all on public.monitor_vitals
  for all to authenticated
  using (public.is_ward_member(public.patient_ward(patient_id)))
  with check (public.is_ward_member(public.patient_ward(patient_id)));

create policy monitor_vitals_history_all on public.monitor_vitals_history
  for all to authenticated
  using (public.is_ward_member(public.patient_ward(patient_id)))
  with check (public.is_ward_member(public.patient_ward(patient_id)));

-- metrics: public counters (landing page). Writes only via bump_metric().
create policy metrics_public_read on public.metrics
  for select to anon, authenticated using (true);
-- recent_activity summaries contain patient names → signed-in only.
create policy recent_activity_read on public.recent_activity
  for select to authenticated using (true);

-- ─────────────────────────────────────────────────────────────── realtime

alter publication supabase_realtime add table
  public.profiles, public.wards, public.patients, public.notes,
  public.note_comments, public.monitor_vitals;

-- ─────────────────────────────────────────────────────────────── storage

insert into storage.buckets (id, name, public)
values ('monitor-snapshots', 'monitor-snapshots', false)
on conflict (id) do nothing;

-- Object path: <patient_id>/latest.jpg
create policy monitor_snapshots_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'monitor-snapshots'
         and public.is_ward_member(public.patient_ward(((storage.foldername(name))[1])::uuid)))
  with check (bucket_id = 'monitor-snapshots'
         and public.is_ward_member(public.patient_ward(((storage.foldername(name))[1])::uuid)));

-- ─────────────────────────────────────────────────────────────── public status

-- Activity feed for the public status page: event type + time only.
-- Summaries can contain patient names, so they never leave the database.
create or replace function public.public_activity(p_limit integer default 20)
returns table (type text, at timestamptz)
language sql stable security definer set search_path = public
as $$
  select type, at from public.recent_activity
  order by at desc
  limit least(greatest(p_limit, 1), 50);
$$;

grant execute on function public.public_activity(integer) to anon, authenticated;
