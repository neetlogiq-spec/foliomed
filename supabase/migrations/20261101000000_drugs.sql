-- Emergency and infusion drugs: each ward's own settings and sign-off, and
-- the infusions running on a patient.
--
-- * ward_drug_settings: one row per ward and drug (keys from the app's
--   starter list, lib/tools/drugs/drug_list.dart). The ward owner sets the
--   vial strength, the standard mixture (dose at 1 mL/h), a unit note, or
--   hides the drug. A doctor of the ward (or the owner) signs a drug off;
--   the app sends a signature of the dose content it showed, so a later
--   change to the list or the ward's settings shows as "not checked" again.
--   Changing the vial or mixture clears the sign-off here as well.
-- * patient_infusions: started, changed and stopped through RPCs only, each
--   writing an Infusion note on the timeline. Rows follow the patient on
--   transfer and stop when the patient is discharged.

create table if not exists public.ward_drug_settings (
  ward_id           text not null references public.wards (id) on delete cascade,
  drug_key          text not null check (drug_key ~ '^[a-z0-9_]{1,40}$'),
  vial_per_ml       numeric check (vial_per_ml > 0 and vial_per_ml <= 100000),
  mix_at_1ml_h      numeric check (mix_at_1ml_h > 0 and mix_at_1ml_h <= 100000),
  hidden            boolean not null default false,
  unit_note         text check (unit_note is null or length(unit_note) <= 300),
  checked_signature text check (checked_signature is null or length(checked_signature) <= 64),
  checked_by        uuid references public.profiles (id) on delete set null,
  checked_by_name   text,
  checked_at        timestamptz,
  updated_by_name   text,
  updated_at        timestamptz not null default now(),
  primary key (ward_id, drug_key)
);

alter table public.ward_drug_settings enable row level security;
drop policy if exists ward_drug_settings_read on public.ward_drug_settings;
create policy ward_drug_settings_read on public.ward_drug_settings for select to authenticated
  using (public.is_ward_member(ward_id));
revoke insert, update, delete on public.ward_drug_settings from authenticated;
grant select on public.ward_drug_settings to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.ward_drug_settings;
exception when duplicate_object then null; end $$;

create or replace function public._is_ward_owner(p_ward text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.wards where id = p_ward and creator_id = auth.uid());
$$;
revoke execute on function public._is_ward_owner(text) from public, anon, authenticated;

-- Owner only. Null vial/mixture = the app's default. A changed vial or
-- mixture clears the sign-off.
create or replace function public.set_ward_drug(
  p_ward text, p_key text, p_vial numeric, p_mix numeric,
  p_hidden boolean default false, p_note text default null)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_name text;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public._is_ward_owner(p_ward) then
    raise exception 'only the ward owner can change the drug list' using errcode = '42501';
  end if;
  select name into v_name from public.profiles where id = auth.uid();
  insert into public.ward_drug_settings as s
    (ward_id, drug_key, vial_per_ml, mix_at_1ml_h, hidden, unit_note, updated_by_name, updated_at)
  values (p_ward, p_key, p_vial, p_mix, coalesce(p_hidden, false), v_note, v_name, now())
  on conflict (ward_id, drug_key) do update
    set vial_per_ml = excluded.vial_per_ml,
        mix_at_1ml_h = excluded.mix_at_1ml_h,
        hidden = excluded.hidden,
        unit_note = excluded.unit_note,
        updated_by_name = excluded.updated_by_name,
        updated_at = now(),
        checked_signature = case
          when s.vial_per_ml is distinct from excluded.vial_per_ml
            or s.mix_at_1ml_h is distinct from excluded.mix_at_1ml_h then null
          else s.checked_signature end,
        checked_by = case
          when s.vial_per_ml is distinct from excluded.vial_per_ml
            or s.mix_at_1ml_h is distinct from excluded.mix_at_1ml_h then null
          else s.checked_by end,
        checked_by_name = case
          when s.vial_per_ml is distinct from excluded.vial_per_ml
            or s.mix_at_1ml_h is distinct from excluded.mix_at_1ml_h then null
          else s.checked_by_name end,
        checked_at = case
          when s.vial_per_ml is distinct from excluded.vial_per_ml
            or s.mix_at_1ml_h is distinct from excluded.mix_at_1ml_h then null
          else s.checked_at end;
