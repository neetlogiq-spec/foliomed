-- Observations: stamping, ranges, ward match, privacy, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Child','11111');

insert into public.observations (patient_id, ward_id, taken_at, resp_rate, spo2, on_oxygen,
  heart_rate, systolic_bp, temp_c, consciousness, pews_behaviour, pews_cardio, pews_resp, created_by_name)
values ('cccccccc-0000-0000-0000-000000000001','11111', now(), 32, 94, true, 150, 95, 38.4, 'A', 1, 1, 2, 'Spoof');
do $$ begin
  if (select created_by_name from public.observations) <> 'Dr A' then raise exception 'NOT STAMPED'; end if;
  raise notice 'recorder stamped';
end $$;
do $$ begin insert into public.observations (patient_id, ward_id, taken_at, pews_resp)
  values ('cccccccc-0000-0000-0000-000000000001','11111', now(), 4); raise exception 'PEWS 4 ACCEPTED';
exception when check_violation then raise notice 'PEWS components 0–3 only'; end $$;
do $$ begin insert into public.observations (patient_id, ward_id, taken_at, consciousness)
  values ('cccccccc-0000-0000-0000-000000000001','11111', now(), 'X'); raise exception 'BAD ACVPU ACCEPTED';
exception when check_violation then raise notice 'ACVPU only'; end $$;
do $$ begin insert into public.observations (patient_id, ward_id, taken_at)
  values ('cccccccc-0000-0000-0000-000000000001','22222', now()); raise exception 'WRONG WARD ACCEPTED';
exception when insufficient_privilege then raise notice 'observations must use the patient''s ward'; end $$;

set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.observations) <> 0 then raise exception 'OUTSIDER SEES OBS'; end if;
  raise notice 'outsiders see nothing';
end $$;

set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if (select ward_id from public.observations) <> '22222' then raise exception 'OBS DID NOT MOVE'; end if;
  raise notice 'observations follow the patient on transfer';
end $$;
reset role;
