-- Observations (vital signs) and the early-warning score behind the
-- status dot on paediatric and adult wards.
--
-- One row per set of observations. Every vital sign is optional; the app
-- works out the score (NEWS2 for 16 years and over, Brighton PEWS for
-- children) — see lib/clinical/early_warning.dart. PEWS behaviour /
-- cardiovascular / respiratory are scored by staff from the chart
-- descriptions (0–3 each), because the "normal for age" bands differ
-- between hospitals.
--
-- Rows belong to the patient's ward (members read/write), the recorder is
-- stamped server-side, and rows follow the patient on transfer.

create table if not exists public.observations (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  taken_at         timestamptz not null,
  resp_rate        smallint check (resp_rate between 0 and 150),
  spo2             smallint check (spo2 between 40 and 100),
  spo2_scale2      boolean not null default false,  -- NEWS2 target 88–92%
  on_oxygen        boolean,
  oxygen_lpm       numeric(4,1) check (oxygen_lpm between 0 and 60),
  heart_rate       smallint check (heart_rate between 0 and 300),
  systolic_bp      smallint check (systolic_bp between 20 and 300),
  diastolic_bp     smallint check (diastolic_bp between 10 and 250),
  temp_c           numeric(3,1) check (temp_c between 25 and 45),
  consciousness    text check (consciousness in ('A', 'C', 'V', 'P', 'U')),
  pews_behaviour   smallint check (pews_behaviour between 0 and 3),
  pews_cardio      smallint check (pews_cardio between 0 and 3),
  pews_resp        smallint check (pews_resp between 0 and 3),
  pews_extra       boolean not null default false,  -- ¼-hourly nebs / persistent vomiting
  note             text check (note is null or length(note) <= 300),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now()
);
create index if not exists observations_patient_idx
  on public.observations (patient_id, taken_at);

alter table public.observations enable row level security;
drop policy if exists observations_ward on public.observations;
create policy observations_ward on public.observations for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (public.is_ward_member(ward_id)
              and ward_id = public.patient_ward(patient_id));
grant select, insert, update, delete on public.observations to authenticated;

drop trigger if exists observations_stamp on public.observations;
create trigger observations_stamp before insert on public.observations
  for each row execute function public.stamp_row_creator();

do $$ begin
  alter publication supabase_realtime add table public.observations;
exception when duplicate_object then null; end $$;

-- Observations follow the patient to a new ward, like the newborn rows.
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
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;
