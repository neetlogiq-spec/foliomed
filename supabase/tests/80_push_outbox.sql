-- Push outbox: notes and due reminders queue alerts; tokens are private.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
select public.register_push_token('token-for-doctor-a-device-0001', 'android');
select 'push enabled before setup: '||public.push_enabled();
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111');
insert into public.notes (patient_id, patient_name, ward_id, author_id, author_name, author_role, content, category, priority)
values ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111','aaaaaaaa-0000-0000-0000-000000000001','Dr A','doctor','Start phototherapy','General','Urgent');
-- system line (acknowledged) is not pushed
select public.discharge_patient('cccccccc-0000-0000-0000-000000000001', 'well');
select public.readmit_patient('cccccccc-0000-0000-0000-000000000001');
insert into public.patient_reminders (patient_id, ward_id, patient_name, title, due_at, kind) values
 ('cccccccc-0000-0000-0000-000000000001','11111','Baby Anaya','Send 48-hour newborn investigations', now() - interval '1 minute', 'general'),
 ('cccccccc-0000-0000-0000-000000000001','11111','Baby Anaya','Later task', now() + interval '2 hours', 'general');

-- Nurse B: can't read A's token or the outbox.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');
select 'nurse sees tokens: '||count(*) from public.push_tokens;
select 'nurse sees outbox rows: '||count(*) from public.push_outbox;
-- The same physical device signs in as nurse B: token moves to B.
select public.register_push_token('token-for-doctor-a-device-0001', 'android');
select 'nurse now owns token: '||count(*) from public.push_tokens;
reset role;

select 'outbox after note: '||count(*)||' (urgent='||bool_and(high_priority)||', excludes author='||bool_and(exclude_user = 'aaaaaaaa-0000-0000-0000-000000000001')||')' from public.push_outbox;
select 'title: '||title||' | body: '||body from public.push_outbox;
select 'queued reminders: '||public.enqueue_due_reminders();
select 'queued again (no duplicates): '||public.enqueue_due_reminders();
-- Snooze ends → pushed again once.
update public.patient_reminders set snoozed_until = now() - interval '1 second' where title like 'Send%';
select 'after snooze: '||public.enqueue_due_reminders();
select 'reminder push body: '||body from public.push_outbox where channel = 'patient_reminders' limit 1;
insert into public.app_settings values ('push_enabled', 'true');
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select 'push enabled after setup: '||public.push_enabled();
reset role;
