-- Forms: template editing rights and versions, saving a form (note,
-- observation, weight), privacy, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('eeeeeeee-0000-0000-0000-000000000005','e@x.com','{"name":"Dr E"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
revoke insert, update, delete on public.form_templates, public.patient_forms from authenticated;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Surgery','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Child','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002'; select public.join_ward('11111');
set request.jwt.claim.sub = 'eeeeeeee-0000-0000-0000-000000000005'; select public.join_ward('11111');

-- Any doctor of the ward edits forms; versions go up only when the fields change.
select public.save_form_template('11111', 'ward_round', 'Ward round', 'Ours', '{"sections": []}', 'ward_round');
do $$ begin
  if (select version from public.form_templates) <> 1 then raise exception 'BAD FIRST VERSION'; end if;
  if (select updated_by_name from public.form_templates) <> 'Dr E' then raise exception 'EDITOR NOT STAMPED'; end if;
end $$;
select public.save_form_template('11111', 'ward_round', 'Ward round', 'Renamed only', '{"sections": []}');
do $$ begin if (select version from public.form_templates) <> 1 then raise exception 'BUMPED WITHOUT CHANGE'; end if; end $$;
select public.save_form_template('11111', 'ward_round', 'Ward round', 'Ours',
  '{"sections": [{"id": "s", "title": "S", "fields": []}]}');
do $$ begin
  if (select version from public.form_templates) <> 2 then raise exception 'NOT BUMPED'; end if;
  raise notice 'doctors edit forms; version follows the fields';
end $$;
do $$ begin perform public.save_form_template('11111', 'bad', 'Bad', '', '{"x": 1}');
  raise exception 'NO-SECTIONS FORM SAVED';
exception when invalid_parameter_value then raise notice 'forms need sections'; end $$;
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin perform public.save_form_template('11111', 'x', 'X', '', '{"sections": []}');
  raise exception 'NURSE EDITED FORM';
exception when insufficient_privilege then raise notice 'nurses fill forms but do not edit them'; end $$;

-- Saving a form: record, timeline note, observation, weight (in range only).
select public.save_patient_form('cccccccc-0000-0000-0000-000000000001', 'ward_round', 'Ward round', 2,
  '{"sections": []}', '{"pain": "no"}', 'Ward round — Nurse B: HR 140; ⚠ not pain controlled.', 1,
  '{"hr": 140, "rr": 32, "spo2": 97, "temp": 38.24, "sbp": 400, "weight": 3.25}');
do $$ begin
  if (select created_by_name from public.patient_forms) <> 'Nurse B' then raise exception 'FORM NOT STAMPED'; end if;
  if not exists (select 1 from public.notes where category = 'Form'
                 and content = 'Ward round — Nurse B: HR 140; ⚠ not pain controlled.') then raise exception 'NO NOTE'; end if;
  if (select heart_rate from public.observations) <> 140 or (select temp_c from public.observations) <> 38.2
     or (select systolic_bp from public.observations) is not null then raise exception 'BAD OBSERVATION'; end if;
  if (select grams from public.weights) <> 3250 then raise exception 'NO WEIGHT'; end if;
  raise notice 'form saved with note, observation (out-of-range dropped) and weight';
end $$;
select public.save_patient_form('cccccccc-0000-0000-0000-000000000001', 'nursing_vitals', 'Nursing vitals', 1,
  '{"sections": []}', '{}', 'Nursing vitals — Nurse B.', 0, '{"weight": 25}');
do $$ begin
  if (select count(*) from public.weights) <> 1 then raise exception 'OUT-OF-RANGE WEIGHT SAVED'; end if;
  if (select count(*) from public.observations) <> 1 then raise exception 'EMPTY OBSERVATION SAVED'; end if;
  raise notice 'no vitals, no observation';
end $$;

set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.patient_forms) + (select count(*) from public.form_templates) <> 0
    then raise exception 'OUTSIDER SEES FORMS'; end if;
  perform public.save_patient_form('cccccccc-0000-0000-0000-000000000001', 'x', 'X', 1, '{}', '{}', 'X.');
  raise exception 'OUTSIDER SAVED';
exception when insufficient_privilege then raise notice 'outsiders see and save nothing'; end $$;

set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if exists (select 1 from public.patient_forms where ward_id <> '22222') then raise exception 'FORMS DID NOT MOVE'; end if;
  raise notice 'filled forms follow transfer';
end $$;
