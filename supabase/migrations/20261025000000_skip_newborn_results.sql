-- "Skip" on the results prompt: stop asking the ward for this plan's
-- results. The plan stays "sent", so results can still be entered from
-- the baby's page later; a timeline line records who skipped.
create or replace function public.skip_newborn_results(p_screen uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
begin
  if s.status = 'resulted' then return; end if;  -- nothing to skip
  update public.patient_reminders
     set done_at = now()
   where screen_id = p_screen and done_at is null;
  perform public._patient_event_note(s.patient_id, s.ward_id, 'Investigation',
    s.planned_hours || '-hour newborn investigation results skipped by '
    || coalesce(nullif(public._my_name(), ''), 'a team member')
    || '. They can still be entered from the baby''s page.');
end;
$$;

revoke execute on function public.skip_newborn_results(uuid) from public, anon;
grant execute on function public.skip_newborn_results(uuid) to authenticated;

-- "Ask again later" after results are in did nothing useful and created a
-- results reminder that never went away. It is now a no-op for a
-- resulted plan (an out-of-date prompt on another phone can still send it).
create or replace function public.remind_newborn_results(p_screen uuid, p_hours int default 6)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  s public.newborn_screens := public._newborn_screen_for_update(p_screen);
  v_name text;
begin
  if p_hours not between 1 and 72 then
    raise exception 'hours out of range' using errcode = '22023';
  end if;
  if s.status = 'resulted' then return; end if;
  select name into v_name from public.patients where id = s.patient_id;
  delete from public.patient_reminders
   where screen_id = p_screen and kind = 'newborn_results' and done_at is null;
  insert into public.patient_reminders (patient_id, ward_id, patient_name,
                                        title, due_at, screen_id, kind)
  values (s.patient_id, s.ward_id, coalesce(v_name, ''),
          'Enter newborn investigation results',
          now() + make_interval(hours => p_hours), p_screen, 'newborn_results');
end;
$$;

-- Close reminders left open on plans that already have results.
update public.patient_reminders r
   set done_at = now()
  from public.newborn_screens s
 where r.screen_id = s.id and s.status = 'resulted' and r.done_at is null;
