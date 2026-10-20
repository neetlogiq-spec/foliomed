-- Ward job list: the day's tasks per patient ("Repeat TSB at 6 pm",
-- "Send TSH", "Paeds review"), optionally assigned to one ward member,
-- ticked off by whoever does it.
--
-- * Who created / assigned / completed a job is stamped by the server.
-- * The assignee must belong to the patient's ward.
-- * Jobs follow the patient on transfer (assignment is dropped if the
--   assignee is not in the new ward).
-- * Assigning someone (other than yourself) queues a push to them only:
--   push_outbox gains `only_user`, honoured by the push-dispatch function.

create table if not exists public.ward_jobs (
  id               uuid primary key default gen_random_uuid(),
  ward_id          text not null references public.wards (id) on delete cascade,
  patient_id       uuid not null references public.patients (id) on delete cascade,
  patient_name     text not null default '',
  title            text not null check (length(trim(title)) between 1 and 200),
  urgent           boolean not null default false,
  due_by           timestamptz,
  assigned_to      uuid references public.profiles (id) on delete set null,
  assigned_name    text,
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now(),
  done_at          timestamptz,
  done_by          uuid references public.profiles (id) on delete set null,
  done_by_name     text
);

create index if not exists ward_jobs_ward_open_idx
  on public.ward_jobs (ward_id, created_at) where done_at is null;
create index if not exists ward_jobs_patient_idx
  on public.ward_jobs (patient_id, created_at);
create index if not exists ward_jobs_assignee_open_idx
  on public.ward_jobs (assigned_to) where done_at is null;

alter table public.ward_jobs enable row level security;

drop policy if exists ward_jobs_all on public.ward_jobs;
create policy ward_jobs_all on public.ward_jobs
  for all to authenticated
  using (public.is_ward_member(ward_id))
  with check (
    public.is_ward_member(ward_id)
    and ward_id = public.patient_ward(patient_id)
  );

-- Is [p_user] a member of [p_ward]? (is_ward_member only checks the caller.)
create or replace function public._user_in_ward(p_user uuid, p_ward text)
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.wards w
                      where w.id = p_ward and p_user = any (w.member_ids)) $$;

create or replace function public.stamp_ward_job()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    select name into new.created_by_name from public.profiles where id = auth.uid();
    new.created_at := now();
    new.done_at := null;
  else
    -- History is not editable from the client.
    new.created_by := old.created_by;
    new.created_by_name := old.created_by_name;
    new.created_at := old.created_at;
  end if;

  select name into new.patient_name from public.patients where id = new.patient_id;
  new.patient_name := coalesce(new.patient_name, '');

  if new.assigned_to is null then
    new.assigned_name := null;
  elsif tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to then
    if not public._user_in_ward(new.assigned_to, new.ward_id) then
      raise exception 'that person is not a member of this ward' using errcode = '22023';
    end if;
    select name into new.assigned_name from public.profiles where id = new.assigned_to;
  else
    new.assigned_name := old.assigned_name;
  end if;

  if new.done_at is not null and (tg_op = 'INSERT' or old.done_at is null) then
    new.done_by := auth.uid();
    select name into new.done_by_name from public.profiles where id = auth.uid();
  elsif new.done_at is null then
    new.done_by := null;
    new.done_by_name := null;
  else
    new.done_at := old.done_at;
    new.done_by := old.done_by;
    new.done_by_name := old.done_by_name;
  end if;
  return new;
end;
$$;

drop trigger if exists ward_jobs_stamp on public.ward_jobs;
create trigger ward_jobs_stamp
  before insert or update on public.ward_jobs
  for each row execute function public.stamp_ward_job();

-- Jobs move with the patient. Done here rather than in transfer_patient so
-- any future way of changing a patient's ward is covered too.
create or replace function public.ward_jobs_follow_patient()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.ward_jobs j
     set ward_id = new.ward_id,
         assigned_to = case when public._user_in_ward(j.assigned_to, new.ward_id)
                            then j.assigned_to end
   where j.patient_id = new.id;
  return new;
end;
$$;

drop trigger if exists patients_ward_jobs_follow on public.patients;
create trigger patients_ward_jobs_follow
  after update of ward_id on public.patients
  for each row when (old.ward_id is distinct from new.ward_id)
  execute function public.ward_jobs_follow_patient();

-- ── Push to the assignee ──────────────────────────────────────────────
alter table public.push_outbox
  add column if not exists only_user uuid;

create or replace function public.enqueue_job_push()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.assigned_to is null or new.done_at is not null
     or new.assigned_to = auth.uid()
     or (tg_op = 'UPDATE' and new.assigned_to is not distinct from old.assigned_to) then
    return new;
  end if;
  insert into public.push_outbox (ward_id, only_user, title, body, data,
                                  high_priority, channel)
  values (
    new.ward_id, new.assigned_to,
    case when new.urgent then 'Urgent job · ' else 'New job · ' end ||
      coalesce(nullif(new.patient_name, ''), 'Patient'),
    coalesce(nullif(new.created_by_name, '') || ': ', '') || left(new.title, 160),
    jsonb_build_object('type', 'job', 'job_id', new.id::text,
                       'patient_id', new.patient_id::text),
    new.urgent, 'ward_notes');
  perform public._kick_push_dispatch();
  return new;
end;
$$;

drop trigger if exists ward_jobs_enqueue_push on public.ward_jobs;
create trigger ward_jobs_enqueue_push
  after insert or update of assigned_to on public.ward_jobs
  for each row execute function public.enqueue_job_push();

-- ── Grants ────────────────────────────────────────────────────────────
grant select, insert, update, delete on public.ward_jobs to authenticated;
revoke execute on function public._user_in_ward(uuid, text) from public, anon, authenticated;
revoke execute on function public.stamp_ward_job() from public, anon, authenticated;
revoke execute on function public.ward_jobs_follow_patient() from public, anon, authenticated;
revoke execute on function public.enqueue_job_push() from public, anon, authenticated;

alter publication supabase_realtime add table public.ward_jobs;
