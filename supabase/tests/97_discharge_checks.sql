-- Discharge checklist: stamping, privacy, upsert, cascade.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (id, name, ward_id, born_at) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111', now() - interval '50 hours');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Nurse B ticks Vitamin K, spoofing who did it.
insert into public.discharge_checks (patient_id, item, done_by, done_by_name, done_at)
values ('cccccccc-0000-0000-0000-000000000001','vitamin_k','aaaaaaaa-0000-0000-0000-000000000001','Spoof', now() - interval '3 days');
do $$ declare c public.discharge_checks; begin
  select * into c from public.discharge_checks;
  if c.done_by <> 'bbbbbbbb-0000-0000-0000-000000000002' or c.done_by_name <> 'Nurse B'
     or c.done_at < now() - interval '1 minute' then
    raise exception 'STAMP WRONG: % % %', c.done_by, c.done_by_name, c.done_at; end if;
  raise notice 'tick stamped as Nurse B, now';
end $$;

-- Follow-up with detail, then Dr A updates it (upsert) — stamp moves to Dr A.
insert into public.discharge_checks (patient_id, item, detail)
values ('cccccccc-0000-0000-0000-000000000001','follow_up','  Paeds OPD 23 Oct  ');
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.discharge_checks (patient_id, item, detail)
values ('cccccccc-0000-0000-0000-000000000001','follow_up','Paeds OPD 24 Oct')
on conflict (patient_id, item) do update set detail = excluded.detail;
select 'follow-up: '||detail||' by '||done_by_name from public.discharge_checks where item = 'follow_up';

-- Bad item keys are refused.
do $$ begin
  insert into public.discharge_checks (patient_id, item) values ('cccccccc-0000-0000-0000-000000000001','Bad Key!');
  raise exception 'BAD KEY ACCEPTED';
exception when check_violation then raise notice 'invalid item key rejected'; end $$;

-- Outsider: sees nothing, cannot tick.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees checks: '||count(*) from public.discharge_checks;
do $$ begin
  insert into public.discharge_checks (patient_id, item) values ('cccccccc-0000-0000-0000-000000000001','bcg');
  raise exception 'OUTSIDER TICKED';
exception when insufficient_privilege then raise notice 'outsider cannot tick'; end $$;

-- Untick = delete; deleting the patient removes the rest.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
delete from public.discharge_checks where item = 'vitamin_k';
select 'after untick: '||count(*) from public.discharge_checks;
reset role;
delete from public.patients where id = 'cccccccc-0000-0000-0000-000000000001';
do $$ begin
  if exists (select 1 from public.discharge_checks) then raise exception 'CASCADE FAILED'; end if;
  raise notice 'checks removed with the patient';
end $$;
