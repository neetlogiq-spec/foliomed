-- Newborn (PNC) investigation workflow.
--
-- A "newborn screen" is the plan to send the standard newborn
-- investigations (CBC, TSH, blood grouping, TSB with direct/indirect,
-- RFT with electrolytes, OAE) at 48 or 72 hours of life, with:
--   * a heads-up reminder 8 or 12 hours before,
--   * a "have they been sent?" reminder at the hour itself,
--   * results entry afterwards (with an optional "results pending" reminder).
-- Every step is a security-definer RPC so the plan, its reminders and the
-- timeline note change together. Results are stored as JSON; the app owns
-- the field list and the bilirubin threshold assessment.

alter table public.patients
  add column if not exists gestation_weeks smallint,
  add column if not exists gestation_days smallint;

do $$ begin
  alter table public.patients add constraint patients_gestation_range check (
    (gestation_weeks is null or gestation_weeks between 22 and 44)
    and (gestation_days is null or gestation_days between 0 and 6));
exception when duplicate_object then null; end $$;

create table if not exists public.newborn_screens (
  id                uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references public.patients (id) on delete cascade,
  ward_id           text not null references public.wards (id) on delete cascade,
  planned_hours     smallint not null check (planned_hours between 1 and 336),
  lead_hours        smallint not null default 12 check (lead_hours between 0 and 48),
  due_at            timestamptz not null,
  status            text not null default 'planned'
                      check (status in ('planned', 'sent', 'resulted')),
  sent_at           timestamptz,
  sent_by           uuid references public.profiles (id) on delete set null,
  sent_by_name      text,
  results           jsonb not null default '{}'::jsonb,
  resulted_at       timestamptz,
  resulted_by       uuid references public.profiles (id) on delete set null,
  resulted_by_name  text,
  created_by        uuid references public.profiles (id) on delete set null,
  created_at        timestamptz not null default now()
);

create index if not exists newborn_screens_patient_idx
  on public.newborn_screens (patient_id, due_at);

alter table public.newborn_screens enable row level security;

-- Read for ward members; every write goes through the functions below.
drop policy if exists newborn_screens_read on public.newborn_screens;
create policy newborn_screens_read on public.newborn_screens
  for select to authenticated using (public.is_ward_member(ward_id));

grant select on public.newborn_screens to authenticated;
alter publication supabase_realtime add table public.newborn_screens;

-- Reminders can belong to a screen; deleting the screen removes them.
alter table public.patient_reminders
  add column if not exists screen_id uuid references public.newborn_screens (id) on delete cascade,
  add column if not exists kind text not null default 'general';

do $$ begin
  alter table public.patient_reminders add constraint patient_reminders_kind_check
    check (kind in ('general', 'newborn_prep', 'newborn_send', 'newborn_results'));
exception when duplicate_object then null; end $$;

create or replace function public._newborn_screen_for_update(p_screen uuid)
returns public.newborn_screens
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into s from public.newborn_screens where id = p_screen for update;
  if s.id is null then raise exception 'no such screen' using errcode = 'P0002'; end if;
  if not public.is_ward_member(s.ward_id) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  return s;
end;
$$;

create or replace function public._my_name() returns text
language sql stable security definer set search_path = public
as $$ select coalesce(name, '') from public.profiles where id = auth.uid() $$;

-- Plan the investigations at p_hours of life, with a heads-up p_lead_hours
-- before. Replaces any plan that hasn't been sent yet.
create or replace function public.plan_newborn_screen(
  p_patient uuid, p_hours int, p_lead_hours int default 12)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_name text;
  v_born timestamptz;
  v_due timestamptz;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, name, born_at into v_ward, v_name, v_born
    from public.patients where id = p_patient for update;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if v_born is null then
    raise exception 'set the date and time of birth first' using errcode = '22023';
  end if;
  if p_hours not between 1 and 336 or p_lead_hours not between 0 and 48 then
    raise exception 'hours out of range' using errcode = '22023';
  end if;

  delete from public.newborn_screens
   where patient_id = p_patient and status = 'planned';

  v_due := v_born + make_interval(hours => p_hours);
  insert into public.newborn_screens (patient_id, ward_id, planned_hours,
                                      lead_hours, due_at, created_by)
  values (p_patient, v_ward, p_hours, p_lead_hours, v_due, auth.uid())
  returning id into v_id;

  if p_lead_hours > 0 then
    insert into public.patient_reminders (patient_id, ward_id, patient_name,
                                          title, due_at, screen_id, kind)
    values (p_patient, v_ward, v_name,
            'Newborn investigations due in ' || p_lead_hours || ' h',
            v_due - make_interval(hours => p_lead_hours), v_id, 'newborn_prep');
  end if;
  insert into public.patient_reminders (patient_id, ward_id, patient_name,
                                        title, due_at, screen_id, kind)
  values (p_patient, v_ward, v_name,
          'Send ' || p_hours || '-hour newborn investigations',
          v_due, v_id, 'newborn_send');
  return v_id;
end;
$$;

