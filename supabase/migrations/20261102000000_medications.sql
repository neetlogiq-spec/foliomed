-- Medications and allergies.
--
-- * patient_medications: one row per drug. context 'inpatient' = given on
--   this admission (active until stopped); 'home' = regular medicine before
--   admission; 'past' = an important earlier drug. Inpatient drugs are
--   started, changed and stopped by doctors (or the ward owner); drug
--   history is recorded by doctors and nurses.
-- * patient_medication_events: start / change / stop history per drug.
-- * patient_allergies: what the patient reacted to and how; adding one
--   clears "no known allergies" (patients.nka_*).
-- All writes go through RPCs that stamp who and when and write a Medication
-- or Allergy note on the timeline. Rows follow the patient on transfer.

alter table public.patients
  add column if not exists nka_recorded_at   timestamptz,
  add column if not exists nka_recorded_by_name text;

create table if not exists public.patient_medications (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  context          text not null check (context in ('inpatient', 'home', 'past')),
  drug_key         text check (drug_key is null or drug_key ~ '^[a-z0-9_]{1,40}$'),
  drug_name        text not null check (length(drug_name) between 1 and 80),
  dose             numeric check (dose is null or (dose > 0 and dose <= 1000000)),
  dose_unit        text not null default '' check (length(dose_unit) <= 20),
  route            text not null default '' check (length(route) <= 30),
  frequency        text not null default '' check (length(frequency) <= 30),
  indication       text check (indication is null or length(indication) <= 200),
  info_source      text check (info_source is null or length(info_source) <= 60),
  note             text check (note is null or length(note) <= 300),
  started_on       date,
  created_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  stopped_at       timestamptz,
  stopped_by_name  text,
  stop_reason      text check (stop_reason is null or length(stop_reason) <= 200)
);
create index if not exists patient_medications_patient_idx
  on public.patient_medications (patient_id, created_at);

create table if not exists public.patient_medication_events (
  id               uuid primary key default gen_random_uuid(),
  medication_id    uuid not null references public.patient_medications (id) on delete cascade,
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  kind             text not null check (kind in ('start', 'change', 'stop')),
  summary          text not null check (length(summary) <= 300),
  at               timestamptz not null default now(),
  by_name          text
);
create index if not exists patient_medication_events_patient_idx
  on public.patient_medication_events (patient_id, at);

create table if not exists public.patient_allergies (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  substance        text not null check (length(substance) between 1 and 80),
  reaction         text check (reaction is null or length(reaction) <= 200),
  severity         text not null default 'unknown'
                   check (severity in ('mild', 'moderate', 'severe', 'unknown')),
  kind             text not null default 'drug' check (kind in ('drug', 'food', 'anaesthesia', 'other')),
  info_source      text check (info_source is null or length(info_source) <= 60),
  created_at       timestamptz not null default now(),
  created_by_name  text
);
create index if not exists patient_allergies_patient_idx on public.patient_allergies (patient_id);

do $$
declare t text;
begin
  foreach t in array array['patient_medications', 'patient_medication_events', 'patient_allergies'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_ward_member(ward_id))',
                   t || '_read', t);
    execute format('revoke insert, update, delete on public.%I from authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ── Helpers ──────────────────────────────────────────────────────────
-- The patient's ward after checking membership (and, if p_doctor, that the
-- caller is a doctor or the ward owner) and that the patient is admitted.
create or replace function public._med_ward(p_patient uuid, p_doctor boolean)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_active boolean;
  v_role text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, is_active into v_ward, v_active from public.patients where id = p_patient;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if not v_active then raise exception 'patient is discharged' using errcode = '22023'; end if;
  if p_doctor then
    select role into v_role from public.profiles where id = auth.uid();
    if v_role is distinct from 'doctor' and not public._is_ward_owner(v_ward) then
      raise exception 'only doctors can prescribe' using errcode = '42501';
    end if;
  end if;
  return v_ward;
end;
$$;
revoke execute on function public._med_ward(uuid, boolean) from public, anon, authenticated;

create or replace function public._my_name()
returns text
language sql stable security definer set search_path = public
as $$ select name from public.profiles where id = auth.uid(); $$;
revoke execute on function public._my_name() from public, anon, authenticated;

-- "Amoxicillin 30 mg/kg IV TDS"
create or replace function public._med_line(p_name text, p_dose numeric, p_unit text, p_route text, p_freq text)
returns text
language sql immutable
as $$
  select concat_ws(' ', p_name,
    case when p_dose is null then null else trim_scale(round(p_dose, 3))::text || ' ' || nullif(p_unit, '') end,
    nullif(p_route, ''), nullif(p_freq, ''));
