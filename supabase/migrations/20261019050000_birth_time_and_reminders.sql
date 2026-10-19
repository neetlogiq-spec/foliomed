-- Newborn (PNC) support: exact time of birth, and ward-shared reminders
-- such as "Send 48-hour investigations".
--
-- * patients.born_at: date AND time of birth. When set, the app derives the
--   age from it (hours in the first week) instead of age/age_unit.
-- * patient_reminders: due-at reminders on a patient, visible to the whole
--   ward. Marking one done records who and when; "Not yet" snoozes it for
--   everyone. Reminders follow the patient on transfer.

alter table public.patients
  add column if not exists born_at timestamptz;

do $$ begin
  alter table public.patients add constraint patients_born_at_not_future
    check (born_at is null or born_at <= now() + interval '1 hour');
exception when duplicate_object then null; end $$;

create table if not exists public.patient_reminders (
  id             uuid primary key default gen_random_uuid(),
  patient_id     uuid not null references public.patients (id) on delete cascade,
  ward_id        text not null references public.wards (id) on delete cascade,
  patient_name   text not null default '',  -- denormalised for notifications
  title          text not null check (length(trim(title)) between 1 and 200),
  due_at         timestamptz not null,
  snoozed_until  timestamptz,
  done_at        timestamptz,
  done_by        uuid references public.profiles (id) on delete set null,
  done_by_name   text,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now()
);

create index if not exists patient_reminders_ward_open_idx
  on public.patient_reminders (ward_id, due_at) where done_at is null;
create index if not exists patient_reminders_patient_idx
  on public.patient_reminders (patient_id, due_at);

alter table public.patient_reminders enable row level security;

drop policy if exists patient_reminders_all on public.patient_reminders;
create policy patient_reminders_all on public.patient_reminders
  for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (
    public.is_ward_member(ward_id)
    and ward_id = public.patient_ward(patient_id)
  );

-- Who completed it is stamped by the server, not trusted from the client.
create or replace function public.stamp_reminder_done()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.done_at is not null and old.done_at is null then
    new.done_by := auth.uid();
    select name into new.done_by_name from public.profiles where id = auth.uid();
  elsif new.done_at is null then
    new.done_by := null;
    new.done_by_name := null;
  end if;
  return new;
end;
$$;

drop trigger if exists patient_reminders_stamp_done on public.patient_reminders;
create trigger patient_reminders_stamp_done
  before update on public.patient_reminders
  for each row execute function public.stamp_reminder_done();

create or replace function public.stamp_reminder_creator()
returns trigger
language plpgsql
as $$
begin
  new.created_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists patient_reminders_stamp_creator on public.patient_reminders;
create trigger patient_reminders_stamp_creator
  before insert on public.patient_reminders
  for each row execute function public.stamp_reminder_creator();

grant select, insert, update, delete on public.patient_reminders to authenticated;
revoke execute on function public.stamp_reminder_done() from public, anon, authenticated;
revoke execute on function public.stamp_reminder_creator() from public, anon, authenticated;

alter publication supabase_realtime add table public.patient_reminders;

-- Transfers now carry reminders along with notes.
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

  perform public._patient_event_note(p_patient, p_target_ward, 'Transfer',
    'Transferred from ' || coalesce(v_from_name, v_from) || ' to ' || v_to_name ||
    coalesce('. Reason: ' || v_reason, '.'));
end;
$$;
