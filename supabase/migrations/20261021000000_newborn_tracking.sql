-- Newborn tracking: bilirubin readings (for the trend chart), phototherapy
-- sessions, daily weights, and mother details on the baby's record.
-- Rows belong to the patient's ward (members read/write); creators are
-- stamped server-side; child rows follow the patient on transfer.

alter table public.patients
  add column if not exists mother_name   text,
  add column if not exists mother_age    smallint,
  add column if not exists gravida_para  text;

do $$ begin
  alter table public.patients add constraint patients_mother_check check (
    (mother_name is null or length(mother_name) <= 80)
    and (mother_age is null or mother_age between 12 and 60)
    and (gravida_para is null or length(gravida_para) <= 20));
exception when duplicate_object then null; end $$;

create index if not exists patients_mother_name_idx
  on public.patients (lower(mother_name)) where mother_name is not null;

-- ── Tables ─────────────────────────────────────────────────────────────
create table if not exists public.bilirubin_readings (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  measured_at      timestamptz not null,
  value            numeric(6,1) not null check (value > 0 and value < 1000),
  unit             text not null check (unit in ('mgdl', 'umol')),
  method           text not null default 'serum' check (method in ('serum', 'transcutaneous')),
  screen_id        uuid references public.newborn_screens (id) on delete cascade,
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now()
);
create index if not exists bilirubin_readings_patient_idx
  on public.bilirubin_readings (patient_id, measured_at);
create unique index if not exists bilirubin_readings_screen_uniq
  on public.bilirubin_readings (screen_id) where screen_id is not null;

create table if not exists public.phototherapy_sessions (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  kind             text not null default 'single'
                     check (kind in ('single', 'double', 'intensive')),
  started_at       timestamptz not null,
  stopped_at       timestamptz,
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now(),
  check (stopped_at is null or stopped_at >= started_at)
);
create index if not exists phototherapy_patient_idx
  on public.phototherapy_sessions (patient_id, started_at);
-- At most one running session per baby.
create unique index if not exists phototherapy_one_open
  on public.phototherapy_sessions (patient_id) where stopped_at is null;

create table if not exists public.weights (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.patients (id) on delete cascade,
  ward_id          text not null references public.wards (id) on delete cascade,
  measured_at      timestamptz not null,
  grams            integer not null check (grams between 300 and 8000),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now()
);
create index if not exists weights_patient_idx on public.weights (patient_id, measured_at);

-- ── RLS, stamping, realtime ───────────────────────────────────────────
create or replace function public.stamp_row_creator()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.created_by := auth.uid();
  select name into new.created_by_name from public.profiles where id = auth.uid();
  return new;
end;
$$;
revoke execute on function public.stamp_row_creator() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['bilirubin_readings', 'phototherapy_sessions', 'weights'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_ward', t);
    execute format($p$create policy %I on public.%I for all to authenticated
                     using (public.is_ward_member(ward_id))
                     with check (public.is_ward_member(ward_id)
                                 and ward_id = public.patient_ward(patient_id))$p$,
                   t || '_ward', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop trigger if exists %I on public.%I', t || '_stamp', t);
    execute format('create trigger %I before insert on public.%I
                    for each row execute function public.stamp_row_creator()', t || '_stamp', t);
    execute format('alter publication supabase_realtime add table public.%I', t);
  end loop;
end $$;

-- Phototherapy start/stop goes on the timeline so the whole ward sees it.
create or replace function public.phototherapy_timeline()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public._patient_event_note(new.patient_id, new.ward_id, 'Phototherapy',
      initcap(new.kind) || ' phototherapy started.');
  elsif new.stopped_at is not null and old.stopped_at is null then
    perform public._patient_event_note(new.patient_id, new.ward_id, 'Phototherapy',
      'Phototherapy stopped after ' ||
      round(extract(epoch from (new.stopped_at - new.started_at)) / 3600.0, 1) || ' h.');
  end if;
  return new;
end;
$$;
revoke execute on function public.phototherapy_timeline() from public, anon, authenticated;

drop trigger if exists phototherapy_sessions_timeline on public.phototherapy_sessions;
create trigger phototherapy_sessions_timeline
  after insert or update of stopped_at on public.phototherapy_sessions
  for each row execute function public.phototherapy_timeline();

-- Child rows follow the patient to a new ward (any path that moves it).
create or replace function public.patients_cascade_ward()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.ward_id is distinct from old.ward_id then
    update public.bilirubin_readings set ward_id = new.ward_id where patient_id = new.id;
    update public.phototherapy_sessions set ward_id = new.ward_id where patient_id = new.id;
    update public.weights set ward_id = new.ward_id where patient_id = new.id;
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_cascade_ward() from public, anon, authenticated;

drop trigger if exists patients_cascade_ward on public.patients;
create trigger patients_cascade_ward
  after update of ward_id on public.patients
  for each row execute function public.patients_cascade_ward();

-- ── Results also feed the bilirubin chart ─────────────────────────────
create or replace function public.save_newborn_results(
  p_screen uuid, p_results jsonb, p_summary text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
  v_summary text := nullif(trim(coalesce(p_summary, '')), '');
  v_tsb numeric;
  v_at timestamptz;
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

  -- One chart point per screen, replaced when results are corrected.
  delete from public.bilirubin_readings where screen_id = p_screen;
  v_tsb := nullif(p_results ->> 'tsb_total', '')::numeric;
  if v_tsb is not null and v_tsb > 0 and v_tsb < 1000 then
    v_at := coalesce(nullif(p_results ->> 'sampled_at', '')::timestamptz,
                     s.sent_at, s.due_at);
    insert into public.bilirubin_readings (patient_id, ward_id, measured_at, value,
                                           unit, method, screen_id)
    values (s.patient_id, s.ward_id, v_at, v_tsb,
            case when p_results ->> 'bili_unit' = 'umol' then 'umol' else 'mgdl' end,
            'serum', p_screen);
  end if;

  perform public._patient_event_note(s.patient_id, s.ward_id, 'Investigation',
    'Newborn investigation results' ||
    case when s.status = 'resulted' then ' (corrected)' else '' end ||
    coalesce(': ' || left(v_summary, 1500), '.'));
end;
$$;
