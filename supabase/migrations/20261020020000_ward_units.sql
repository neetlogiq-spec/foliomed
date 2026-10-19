-- Units (consultant teams) inside a ward: "PNC → Unit A, Unit B".
-- A unit is a label for organising and counting, not a permission
-- boundary — every ward member still sees every unit's patients.
-- The ward owner manages the list; any member can move a patient between
-- units (logged on the timeline). Transferring to another ward clears it.

create table if not exists public.ward_units (
  id          uuid primary key default gen_random_uuid(),
  ward_id     text not null references public.wards (id) on delete cascade,
  name        text not null check (length(trim(name)) between 1 and 40),
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

create unique index if not exists ward_units_name_uniq
  on public.ward_units (ward_id, lower(trim(name)));

alter table public.ward_units enable row level security;

create or replace function public.is_ward_owner(p_ward text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.wards
                  where id = p_ward and creator_id = auth.uid())
$$;
revoke execute on function public.is_ward_owner(text) from public, anon;
grant execute on function public.is_ward_owner(text) to authenticated;

drop policy if exists ward_units_read on public.ward_units;
create policy ward_units_read on public.ward_units
  for select to authenticated using (public.is_ward_member(ward_id));

drop policy if exists ward_units_owner_write on public.ward_units;
create policy ward_units_owner_write on public.ward_units
  for all to authenticated
  using (public.is_ward_owner(ward_id))
  with check (public.is_ward_owner(ward_id));

grant select, insert, update, delete on public.ward_units to authenticated;
alter publication supabase_realtime add table public.ward_units;

alter table public.patients
  add column if not exists unit_id uuid references public.ward_units (id) on delete set null;

create index if not exists patients_unit_idx on public.patients (unit_id);

-- A patient's unit must belong to the patient's ward. A ward transfer
-- drops a unit from the old ward instead of failing.
create or replace function public.guard_patient_unit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_unit_ward text;
begin
  if new.unit_id is null then return new; end if;
  select ward_id into v_unit_ward from public.ward_units where id = new.unit_id;
  if v_unit_ward is distinct from new.ward_id then
    if tg_op = 'UPDATE' and new.ward_id is distinct from old.ward_id then
      new.unit_id := null;
    else
      raise exception 'unit belongs to another ward' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists patients_guard_unit on public.patients;
create trigger patients_guard_unit
  before insert or update of unit_id, ward_id on public.patients
  for each row execute function public.guard_patient_unit();

revoke execute on function public.guard_patient_unit() from public, anon, authenticated;

-- Move a patient to a unit (null = unassigned), with a timeline line.
create or replace function public.move_patient_unit(p_patient uuid, p_unit uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_old uuid;
  v_old_name text;
  v_new_name text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, unit_id into v_ward, v_old
    from public.patients where id = p_patient for update;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if p_unit is not distinct from v_old then return; end if;
  if p_unit is not null then
    select name into v_new_name from public.ward_units
     where id = p_unit and ward_id = v_ward;
    if v_new_name is null then
      raise exception 'no such unit in this ward' using errcode = 'P0002';
    end if;
  end if;
  select name into v_old_name from public.ward_units where id = v_old;

  update public.patients set unit_id = p_unit where id = p_patient;
  perform public._patient_event_note(p_patient, v_ward, 'Transfer',
    'Moved from ' || coalesce(v_old_name, 'no unit') || ' to ' ||
    coalesce(v_new_name, 'no unit') || '.');
end;
$$;

revoke execute on function public.move_patient_unit(uuid, uuid) from public, anon;
grant execute on function public.move_patient_unit(uuid, uuid) to authenticated;
