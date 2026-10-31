-- Structured shift handover (I-PASS: Illness severity, Patient summary,
-- Action list, Situation awareness & contingency, Synthesis by receiver).
--
-- * patients.handover_summary: 1–3 lines kept up to date between shifts;
--   who/when stamped by trigger.
-- * patient_contingencies: "If … then …" lines per patient (ward-scoped,
--   follow the patient on transfer).
-- * handovers + handover_entries: one session per shift change. The
--   outgoing person starts it (the patient list is captured then), the
--   incoming person marks each patient received (optionally with a
--   question) on their own phone, and finishing records who missed what.
--   Writes go through the RPCs below so names and times can be trusted.
--
-- Illness severity (the status dot) and the action list (jobs, reminders)
-- already exist.

-- ── Patient summary ────────────────────────────────────────────────────
alter table public.patients
  add column if not exists handover_summary         text,
  add column if not exists handover_summary_at      timestamptz,
  add column if not exists handover_summary_by_name text;

do $$ begin
  alter table public.patients add constraint patients_handover_summary_check
    check (handover_summary is null or length(handover_summary) <= 500);
exception when duplicate_object then null; end $$;

create or replace function public.stamp_handover_summary()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.handover_summary is not distinct from old.handover_summary then
    new.handover_summary_at := old.handover_summary_at;
    new.handover_summary_by_name := old.handover_summary_by_name;
    return new;
  end if;
  new.handover_summary := nullif(trim(coalesce(new.handover_summary, '')), '');
  if new.handover_summary is null then
    new.handover_summary_at := null;
    new.handover_summary_by_name := null;
  else
    new.handover_summary_at := now();
    new.handover_summary_by_name := public._my_name();
  end if;
  return new;
end;
$$;
revoke execute on function public.stamp_handover_summary() from public, anon, authenticated;

drop trigger if exists patients_stamp_handover_summary on public.patients;
create trigger patients_stamp_handover_summary
  before insert or update on public.patients
  for each row execute function public.stamp_handover_summary();

-- ── If / then ──────────────────────────────────────────────────────────
create table if not exists public.patient_contingencies (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  if_text          text not null check (length(trim(if_text)) between 1 and 200),
  then_text        text not null check (length(trim(then_text)) between 1 and 300),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now()
);
create index if not exists patient_contingencies_patient_idx
  on public.patient_contingencies (patient_id, created_at);

alter table public.patient_contingencies enable row level security;
drop policy if exists patient_contingencies_ward on public.patient_contingencies;
create policy patient_contingencies_ward on public.patient_contingencies for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (public.is_ward_member(ward_id) and ward_id = public.patient_ward(patient_id));
grant select, insert, update, delete on public.patient_contingencies to authenticated;

drop trigger if exists patient_contingencies_stamp on public.patient_contingencies;
create trigger patient_contingencies_stamp before insert on public.patient_contingencies
  for each row execute function public.stamp_row_creator();

do $$ begin
  alter publication supabase_realtime add table public.patient_contingencies;
exception when duplicate_object then null; end $$;

create or replace function public.patients_cascade_ward()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.ward_id is distinct from old.ward_id then
    update public.bilirubin_readings set ward_id = new.ward_id where patient_id = new.id;
    update public.phototherapy_sessions set ward_id = new.ward_id where patient_id = new.id;
    update public.weights set ward_id = new.ward_id where patient_id = new.id;
    update public.observations set ward_id = new.ward_id where patient_id = new.id;
    update public.patient_contingencies set ward_id = new.ward_id where patient_id = new.id;
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;

-- ── Handover sessions ─────────────────────────────────────────────────
create table if not exists public.handovers (
  id               uuid primary key default gen_random_uuid(),
  ward_id          text not null references public.wards (id) on delete cascade,
  unit_id          uuid references public.ward_units (id) on delete set null,
  scope_label      text not null default '',
  started_at       timestamptz not null default now(),
  given_by         uuid references public.profiles (id) on delete set null,
  given_by_name    text not null default '',
  finished_at      timestamptz,
  finished_by_name text
);
create index if not exists handovers_ward_idx on public.handovers (ward_id, started_at desc);