$$;
revoke execute on function public._med_line(text, numeric, text, text, text) from public, anon, authenticated;

-- ── Medications ──────────────────────────────────────────────────────
create or replace function public.add_medication(
  p_patient uuid, p_context text, p_drug_key text, p_name text, p_dose numeric, p_unit text,
  p_route text, p_freq text, p_indication text default null, p_started_on date default null,
  p_info_source text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, p_context = 'inpatient');
  v_name text := public._my_name();
  v_id uuid;
  v_line text := public._med_line(trim(p_name), p_dose, trim(coalesce(p_unit, '')),
                                  trim(coalesce(p_route, '')), trim(coalesce(p_freq, '')));
  v_ind text := nullif(trim(coalesce(p_indication, '')), '');
  v_src text := nullif(trim(coalesce(p_info_source, '')), '');
begin
  if p_context not in ('inpatient', 'home', 'past') then
    raise exception 'unknown medication context' using errcode = '22023';
  end if;
  insert into public.patient_medications (patient_id, ward_id, context, drug_key, drug_name, dose, dose_unit,
    route, frequency, indication, info_source, note, started_on, created_by, created_by_name)
  values (p_patient, v_ward, p_context, nullif(p_drug_key, ''), trim(p_name), p_dose, trim(coalesce(p_unit, '')),
    trim(coalesce(p_route, '')), trim(coalesce(p_freq, '')), v_ind, v_src,
    nullif(trim(coalesce(p_note, '')), ''),
    case when p_context = 'inpatient' then coalesce(p_started_on, current_date) else p_started_on end,
    auth.uid(), v_name)
  returning id into v_id;
  if p_context = 'inpatient' then
    insert into public.patient_medication_events (medication_id, patient_id, ward_id, kind, summary, by_name)
    values (v_id, p_patient, v_ward, 'start', v_line, v_name);
  end if;
  perform public._patient_event_note(p_patient, v_ward, 'Medication',
    case p_context
      when 'inpatient' then 'Started ' || v_line || coalesce(' — ' || v_ind, '') || '.'
      when 'home' then 'Drug history: takes ' || v_line || coalesce(' (from ' || v_src || ')', '') || '.'
      else 'Drug history: previously ' || v_line || coalesce(' (from ' || v_src || ')', '') || '.'
    end);
  return v_id;
end;
$$;
revoke execute on function public.add_medication(uuid, text, text, text, numeric, text, text, text, text, date, text, text)
  from public, anon;
grant execute on function public.add_medication(uuid, text, text, text, numeric, text, text, text, text, date, text, text)
  to authenticated;

