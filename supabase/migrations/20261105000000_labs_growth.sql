-- Lab results and growth measurements.
--
-- * lab_results: one row per test result (number or text, e.g. a culture),
--   with the report's reference range when known and the app's flag.
--   Added in batches by add_lab_results(), which stamps who and writes one
--   Investigation note on the timeline. Ward members can delete a result
--   entered in error.
-- * patient_measurements: length / height and head circumference, for the
--   WHO growth charts (weights stay in public.weights).
-- Both follow the patient on transfer.

create table if not exists public.lab_results (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  test_key         text not null check (test_key ~ '^[a-z0-9_]{1,40}$'),
  test_name        text not null check (length(test_name) between 1 and 60),
  value            numeric check (value between -1000000 and 1000000),
  value_text       text check (value_text is null or length(value_text) <= 200),
  unit             text not null default '' check (length(unit) <= 20),
  ref_low          numeric,
  ref_high         numeric,
  flag             text check (flag is null or flag in ('low', 'high', 'criticalLow', 'criticalHigh')),
  sampled_at       timestamptz not null,
  source           text not null default 'manual' check (source in ('manual', 'scan')),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now(),
  check (value is not null or value_text is not null)
);
create index if not exists lab_results_patient_idx on public.lab_results (patient_id, test_key, sampled_at);

alter table public.lab_results enable row level security;
drop policy if exists lab_results_read on public.lab_results;
create policy lab_results_read on public.lab_results for select to authenticated
  using (public.is_ward_member(ward_id));
drop policy if exists lab_results_delete on public.lab_results;
create policy lab_results_delete on public.lab_results for delete to authenticated
  using (public.is_ward_member(ward_id));
revoke insert, update on public.lab_results from authenticated;
grant select, delete on public.lab_results to authenticated;

create table if not exists public.patient_measurements (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  measured_at      timestamptz not null,
  length_cm        numeric(5,1) check (length_cm between 20 and 250),
  head_cm          numeric(4,1) check (head_cm between 15 and 70),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now(),
  check (length_cm is not null or head_cm is not null)
);
create index if not exists patient_measurements_patient_idx on public.patient_measurements (patient_id, measured_at);

alter table public.patient_measurements enable row level security;
drop policy if exists patient_measurements_ward on public.patient_measurements;
create policy patient_measurements_ward on public.patient_measurements for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (public.is_ward_member(ward_id) and ward_id = public.patient_ward(patient_id));
grant select, insert, delete on public.patient_measurements to authenticated;

drop trigger if exists patient_measurements_stamp on public.patient_measurements;
create trigger patient_measurements_stamp before insert on public.patient_measurements
  for each row execute function public.stamp_row_creator();

do $$
declare t text;
begin
  foreach t in array array['lab_results', 'patient_measurements'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- Adds a batch of results sampled together. p_results is an array of
-- {test_key, test_name, value | value_text, unit, ref_low, ref_high, flag};
-- p_summary is the app's one-line note for the timeline.
create or replace function public.add_lab_results(
  p_patient uuid, p_sampled_at timestamptz, p_results jsonb, p_summary text, p_source text default 'manual')
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, false);
  v_name text := public._my_name();
  v_count integer;
begin
  if jsonb_typeof(p_results) is distinct from 'array' or jsonb_array_length(p_results) = 0 then
    raise exception 'no results to add' using errcode = '22023';
  end if;
  if jsonb_array_length(p_results) > 80 then
    raise exception 'too many results at once' using errcode = '22023';
  end if;
  insert into public.lab_results (patient_id, ward_id, test_key, test_name, value, value_text, unit, ref_low, ref_high,
                                  flag, sampled_at, source, created_by, created_by_name)
  select p_patient, v_ward, r ->> 'test_key', r ->> 'test_name',
         (r ->> 'value')::numeric, nullif(trim(r ->> 'value_text'), ''), coalesce(r ->> 'unit', ''),
         (r ->> 'ref_low')::numeric, (r ->> 'ref_high')::numeric, nullif(r ->> 'flag', ''),
         coalesce(p_sampled_at, now()), coalesce(p_source, 'manual'), auth.uid(), v_name
    from jsonb_array_elements(p_results) r;
  get diagnostics v_count = row_count;
  perform public._patient_event_note(p_patient, v_ward, 'Investigation', left(trim(p_summary), 2000));
  return v_count;
end;
$$;
revoke execute on function public.add_lab_results(uuid, timestamptz, jsonb, text, text) from public, anon;
grant execute on function public.add_lab_results(uuid, timestamptz, jsonb, text, text) to authenticated;

-- Follow the patient on transfer.
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
    update public.patient_forms set ward_id = new.ward_id where patient_id = new.id;
    update public.lab_results set ward_id = new.ward_id where patient_id = new.id;
    update public.patient_measurements set ward_id = new.ward_id where patient_id = new.id;
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;