create table if not exists public.handover_entries (
  id                uuid primary key default gen_random_uuid(),
  handover_id       uuid not null references public.handovers (id) on delete cascade,
  ward_id           text not null references public.wards (id) on delete cascade,
  patient_id        uuid references public.patients (id) on delete set null,
  patient_name      text not null default '',
  bed_number        text not null default '',
  position          int not null default 0,
  received_at       timestamptz,
  received_by       uuid references public.profiles (id) on delete set null,
  received_by_name  text,
  question          text check (question is null or length(question) <= 300),
  unique (handover_id, patient_id)
);
create index if not exists handover_entries_handover_idx on public.handover_entries (handover_id, position);

alter table public.handovers enable row level security;
alter table public.handover_entries enable row level security;
drop policy if exists handovers_read on public.handovers;
create policy handovers_read on public.handovers for select to authenticated
  using (public.is_ward_member(ward_id));
drop policy if exists handover_entries_read on public.handover_entries;
create policy handover_entries_read on public.handover_entries for select to authenticated
  using (public.is_ward_member(ward_id));
-- Read only for clients; every write goes through the functions below.
grant select on public.handovers, public.handover_entries to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.handovers;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.handover_entries;
exception when duplicate_object then null; end $$;

-- Starts a handover for the ward (or one unit): captures the admitted
-- patients in bed order. Returns the handover id.
create or replace function public.start_handover(p_ward text, p_unit uuid default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
  v_label text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.is_ward_member(p_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  select name into v_label from public.wards where id = p_ward;
  if p_unit is not null then
    v_label := v_label || ' · ' || coalesce(
      (select name from public.ward_units where id = p_unit and ward_id = p_ward), '');
    if not exists (select 1 from public.ward_units where id = p_unit and ward_id = p_ward) then
      raise exception 'no such unit in this ward' using errcode = 'P0002';
    end if;
  end if;
  insert into public.handovers (ward_id, unit_id, scope_label, given_by, given_by_name)
  values (p_ward, p_unit, coalesce(v_label, ''), auth.uid(), public._my_name())
  returning id into v_id;

  insert into public.handover_entries (handover_id, ward_id, patient_id, patient_name, bed_number, position)
  select v_id, p_ward, p.id, p.name, coalesce(p.bed_number, ''),
         row_number() over (
           order by nullif(substring(coalesce(p.bed_number, '') from '^\d+'), '')::int nulls last,
                    lower(coalesce(p.bed_number, '')), lower(p.name))
    from public.patients p
   where p.ward_id = p_ward and p.is_active
     and (p_unit is null or p.unit_id = p_unit);
  return v_id;
end;
$$;

create or replace function public._open_handover_entry(p_entry uuid)
returns public.handover_entries
language plpgsql security definer set search_path = public
as $$
declare
  e public.handover_entries;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into e from public.handover_entries where id = p_entry for update;
  if e.id is null then raise exception 'no such handover entry' using errcode = 'P0002'; end if;
  if not public.is_ward_member(e.ward_id) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if exists (select 1 from public.handovers where id = e.handover_id and finished_at is not null) then
    raise exception 'this handover is finished' using errcode = '22023';
  end if;
  return e;
end;
$$;
revoke execute on function public._open_handover_entry(uuid) from public, anon, authenticated;

-- The incoming person confirms one patient (with an optional question).
create or replace function public.receive_handover_entry(p_entry uuid, p_question text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  e public.handover_entries := public._open_handover_entry(p_entry);
begin
  update public.handover_entries
     set received_at = now(), received_by = auth.uid(), received_by_name = public._my_name(),
         question = nullif(trim(coalesce(p_question, '')), '')
   where id = e.id;
end;
$$;

-- Undo a "received" (e.g. tapped by mistake) while the handover is open.
create or replace function public.unreceive_handover_entry(p_entry uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  e public.handover_entries := public._open_handover_entry(p_entry);
begin
  update public.handover_entries
     set received_at = null, received_by = null, received_by_name = null
   where id = e.id;
end;
$$;

-- Finish: anything not received stays unreceived (= missed).
create or replace function public.finish_handover(p_handover uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  h public.handovers;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into h from public.handovers where id = p_handover for update;
  if h.id is null then raise exception 'no such handover' using errcode = 'P0002'; end if;
  if not public.is_ward_member(h.ward_id) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if h.finished_at is not null then return; end if;
  update public.handovers set finished_at = now(), finished_by_name = public._my_name()
   where id = p_handover;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array['start_handover(text, uuid)', 'receive_handover_entry(uuid, text)',
                           'unreceive_handover_entry(uuid)', 'finish_handover(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
