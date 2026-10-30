-- Workload report: tasks per shift and response times, for the ward
-- owner and admins.
--
-- * wards.shift_starts: shift start times in minutes after local
--   midnight (default 08:00, 14:00, 20:00). Shifts run from one start to
--   the next; the last wraps past midnight. Owner edits.
-- * ward_workload(): the raw timings for a date range (≤ 31 days) — jobs,
--   urgent notes (posted → confirmed), reminders (due → done) and
--   handovers (patients, missed). The app groups them into shifts in the
--   phone's time zone and works out the numbers.

alter table public.wards
  add column if not exists shift_starts smallint[] not null default array[480, 840, 1200]::smallint[];

do $$ begin
  alter table public.wards add constraint wards_shift_starts_check
    check (cardinality(shift_starts) between 1 and 6
           and 0 <= all (shift_starts) and 1440 > all (shift_starts));
exception when duplicate_object then null; end $$;

create or replace function public.ward_workload(p_ward text, p_from timestamptz, p_to timestamptz)
returns table (
  kind       text,         -- job | urgent_note | reminder | handover
  at         timestamptz,  -- created / posted / due / started
  done_at    timestamptz,  -- done / confirmed / done / finished
  urgent     boolean,
  due_at     timestamptz,  -- jobs: due by
  who        text,         -- done by / confirmed by / given by
  total      int,          -- handovers: patients
  missed     int           -- handovers: not received
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not (public.is_admin()
          or exists (select 1 from public.wards w where w.id = p_ward and w.creator_id = auth.uid())) then
    raise exception 'only the ward owner or an admin can see the workload report' using errcode = '42501';
  end if;
  if p_to <= p_from or p_to - p_from > interval '32 days' then
    raise exception 'choose a range of up to 31 days' using errcode = '22023';
  end if;
  return query
    select 'job'::text, j.created_at, j.done_at, j.urgent, j.due_by, j.done_by_name, null::int, null::int
      from public.ward_jobs j
     where j.ward_id = p_ward and j.created_at >= p_from and j.created_at < p_to
    union all
    select 'urgent_note', n.created_at, n.acknowledged_at, true, null, n.acknowledged_by, null, null
      from public.notes n
     where n.ward_id = p_ward and n.priority = 'Urgent' and n.created_at >= p_from and n.created_at < p_to
    union all
    select 'reminder', r.due_at, r.done_at, false, null, r.done_by_name, null, null
      from public.patient_reminders r
     where r.ward_id = p_ward and r.due_at >= p_from and r.due_at < p_to
    union all
    select 'handover', h.started_at, h.finished_at, false, null, h.given_by_name,
           (select count(*)::int from public.handover_entries e where e.handover_id = h.id),
           (select count(*)::int from public.handover_entries e where e.handover_id = h.id and e.received_at is null)
      from public.handovers h
     where h.ward_id = p_ward and h.started_at >= p_from and h.started_at < p_to;
end;
$$;
revoke execute on function public.ward_workload(text, timestamptz, timestamptz) from public, anon;
grant execute on function public.ward_workload(text, timestamptz, timestamptz) to authenticated;