create or replace function public.change_medication(
  p_id uuid, p_dose numeric, p_unit text, p_route text, p_freq text, p_reason text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.patient_medications;
  v_ward text;
  v_name text := public._my_name();
  v_old text;
  v_new text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  select * into v_row from public.patient_medications where id = p_id for update;
  if v_row.id is null then raise exception 'no such medication' using errcode = 'P0002'; end if;
  v_ward := public._med_ward(v_row.patient_id, true);
  if v_row.context <> 'inpatient' or v_row.stopped_at is not null then
    raise exception 'only active medicines can be changed' using errcode = '22023';
  end if;
  v_old := public._med_line('', v_row.dose, v_row.dose_unit, v_row.route, v_row.frequency);
  update public.patient_medications
     set dose = p_dose, dose_unit = trim(coalesce(p_unit, '')), route = trim(coalesce(p_route, '')),
         frequency = trim(coalesce(p_freq, ''))
   where id = p_id;
  v_new := public._med_line('', p_dose, trim(coalesce(p_unit, '')), trim(coalesce(p_route, '')),
                            trim(coalesce(p_freq, '')));
  insert into public.patient_medication_events (medication_id, patient_id, ward_id, kind, summary, by_name)
  values (p_id, v_row.patient_id, v_ward, 'change', trim(v_old) || ' → ' || trim(v_new) || coalesce(' — ' || v_reason, ''),
          v_name);
  perform public._patient_event_note(v_row.patient_id, v_ward, 'Medication',
    v_row.drug_name || ' changed: ' || trim(v_old) || ' → ' || trim(v_new) || coalesce(' — ' || v_reason, '') || '.');
end;
$$;
revoke execute on function public.change_medication(uuid, numeric, text, text, text, text) from public, anon;
grant execute on function public.change_medication(uuid, numeric, text, text, text, text) to authenticated;

-- Stops an active medicine (doctors), or removes a drug-history entry made
-- in error (doctors and nurses).
create or replace function public.stop_medication(p_id uuid, p_reason text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.patient_medications;
  v_ward text;
  v_name text := public._my_name();
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  select * into v_row from public.patient_medications where id = p_id for update;
  if v_row.id is null then raise exception 'no such medication' using errcode = 'P0002'; end if;
  if v_row.stopped_at is not null then return; end if;
  v_ward := public._med_ward(v_row.patient_id, v_row.context = 'inpatient');
  update public.patient_medications
     set stopped_at = now(), stopped_by_name = v_name, stop_reason = v_reason
   where id = p_id;
  if v_row.context = 'inpatient' then
    insert into public.patient_medication_events (medication_id, patient_id, ward_id, kind, summary, by_name)
    values (p_id, v_row.patient_id, v_ward, 'stop', coalesce(v_reason, 'Stopped'), v_name);
    perform public._patient_event_note(v_row.patient_id, v_ward, 'Medication',
      'Stopped ' || v_row.drug_name || coalesce(' — ' || v_reason, '') || '.');
  else
    perform public._patient_event_note(v_row.patient_id, v_ward, 'Medication',
      'Drug history: removed ' || v_row.drug_name || coalesce(' — ' || v_reason, '') || '.');
  end if;
end;
$$;
revoke execute on function public.stop_medication(uuid, text) from public, anon;
grant execute on function public.stop_medication(uuid, text) to authenticated;

-- ── Allergies ────────────────────────────────────────────────────────
create or replace function public.add_allergy(
  p_patient uuid, p_substance text, p_reaction text default null, p_severity text default 'unknown',
  p_kind text default 'drug', p_info_source text default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, false);
  v_name text := public._my_name();
  v_id uuid;
  v_reaction text := nullif(trim(coalesce(p_reaction, '')), '');
begin
  insert into public.patient_allergies (patient_id, ward_id, substance, reaction, severity, kind, info_source,
                                        created_by_name)
  values (p_patient, v_ward, trim(p_substance), v_reaction, coalesce(p_severity, 'unknown'), coalesce(p_kind, 'drug'),
          nullif(trim(coalesce(p_info_source, '')), ''), v_name)
  returning id into v_id;
  update public.patients set nka_recorded_at = null, nka_recorded_by_name = null where id = p_patient;
  perform public._patient_event_note(p_patient, v_ward, 'Allergy',
    'Allergy recorded: ' || trim(p_substance) || coalesce(' — ' || v_reaction, '')
    || case when coalesce(p_severity, 'unknown') = 'unknown' then '' else ' (' || p_severity || ')' end || '.');
  return v_id;
end;
$$;
revoke execute on function public.add_allergy(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.add_allergy(uuid, text, text, text, text, text) to authenticated;

-- Removing an allergy (recorded in error) is for doctors, with a reason.
create or replace function public.remove_allergy(p_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.patient_allergies;
  v_ward text;
begin
  select * into v_row from public.patient_allergies where id = p_id;
  if v_row.id is null then raise exception 'no such allergy' using errcode = 'P0002'; end if;
  v_ward := public._med_ward(v_row.patient_id, true);
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'give a reason for removing an allergy' using errcode = '22023';
  end if;
  delete from public.patient_allergies where id = p_id;
  perform public._patient_event_note(v_row.patient_id, v_ward, 'Allergy',
    'Allergy removed: ' || v_row.substance || ' — ' || trim(p_reason) || '.');
end;
$$;
revoke execute on function public.remove_allergy(uuid, text) from public, anon;
grant execute on function public.remove_allergy(uuid, text) to authenticated;

-- "No known allergies" — only when none are recorded.
create or replace function public.set_no_known_allergies(p_patient uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, false);
begin
  if exists (select 1 from public.patient_allergies where patient_id = p_patient) then
    raise exception 'allergies are recorded for this patient' using errcode = '22023';
  end if;
  update public.patients set nka_recorded_at = now(), nka_recorded_by_name = public._my_name()
   where id = p_patient;
  perform public._patient_event_note(p_patient, v_ward, 'Allergy', 'No known allergies.');
end;
$$;
revoke execute on function public.set_no_known_allergies(uuid) from public, anon;
grant execute on function public.set_no_known_allergies(uuid) to authenticated;

-- ── Follow the patient on transfer ───────────────────────────────────
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
    update public.patient_infusions set ward_id = new.ward_id where patient_id = new.id;
    update public.patient_medications set ward_id = new.ward_id where patient_id = new.id;
    update public.patient_medication_events set ward_id = new.ward_id where patient_id = new.id;
    update public.patient_allergies set ward_id = new.ward_id where patient_id = new.id;
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;
