-- Newborn investigation plan → sent → results, with reminders and RLS.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001'),('22222','NICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id, born_at, gestation_weeks, gestation_days) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111', now() - interval '10 hours', 39, 2),
 ('cccccccc-0000-0000-0000-000000000002','No birth time','11111', null, null, null);
do $$ begin insert into public.patients (name, ward_id, gestation_weeks) values ('x','11111', 50); raise exception 'BAD GESTATION ACCEPTED'; exception when check_violation then raise notice 'gestation range enforced'; end $$;
do $$ begin perform public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000002', 48, 12); raise exception 'PLANNED WITHOUT BIRTH TIME'; exception when invalid_parameter_value then raise notice 'birth time required to plan'; end $$;

-- Plan 48 h with an 8 h heads-up, then change mind to 72 h / 12 h: only one plan remains.
select public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000001', 48, 8);
select public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000001', 72, 12);
select 'plans: '||count(*)||', hours='||max(planned_hours) from public.newborn_screens;
select 'reminders: '||string_agg(kind||' @'||round(extract(epoch from (r.due_at - p.born_at))/3600)||'h', ', ' order by r.due_at)
  from public.patient_reminders r join public.patients p on p.id = r.patient_id;
do $$ begin insert into public.newborn_screens (patient_id, ward_id, planned_hours, due_at) values ('cccccccc-0000-0000-0000-000000000001','11111',48,now()); raise exception 'DIRECT INSERT ACCEPTED'; exception when insufficient_privilege then raise notice 'direct writes blocked (RPC only)'; end $$;

-- Nurse B marks sent; reminders close; timeline note posted.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');
select public.mark_newborn_screen_sent(id) from public.newborn_screens;
select public.mark_newborn_screen_sent(id) from public.newborn_screens; -- idempotent
select 'status: '||status||' by '||sent_by_name from public.newborn_screens;
select 'open reminders after sent: '||count(*) from public.patient_reminders where done_at is null;
select public.remind_newborn_results(id, 6) from public.newborn_screens;
select 'results reminder in ~'||round(extract(epoch from (due_at - now()))/3600)||' h' from public.patient_reminders where kind='newborn_results';

-- Outsider: sees nothing, can't act.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees screens: '||count(*) from public.newborn_screens;
do $$ begin perform public.save_newborn_results((select id from public.newborn_screens limit 1), '{}', 'x'); raise exception 'OUTSIDER SAVED'; exception when no_data_found or sqlstate 'P0002' then raise notice 'outsider cannot find the screen'; end $$;

-- Dr A saves results; results reminder closes; corrected save labelled.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.save_newborn_results(id, '{"tsb_total": 12.4, "tsb_direct": 0.6}', 'TSB 12.4 mg/dL') from public.newborn_screens;
select public.save_newborn_results(id, '{"tsb_total": 12.8, "tsb_direct": 0.6}', 'TSB 12.8 mg/dL') from public.newborn_screens;
select 'status: '||status||', tsb='||(results->>'tsb_total')||', by '||resulted_by_name from public.newborn_screens;
select 'open reminders after results: '||count(*) from public.patient_reminders where done_at is null;
select 'timeline: '||string_agg(left(content, 45), ' | ' order by created_at) from public.notes where category='Investigation';
do $$ begin perform public.save_newborn_results((select id from public.newborn_screens limit 1), '[1]', 'x'); raise exception 'ARRAY ACCEPTED'; exception when invalid_parameter_value then raise notice 'results must be an object'; end $$;

-- Transfer carries the plan.
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','phototherapy');
select 'screen ward after transfer: '||ward_id from public.newborn_screens;
reset role;
