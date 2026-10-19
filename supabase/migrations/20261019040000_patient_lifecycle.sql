-- Patient lifecycle: unique patient IDs, age units, discharge and transfer.
--
-- * patient_code: system-wide unique, human-readable ID (FM000123),
--   assigned by the database and immutable.
-- * hospital_id: optional hospital MRN / IP number, free text.
-- * age_unit: 'days' | 'months' | 'years' (neonates and infants).
-- * status: 'admitted' | 'discharged', with who/when/summary; is_active is
--   kept in sync so existing queries keep working.
-- * discharge_patient / readmit_patient / transfer_patient RPCs record a
--   timeline note for every event. A transfer moves the patient's notes
--   (and therefore their replies) to the destination ward, so the new team
--   inherits the full history and the old ward loses access.

create sequence if not exists public.patient_code_seq;
-- Inserting a patient draws the next code, so signed-in users need the sequence.
grant usage, select on sequence public.patient_code_seq to authenticated;

alter table public.patients
  add column if not exists patient_code text,
  add column if not exists hospital_id text,
  add column if not exists age_unit text not null default 'years',
  add column if not exists status text not null default 'admitted',
  add column if not exists discharged_at timestamptz,
  add column if not exists discharged_by uuid references public.profiles (id) on delete set null,
  add column if not exists discharge_summary text;

-- Backfill codes for existing patients (oldest first), then enforce.
update public.patients p
   set patient_code = 'FM' || lpad(nextval('public.patient_code_seq')::text, 6, '0')
  from (select id from public.patients where patient_code is null order by created_at) o
 where p.id = o.id;

alter table public.patients
  alter column patient_code set default
    ('FM' || lpad(nextval('public.patient_code_seq')::text, 6, '0')),
  alter column patient_code set not null;

do $$ begin
  alter table public.patients add constraint patients_patient_code_key unique (patient_code);
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.patients add constraint patients_age_unit_check
    check (age_unit in ('days', 'months', 'years'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.patients add constraint patients_status_check
    check (status in ('admitted', 'discharged'));
exception when duplicate_object then null; end $$;

create index if not exists patients_ward_status_idx
  on public.patients (ward_id, status, admitted_at desc);

-- patient_code never changes; is_active mirrors status.
create or replace function public.guard_patient_row()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    new.patient_code := old.patient_code;
  end if;
  new.is_active := (new.status = 'admitted');
  return new;
end;
$$;

drop trigger if exists patients_guard_row on public.patients;
create trigger patients_guard_row
  before insert or update on public.patients
  for each row execute function public.guard_patient_row();

-- Timeline note written on behalf of the caller.
create or replace function public._patient_event_note(
  p_patient uuid, p_ward text, p_category text, p_content text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_name text;
  v_role text;
  v_patient_name text;
begin
  select name, role into v_name, v_role from public.profiles where id = auth.uid();
  select name into v_patient_name from public.patients where id = p_patient;
  insert into public.notes (patient_id, patient_name, ward_id, author_id,
                            author_name, author_role, content, category,
                            priority, is_acknowledged)
  values (p_patient, coalesce(v_patient_name, ''), p_ward, auth.uid(),
          coalesce(v_name, ''), coalesce(v_role, ''), p_content, p_category,
          'Normal', true);
end;
$$;

create or replace function public.discharge_patient(p_patient uuid, p_summary text default '')
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_status text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, status into v_ward, v_status from public.patients where id = p_patient for update;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if v_status = 'discharged' then return; end if;
  update public.patients
     set status = 'discharged', discharged_at = now(), discharged_by = auth.uid(),
         discharge_summary = nullif(trim(coalesce(p_summary, '')), '')
   where id = p_patient;
  perform public._patient_event_note(p_patient, v_ward, 'Discharge',
    'Discharged' || case when nullif(trim(coalesce(p_summary, '')), '') is null
                         then '.' else ': ' || trim(p_summary) end);
end;
$$;

create or replace function public.readmit_patient(p_patient uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id into v_ward from public.patients where id = p_patient for update;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  update public.patients
     set status = 'admitted', admitted_at = now(), discharged_at = null,
         discharged_by = null, discharge_summary = null
   where id = p_patient and status = 'discharged';
  if found then
    perform public._patient_event_note(p_patient, v_ward, 'Admission', 'Readmitted.');
  end if;
end;
$$;

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
  -- History travels with the patient; replies follow their notes.
  update public.notes set ward_id = p_target_ward where patient_id = p_patient;

  perform public._patient_event_note(p_patient, p_target_ward, 'Transfer',
    'Transferred from ' || coalesce(v_from_name, v_from) || ' to ' || v_to_name ||
    coalesce('. Reason: ' || v_reason, '.'));
end;
$$;

revoke execute on function public._patient_event_note(uuid, text, text, text) from public, anon, authenticated;
revoke execute on function public.guard_patient_row() from public, anon, authenticated;
revoke execute on function public.discharge_patient(uuid, text) from public, anon;
revoke execute on function public.readmit_patient(uuid) from public, anon;
revoke execute on function public.transfer_patient(uuid, text, text, text) from public, anon;
grant execute on function public.discharge_patient(uuid, text) to authenticated;
grant execute on function public.readmit_patient(uuid) to authenticated;
grant execute on function public.transfer_patient(uuid, text, text, text) to authenticated;
