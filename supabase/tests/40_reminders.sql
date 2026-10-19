-- Newborn birth time + ward reminders smoke test.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001'),('22222','NICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id, born_at) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111', now() - interval '30 hours');
do $$ begin insert into public.patients (name, ward_id, born_at) values ('Future','11111', now() + interval '2 days'); raise exception 'FUTURE BIRTH ACCEPTED'; exception when check_violation then raise notice 'birth time in the future rejected'; end $$;
insert into public.patient_reminders (patient_id, ward_id, title, due_at)
select id, ward_id, 'Send 48-hour investigations', born_at + interval '48 hours' from public.patients where name='Baby Anaya';
select 'reminder due in ~'||round(extract(epoch from (due_at - now()))/3600)||' h, creator stamped='||(created_by='aaaaaaaa-0000-0000-0000-000000000001') from public.patient_reminders;
do $$ begin insert into public.patient_reminders (patient_id, ward_id, title, due_at) values ('cccccccc-0000-0000-0000-000000000001','22222','wrong ward', now()); raise exception 'MISMATCHED WARD ACCEPTED'; exception when insufficient_privilege then raise notice 'reminder must use the patient''s ward'; end $$;
-- Nurse B (PNC member) marks it sent; server stamps who
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');
update public.patient_reminders set done_at = now(), done_by = 'aaaaaaaa-0000-0000-0000-000000000001', done_by_name = 'Spoofed';
select 'done by: '||done_by_name||' (spoof ignored='||(done_by='bbbbbbbb-0000-0000-0000-000000000002')||')' from public.patient_reminders;
-- Outsider sees nothing
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees reminders: '||count(*) from public.patient_reminders;
-- Transfer carries reminders
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','needs phototherapy');
select 'reminder ward after transfer: '||ward_id from public.patient_reminders;
reset role;
