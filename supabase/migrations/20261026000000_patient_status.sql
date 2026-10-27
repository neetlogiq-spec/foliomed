-- Patient status dots (green / amber / red on the Patients board).
--
-- * wards.kind picks which automatic rules the app applies (newborn
--   bilirubin and weight for PNC/NICU, support tags for PICU, …). 'other'
--   means "follow the patient's age". Owner-only, like the rest of wards.
-- * patients.acuity is the status staff set by hand: stable / watch / sick
--   (null = not set), with an optional one-line reason. Who set it and
--   when are stamped by the server; the app greys a status that hasn't
--   been reviewed in 12 h (PICU) or 24 h (other wards).
-- * patients.support_tags: PICU organ support (ventilated, inotropes, …).
--
-- Changes go through set_patient_status(), which also logs a Status note
-- on the timeline. Re-saving the same status counts as a review.

alter table public.wards
  add column if not exists kind text not null default 'other';

do $$ begin
  alter table public.wards add constraint wards_kind_check
    check (kind in ('pnc', 'nicu', 'picu', 'paeds', 'adult', 'other'));
exception when duplicate_object then null; end $$;

alter table public.patients
  add column if not exists acuity             text,
  add column if not exists acuity_reason      text,
  add column if not exists acuity_set_at      timestamptz,
  add column if not exists acuity_set_by      uuid references public.profiles (id) on delete set null,
  add column if not exists acuity_set_by_name text,
  add column if not exists support_tags       text[] not null default '{}';

do $$ begin
  alter table public.patients add constraint patients_acuity_check
    check (acuity is null or acuity in ('stable', 'watch', 'sick'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.patients add constraint patients_acuity_reason_check
    check (acuity_reason is null or length(acuity_reason) <= 200);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.patients add constraint patients_support_tags_check
    check (support_tags <@ array['ventilated', 'niv', 'inotropes', 'centralLine',
                                 'crrt', 'sedation']::text[]);
exception when duplicate_object then null; end $$;

-- Whoever writes the status, the server decides who and when.
create or replace function public.stamp_patient_status()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.acuity is null and cardinality(new.support_tags) = 0 then
      new.acuity_set_at := null;
      new.acuity_set_by := null;
      new.acuity_set_by_name := null;
      return new;
    end if;
  elsif new.acuity is not distinct from old.acuity
    and new.acuity_reason is not distinct from old.acuity_reason
    and new.support_tags is not distinct from old.support_tags
    and new.acuity_set_at is not distinct from old.acuity_set_at then
    -- Status untouched: keep the stamps as they were.
    new.acuity_set_by := old.acuity_set_by;
    new.acuity_set_by_name := old.acuity_set_by_name;
    return new;
  end if;
  new.acuity_reason := nullif(trim(coalesce(new.acuity_reason, '')), '');
  new.acuity_set_at := now();
  new.acuity_set_by := auth.uid();
  select name into new.acuity_set_by_name from public.profiles where id = auth.uid();
  return new;
end;
$$;

drop trigger if exists patients_stamp_status on public.patients;
create trigger patients_stamp_status
  before insert or update on public.patients
  for each row execute function public.stamp_patient_status();

revoke execute on function public.stamp_patient_status() from public, anon, authenticated;

create or replace function public._support_tag_label(p_tag text)
returns text
language sql immutable
as $$
  select case p_tag
    when 'ventilated'  then 'Ventilated'
    when 'niv'         then 'NIV / HFNC'
    when 'inotropes'   then 'Inotropes'
    when 'centralLine' then 'Central line'
    when 'crrt'        then 'CRRT'
    when 'sedation'    then 'Sedation'
    else p_tag end;
$$;

-- Sets (or reviews, or clears with p_acuity null) the patient's status
-- and support tags, and logs it on the timeline.
create or replace function public.set_patient_status(
  p_patient uuid, p_acuity text, p_reason text default null,
  p_tags text[] default '{}')
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_active boolean;
  v_old text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_tags text[] := coalesce(p_tags, '{}');
  v_label text;
  v_text text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, is_active, acuity into v_ward, v_active, v_old
    from public.patients where id = p_patient for update;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if not v_active then
    raise exception 'patient is discharged' using errcode = '22023';
  end if;

  update public.patients
     set acuity = p_acuity,
         acuity_reason = v_reason,
         support_tags = v_tags,
         acuity_set_at = clock_timestamp()  -- always "changed", so the trigger stamps
   where id = p_patient;

  v_label := case p_acuity when 'stable' then 'Stable' when 'watch' then 'Watch'
                           when 'sick' then 'Sick' end;
  v_text := case
    when p_acuity is null then 'Status cleared'
    when p_acuity is not distinct from v_old then 'Status reviewed: ' || v_label
    else 'Status: ' || v_label end
    || coalesce(' — ' || v_reason, '') || '.';
  if cardinality(v_tags) > 0 then
    v_text := v_text || ' Support: ' ||
      (select string_agg(public._support_tag_label(t), ', ') from unnest(v_tags) t) || '.';
  end if;
  perform public._patient_event_note(p_patient, v_ward, 'Status', v_text);
end;
$$;

revoke execute on function public.set_patient_status(uuid, text, text, text[]) from public, anon;
grant execute on function public.set_patient_status(uuid, text, text, text[]) to authenticated;