end;
$$;
revoke execute on function public.set_ward_drug(text, text, numeric, numeric, boolean, text) from public, anon;
grant execute on function public.set_ward_drug(text, text, numeric, numeric, boolean, text) to authenticated;

-- A doctor of the ward, or its owner, signs off what the app showed
-- (p_signature); null clears the sign-off.
create or replace function public.check_ward_drug(p_ward text, p_key text, p_signature text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_name text;
  v_role text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select name, role into v_name, v_role from public.profiles where id = auth.uid();
  if not (public._is_ward_owner(p_ward) or (public.is_ward_member(p_ward) and v_role = 'doctor')) then
    raise exception 'only the ward''s doctors can sign off drugs' using errcode = '42501';
  end if;
  insert into public.ward_drug_settings as s (ward_id, drug_key, checked_signature, checked_by,
                                              checked_by_name, checked_at, updated_at)
  values (p_ward, p_key, p_signature,
          case when p_signature is null then null else auth.uid() end,
          case when p_signature is null then null else v_name end,
          case when p_signature is null then null else now() end, now())
  on conflict (ward_id, drug_key) do update
    set checked_signature = excluded.checked_signature,
        checked_by = excluded.checked_by,
        checked_by_name = excluded.checked_by_name,
        checked_at = excluded.checked_at;
end;
$$;
revoke execute on function public.check_ward_drug(text, text, text) from public, anon;
grant execute on function public.check_ward_drug(text, text, text) to authenticated;

-- ── Running infusions ────────────────────────────────────────────────
create table if not exists public.patient_infusions (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  drug_key         text check (drug_key is null or drug_key ~ '^[a-z0-9_]{1,40}$'),
  drug_name        text not null check (length(drug_name) between 1 and 60),
  dose             numeric not null check (dose >= 0),
  dose_unit        text not null check (length(dose_unit) between 1 and 20),
  rate_ml_h        numeric not null check (rate_ml_h >= 0 and rate_ml_h <= 1000),
  concentration    numeric not null check (concentration > 0),
  conc_unit        text not null check (length(conc_unit) between 1 and 20),
  syringe          text not null default '' check (length(syringe) <= 120),
  weight_kg        numeric check (weight_kg > 0 and weight_kg <= 300),
  started_at       timestamptz not null default now(),
  started_by       uuid references public.profiles (id) on delete set null,
  started_by_name  text,
  changed_at       timestamptz,
  changed_by_name  text,
  stopped_at       timestamptz,
  stopped_by_name  text
);
create index if not exists patient_infusions_patient_idx
  on public.patient_infusions (patient_id, started_at desc);
create index if not exists patient_infusions_ward_idx
  on public.patient_infusions (ward_id) where stopped_at is null;

alter table public.patient_infusions enable row level security;
drop policy if exists patient_infusions_read on public.patient_infusions;
create policy patient_infusions_read on public.patient_infusions for select to authenticated
  using (public.is_ward_member(ward_id));
revoke insert, update, delete on public.patient_infusions from authenticated;
grant select on public.patient_infusions to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.patient_infusions;
exception when duplicate_object then null; end $$;

create or replace function public._infusion_num(p numeric)
returns text
language sql immutable
as $$ select trim_scale(round(p, 3))::text; $$;

-- "10 mcg/kg/min (1.0 mL/h)"
create or replace function public._infusion_dose(p_dose numeric, p_unit text, p_rate numeric)
returns text
language sql immutable
as $$
  select public._infusion_num(p_dose) || ' ' || p_unit || ' (' || to_char(round(p_rate, 1), 'FM99990.0') || ' mL/h)';
$$;
revoke execute on function public._infusion_num(numeric) from public, anon, authenticated;
revoke execute on function public._infusion_dose(numeric, text, numeric) from public, anon, authenticated;

create or replace function public._infusion_patient_ward(p_patient uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_active boolean;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, is_active into v_ward, v_active from public.patients where id = p_patient;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if not v_active then raise exception 'patient is discharged' using errcode = '22023'; end if;
  return v_ward;
end;
$$;
revoke execute on function public._infusion_patient_ward(uuid) from public, anon, authenticated;

create or replace function public.start_infusion(
  p_patient uuid, p_drug_key text, p_drug_name text, p_dose numeric, p_dose_unit text,
  p_rate numeric, p_concentration numeric, p_conc_unit text, p_syringe text default '',
  p_weight numeric default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._infusion_patient_ward(p_patient);
  v_name text;
  v_id uuid;
  v_syringe text := trim(coalesce(p_syringe, ''));
begin
  select name into v_name from public.profiles where id = auth.uid();
  insert into public.patient_infusions (patient_id, ward_id, drug_key, drug_name, dose, dose_unit,
    rate_ml_h, concentration, conc_unit, syringe, weight_kg, started_by, started_by_name)
  values (p_patient, v_ward, nullif(p_drug_key, ''), trim(p_drug_name), p_dose, p_dose_unit,
    p_rate, p_concentration, p_conc_unit, v_syringe, p_weight, auth.uid(), v_name)
  returning id into v_id;
  perform public._patient_event_note(p_patient, v_ward, 'Infusion',
    'Started ' || trim(p_drug_name) || ' ' || public._infusion_dose(p_dose, p_dose_unit, p_rate)
    || case when v_syringe = '' then '' else ' — ' || v_syringe end || '.');
  return v_id;
end;
$$;
revoke execute on function public.start_infusion(uuid, text, text, numeric, text, numeric, numeric, text, text, numeric)
  from public, anon;
grant execute on function public.start_infusion(uuid, text, text, numeric, text, numeric, numeric, text, text, numeric)
  to authenticated;

create or replace function public.change_infusion(p_id uuid, p_dose numeric, p_rate numeric)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.patient_infusions;
  v_ward text;
  v_name text;
begin
  select * into v_row from public.patient_infusions where id = p_id for update;
  if v_row.id is null then raise exception 'no such infusion' using errcode = 'P0002'; end if;
  v_ward := public._infusion_patient_ward(v_row.patient_id);
  if v_row.stopped_at is not null then raise exception 'infusion already stopped' using errcode = '22023'; end if;
  if p_dose < 0 or p_rate < 0 then raise exception 'dose and rate must not be negative' using errcode = '22023'; end if;
  select name into v_name from public.profiles where id = auth.uid();
  update public.patient_infusions
     set dose = p_dose, rate_ml_h = p_rate, changed_at = now(), changed_by_name = v_name
   where id = p_id;
  perform public._patient_event_note(v_row.patient_id, v_ward, 'Infusion',
    v_row.drug_name || ' changed from ' || public._infusion_num(v_row.dose) || ' to '
    || public._infusion_dose(p_dose, v_row.dose_unit, p_rate) || '.');
end;
$$;
revoke execute on function public.change_infusion(uuid, numeric, numeric) from public, anon;
grant execute on function public.change_infusion(uuid, numeric, numeric) to authenticated;

create or replace function public.stop_infusion(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.patient_infusions;
  v_ward text;
  v_name text;
begin
  select * into v_row from public.patient_infusions where id = p_id for update;
  if v_row.id is null then raise exception 'no such infusion' using errcode = 'P0002'; end if;
  if v_row.stopped_at is not null then return; end if;
  select ward_id into v_ward from public.patients where id = v_row.patient_id;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  select name into v_name from public.profiles where id = auth.uid();
  update public.patient_infusions set stopped_at = now(), stopped_by_name = v_name where id = p_id;
  perform public._patient_event_note(v_row.patient_id, v_ward, 'Infusion',
    'Stopped ' || v_row.drug_name || '.');
end;
$$;
revoke execute on function public.stop_infusion(uuid) from public, anon;
grant execute on function public.stop_infusion(uuid) to authenticated;

-- Infusions follow the patient to a new ward.
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
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;

-- (is_active is set from status by a BEFORE trigger, so watch status.)
create or replace function public.patients_stop_infusions()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not new.is_active then
    update public.patient_infusions set stopped_at = now(), stopped_by_name = 'Discharge'
     where patient_id = new.id and stopped_at is null;
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_stop_infusions() from public, anon, authenticated;

drop trigger if exists patients_stop_infusions on public.patients;
create trigger patients_stop_infusions
  after update of status on public.patients
  for each row execute function public.patients_stop_infusions();
