-- Regression: re-planning and saving results never leave stale reminders.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (id, name, ward_id, born_at) values
 ('cccccccc-0000-0000-0000-000000000001','BO NUTHANA','11111', now() - interval '40 hours');

select public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000001', 48, 12) as first_plan \gset
select public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000001', 48, 12) as second_plan \gset
select set_config('t.first_plan', :'first_plan', false);
do $$ declare n int; s int; begin
  select count(*) into s from public.newborn_screens;
  select count(*) into n from public.patient_reminders where done_at is null;
  if s <> 1 or n <> 2 then raise exception 'AFTER RE-PLAN: % screens, % open reminders', s, n; end if;
  raise notice 'plan twice → 1 plan, 2 open reminders (heads-up + sent?)';
end $$;

-- The replaced plan is gone: marking it sent fails with P0002 (the app
-- now says "this plan was replaced" instead of a raw error).
do $$ begin
  perform public.mark_newborn_screen_sent(current_setting('t.first_plan')::uuid);
  raise exception 'STALE PLAN ACCEPTED';
exception when no_data_found then raise notice 'stale plan → no_data_found (P0002)'; end $$;

select public.mark_newborn_screen_sent(:'second_plan'::uuid);
select public.remind_newborn_results(:'second_plan'::uuid, 6);
-- Skip: stops asking for results, keeps the plan open for later entry.
select public.skip_newborn_results(:'second_plan'::uuid);
do $$ declare n int; st text; begin
  select count(*) into n from public.patient_reminders where done_at is null;
  select status into st from public.newborn_screens;
  if n <> 0 or st <> 'sent' then raise exception 'AFTER SKIP: % open, status %', n, st; end if;
  if not exists (select 1 from public.notes where content like '%results skipped%') then
    raise exception 'NO TIMELINE NOTE FOR SKIP'; end if;
  raise notice 'skip → no open reminders, plan still sent, timeline note posted';
end $$;
-- Results can still be entered later.
select public.save_newborn_results(:'second_plan'::uuid, '{"tsh": 3.1}'::jsonb, 'TSH 3.1');
do $$ declare n int; begin
  select count(*) into n from public.patient_reminders where done_at is null;
  if n <> 0 then raise exception 'OPEN REMINDERS AFTER RESULTS: %', n; end if;
  raise notice 'after results: no open reminders';
end $$;
reset role;
