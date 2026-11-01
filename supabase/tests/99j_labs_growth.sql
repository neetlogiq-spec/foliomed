-- Labs and measurements: batch add with note, flags, delete, privacy, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
revoke insert, update on public.lab_results from authenticated;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Child','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002'; select public.join_ward('11111');

select public.add_lab_results('cccccccc-0000-0000-0000-000000000001', '2026-11-05 06:00+00',
  '[{"test_key":"hb","test_name":"Hb","value":9.1,"unit":"g/dL","ref_low":11,"ref_high":14,"flag":"low"},
    {"test_key":"k","test_name":"Potassium","value":6.8,"unit":"mmol/L","flag":"criticalHigh"},
    {"test_key":"blood_culture","test_name":"Blood culture","value_text":"No growth at 48 h"}]',
  'Labs: Hb 9.1 g/dL ↓, Potassium 6.8 mmol/L ⚠↑, Blood culture no growth at 48 h.', 'scan');
do $$ begin
  if (select count(*) from public.lab_results) <> 3 then raise exception 'NOT ALL SAVED'; end if;
  if exists (select 1 from public.lab_results where created_by_name <> 'Nurse B' or source <> 'scan')
    then raise exception 'NOT STAMPED'; end if;
  if not exists (select 1 from public.notes where category = 'Investigation' and content like 'Labs: Hb 9.1%')
    then raise exception 'NO NOTE'; end if;
  raise notice 'batch saved with stamp and one timeline note';
end $$;
do $$ begin perform public.add_lab_results('cccccccc-0000-0000-0000-000000000001', now(), '[]', 'x');
  raise exception 'EMPTY BATCH ACCEPTED';
exception when invalid_parameter_value then raise notice 'empty batches refused'; end $$;
do $$ begin perform public.add_lab_results('cccccccc-0000-0000-0000-000000000001', now(),
    '[{"test_key":"hb","test_name":"Hb","flag":"weird"}]', 'x');
  raise exception 'BAD ROW ACCEPTED';
exception when check_violation then raise notice 'rows need a value and a known flag'; end $$;
do $$ begin insert into public.lab_results (patient_id, ward_id, test_key, test_name, value, sampled_at)
    values ('cccccccc-0000-0000-0000-000000000001','11111','hb','Hb',1,now());
  raise exception 'DIRECT INSERT';
exception when insufficient_privilege then raise notice 'results only through the RPC'; end $$;
delete from public.lab_results where test_key = 'hb';
do $$ begin if (select count(*) from public.lab_results) <> 2 then raise exception 'DELETE FAILED'; end if; end $$;

insert into public.patient_measurements (patient_id, ward_id, measured_at, length_cm, head_cm, created_by_name)
values ('cccccccc-0000-0000-0000-000000000001','11111', now(), 74.5, 45.2, 'Spoof');
do $$ begin
  if (select created_by_name from public.patient_measurements) <> 'Nurse B' then raise exception 'MEASURE NOT STAMPED'; end if;
end $$;
do $$ begin insert into public.patient_measurements (patient_id, ward_id, measured_at, length_cm)
    values ('cccccccc-0000-0000-0000-000000000001','11111', now(), 5);
  raise exception 'SILLY LENGTH';
exception when check_violation then raise notice 'measurement ranges enforced'; end $$;

set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.lab_results) + (select count(*) from public.patient_measurements) <> 0
    then raise exception 'OUTSIDER SEES LABS'; end if;
  raise notice 'outsiders see nothing';
end $$;

set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if exists (select 1 from public.lab_results where ward_id <> '22222')
     or exists (select 1 from public.patient_measurements where ward_id <> '22222') then raise exception 'DID NOT MOVE'; end if;
  raise notice 'labs and measurements follow transfer';
end $$;
