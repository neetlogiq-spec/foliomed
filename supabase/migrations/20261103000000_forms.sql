-- Quick forms.
--
-- * form_templates: a ward's own forms (built-in ones ship with the app; a
--   ward form with a built-in's key replaces it on that ward). Any doctor
--   of the ward, or its owner, creates and edits them; every save bumps the
--   version. The definition is JSON (sections → fields), see
--   lib/forms/form_model.dart.
-- * patient_forms: a filled form, with a copy of the definition it was
--   filled with (so old records show exactly what was asked), the answers
--   and the summary the app wrote. save_patient_form() adds it, writes the
--   summary as a Form note on the timeline, and records any vital signs as
--   an observation (and a weight, in the newborn weight range).

create table if not exists public.form_templates (
  id               uuid primary key default gen_random_uuid(),
  ward_id          text not null references public.wards (id) on delete cascade,
  key              text not null check (key ~ '^[a-z0-9_]{1,40}$'),
  name             text not null check (length(name) between 1 and 60),
  description      text not null default '' check (length(description) <= 120),
  version          integer not null default 1 check (version >= 1),
  definition       jsonb not null check (octet_length(definition::text) <= 60000),
  based_on         text check (based_on is null or based_on ~ '^[a-z0-9_]{1,40}$'),
  archived         boolean not null default false,
  updated_by_name  text,
  updated_at       timestamptz not null default now(),
  unique (ward_id, key)
);

create table if not exists public.patient_forms (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  template_key     text not null check (template_key ~ '^[a-z0-9_]{1,40}$'),
  template_name    text not null check (length(template_name) between 1 and 60),
  template_version integer not null default 1,
  definition       jsonb not null check (octet_length(definition::text) <= 60000),
  answers          jsonb not null check (octet_length(answers::text) <= 60000),
  summary          text not null check (length(summary) <= 4000),
  abnormal_count   integer not null default 0 check (abnormal_count >= 0),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now()
);
create index if not exists patient_forms_patient_idx on public.patient_forms (patient_id, created_at desc);

do $$
declare t text;
begin
  foreach t in array array['form_templates', 'patient_forms'] loop
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

-- Doctors of the ward (or its owner) create and edit forms. Returns the
-- new version.
create or replace function public.save_form_template(
  p_ward text, p_key text, p_name text, p_description text, p_definition jsonb,
  p_based_on text default null, p_archived boolean default false)
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_role text;
  v_name text;
  v_version integer;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select role, name into v_role, v_name from public.profiles where id = auth.uid();
  if not (public._is_ward_owner(p_ward) or (public.is_ward_member(p_ward) and v_role = 'doctor')) then
    raise exception 'only the ward''s doctors can change forms' using errcode = '42501';
  end if;
  if jsonb_typeof(p_definition -> 'sections') is distinct from 'array' then
    raise exception 'a form needs sections' using errcode = '22023';
  end if;
  insert into public.form_templates as t (ward_id, key, name, description, definition, based_on, archived,
                                          updated_by_name, updated_at)
  values (p_ward, p_key, trim(p_name), trim(coalesce(p_description, '')), p_definition, nullif(p_based_on, ''),
          coalesce(p_archived, false), v_name, now())
  on conflict (ward_id, key) do update
    set name = excluded.name,
        description = excluded.description,
        definition = excluded.definition,
        archived = excluded.archived,
        version = t.version + case when t.definition is distinct from excluded.definition then 1 else 0 end,
        updated_by_name = excluded.updated_by_name,
        updated_at = now()
  returning version into v_version;
  return v_version;
end;
$$;
revoke execute on function public.save_form_template(text, text, text, text, jsonb, text, boolean) from public, anon;
grant execute on function public.save_form_template(text, text, text, text, jsonb, text, boolean) to authenticated;

-- A number from the vitals JSON, or null when missing or out of [lo, hi].
create or replace function public._vital(p_vitals jsonb, p_key text, lo numeric, hi numeric)
returns numeric
language sql immutable
as $$
  select case when jsonb_typeof(p_vitals -> p_key) = 'number'
               and (p_vitals ->> p_key)::numeric between lo and hi
              then (p_vitals ->> p_key)::numeric end;
$$;
revoke execute on function public._vital(jsonb, text, numeric, numeric) from public, anon, authenticated;

create or replace function public.save_patient_form(
  p_patient uuid, p_key text, p_name text, p_version integer, p_definition jsonb, p_answers jsonb,
  p_summary text, p_abnormal integer default 0, p_vitals jsonb default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, false);
  v_name text := public._my_name();
  v_id uuid;
  v_v jsonb := coalesce(p_vitals, '{}'::jsonb);
  v_rr numeric := public._vital(v_v, 'rr', 0, 150);
  v_spo2 numeric := public._vital(v_v, 'spo2', 40, 100);
  v_hr numeric := public._vital(v_v, 'hr', 0, 300);
  v_sbp numeric := public._vital(v_v, 'sbp', 20, 300);
  v_dbp numeric := public._vital(v_v, 'dbp', 10, 250);
  v_temp numeric := public._vital(v_v, 'temp', 25, 45);
  v_wt numeric := public._vital(v_v, 'weight', 0.3, 8);
begin
  insert into public.patient_forms (patient_id, ward_id, template_key, template_name, template_version, definition,
                                    answers, summary, abnormal_count, created_by, created_by_name)
  values (p_patient, v_ward, p_key, trim(p_name), coalesce(p_version, 1), p_definition, p_answers, trim(p_summary),
          greatest(coalesce(p_abnormal, 0), 0), auth.uid(), v_name)
  returning id into v_id;
  perform public._patient_event_note(p_patient, v_ward, 'Form', trim(p_summary));
  if coalesce(v_rr, v_spo2, v_hr, v_sbp, v_dbp, v_temp) is not null then
    insert into public.observations (patient_id, ward_id, taken_at, resp_rate, spo2, heart_rate, systolic_bp,
                                     diastolic_bp, temp_c, note)
    values (p_patient, v_ward, now(), round(v_rr), round(v_spo2), round(v_hr), round(v_sbp), round(v_dbp),
            round(v_temp, 1), left(trim(p_name), 300));
  end if;
  if v_wt is not null then
    insert into public.weights (patient_id, ward_id, measured_at, grams) values (p_patient, v_ward, now(), round(v_wt * 1000));
  end if;
  return v_id;
end;
$$;
revoke execute on function public.save_patient_form(uuid, text, text, integer, jsonb, jsonb, text, integer, jsonb)
  from public, anon;
grant execute on function public.save_patient_form(uuid, text, text, integer, jsonb, jsonb, text, integer, jsonb)
  to authenticated;

-- Filled forms follow the patient on transfer.
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
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;