create or replace function public.mark_newborn_screen_sent(p_screen uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
begin
  if s.status <> 'planned' then return; end if;  -- idempotent
  update public.newborn_screens
     set status = 'sent', sent_at = now(), sent_by = auth.uid(),
         sent_by_name = public._my_name()
   where id = p_screen;
  update public.patient_reminders
     set done_at = now()
   where screen_id = p_screen and kind in ('newborn_prep', 'newborn_send')
     and done_at is null;
  perform public._patient_event_note(s.patient_id, s.ward_id, 'Investigation',
    s.planned_hours || '-hour newborn investigations sent: CBC, TSH, blood '
    || 'grouping, TSB (total/direct/indirect), RFT (urea, creatinine, '
    || 'electrolytes) and OAE.');
end;
$$;

-- "Results not back yet": ask the ward again in p_hours.
create or replace function public.remind_newborn_results(p_screen uuid, p_hours int default 6)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
  v_name text;
begin
  if p_hours not between 1 and 72 then
    raise exception 'hours out of range' using errcode = '22023';
  end if;
  select name into v_name from public.patients where id = s.patient_id;
  delete from public.patient_reminders
   where screen_id = p_screen and kind = 'newborn_results' and done_at is null;
  insert into public.patient_reminders (patient_id, ward_id, patient_name,
                                        title, due_at, screen_id, kind)
  values (s.patient_id, s.ward_id, coalesce(v_name, ''),
          'Enter newborn investigation results',
          now() + make_interval(hours => p_hours), p_screen, 'newborn_results');
end;
$$;

-- Saves (or corrects) results. p_summary is the human-readable line the
-- app builds; it is posted to the patient's timeline.
create or replace function public.save_newborn_results(
  p_screen uuid, p_results jsonb, p_summary text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
  v_summary text := nullif(trim(coalesce(p_summary, '')), '');
begin
  if jsonb_typeof(p_results) <> 'object' then
    raise exception 'results must be an object' using errcode = '22023';
  end if;
  if length(p_results::text) > 20000 then
    raise exception 'results too large' using errcode = '22023';
  end if;
  update public.newborn_screens
     set status = 'resulted', results = p_results, resulted_at = now(),
         resulted_by = auth.uid(), resulted_by_name = public._my_name(),
         sent_at = coalesce(sent_at, now()),
         sent_by = coalesce(sent_by, auth.uid()),
         sent_by_name = coalesce(sent_by_name, public._my_name())
   where id = p_screen;
  update public.patient_reminders
     set done_at = now()
   where screen_id = p_screen and done_at is null;
  perform public._patient_event_note(s.patient_id, s.ward_id, 'Investigation',
    'Newborn investigation results' ||
    case when s.status = 'resulted' then ' (corrected)' else '' end ||
    coalesce(': ' || left(v_summary, 1500), '.'));
end;
$$;

-- Plans and their reminders follow the patient on transfer.
create or replace function public.transfer_patient(
  p_patient uuid, p_target_ward text, p_reason text default '', p_bed text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_from text;
  v_from_name text;
  v_to_name text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id into v_from from public.patients where id = p_patient for update;
  if v_from is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if v_from = p_target_ward then
    raise exception 'patient is already in that ward' using errcode = '22023';
  end if;
  if not public.is_ward_member(v_from) or not public.is_ward_member(p_target_ward) then
    raise exception 'you must be a member of both wards' using errcode = '42501';
  end if;
  select name into v_from_name from public.wards where id = v_from;
  select name into v_to_name from public.wards where id = p_target_ward;
  if v_to_name is null then raise exception 'no such ward' using errcode = 'P0002'; end if;

  update public.patients
     set ward_id = p_target_ward,
         bed_number = coalesce(nullif(trim(coalesce(p_bed, '')), ''), bed_number)
   where id = p_patient;
  update public.notes set ward_id = p_target_ward where patient_id = p_patient;
  update public.patient_reminders set ward_id = p_target_ward where patient_id = p_patient;
  update public.newborn_screens set ward_id = p_target_ward where patient_id = p_patient;

  perform public._patient_event_note(p_patient, p_target_ward, 'Transfer',
    'Transferred from ' || coalesce(v_from_name, v_from) || ' to ' || v_to_name ||
    coalesce('. Reason: ' || v_reason, '.'));
end;
$$;

revoke execute on function public._newborn_screen_for_update(uuid) from public, anon, authenticated;
revoke execute on function public._my_name() from public, anon, authenticated;
revoke execute on function public.plan_newborn_screen(uuid, int, int) from public, anon;
revoke execute on function public.mark_newborn_screen_sent(uuid) from public, anon;
revoke execute on function public.remind_newborn_results(uuid, int) from public, anon;
revoke execute on function public.save_newborn_results(uuid, jsonb, text) from public, anon;
grant execute on function public.plan_newborn_screen(uuid, int, int) to authenticated;
grant execute on function public.mark_newborn_screen_sent(uuid) to authenticated;
grant execute on function public.remind_newborn_results(uuid, int) to authenticated;
grant execute on function public.save_newborn_results(uuid, jsonb, text) to authenticated;
