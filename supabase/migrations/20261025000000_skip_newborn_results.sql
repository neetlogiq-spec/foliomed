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
