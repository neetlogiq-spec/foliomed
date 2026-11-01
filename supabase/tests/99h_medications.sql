-- Medications and allergies: roles, history, timeline, privacy, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
revoke insert, update, delete on public.patient_medications, public.patient_medication_events,
  public.patient_allergies from authenticated;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Child','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002'; select public.join_ward('11111');

-- A doctor starts a drug; history and timeline follow.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.add_medication('cccccccc-0000-0000-0000-000000000001', 'inpatient', '', ' Amoxicillin ', 30,
  'mg/kg', 'IV', 'TDS', 'Pneumonia');
do $$ begin
  if (select created_by_name from public.patient_medications) <> 'Dr A' then raise exception 'NOT STAMPED'; end if;
  if (select started_on from public.patient_medications) <> current_date then raise exception 'NO START DATE'; end if;
  if not exists (select 1 from public.notes where category = 'Medication'
                 and content = 'Started Amoxicillin 30 mg/kg IV TDS — Pneumonia.')
    then raise exception 'NO START NOTE: %', (select string_agg(content, ' | ') from public.notes); end if;
  raise notice 'doctor starts a medicine';
end $$;
select public.change_medication((select id from public.patient_medications), 50, 'mg/kg', 'IV', 'TDS', 'Severe');
do $$ begin
  if (select dose from public.patient_medications) <> 50 then raise exception 'NOT CHANGED'; end if;
  if (select summary from public.patient_medication_events where kind = 'change')
     <> '30 mg/kg IV TDS → 50 mg/kg IV TDS — Severe' then
    raise exception 'BAD CHANGE EVENT: %', (select summary from public.patient_medication_events where kind = 'change');
  end if;
  raise notice 'changes kept as history';
end $$;

-- Nurses record drug history and allergies, but don't prescribe.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin perform public.add_medication('cccccccc-0000-0000-0000-000000000001', 'inpatient', '', 'Paracetamol',
    15, 'mg/kg', 'Oral', 'QID');
  raise exception 'NURSE PRESCRIBED';
exception when insufficient_privilege then raise notice 'nurses cannot prescribe'; end $$;
do $$ begin perform public.change_medication((select id from public.patient_medications where context = 'inpatient'),
    1, 'mg', 'IV', 'OD');
  raise exception 'NURSE CHANGED';
exception when insufficient_privilege then raise notice 'nurses cannot change doses'; end $$;
select public.add_medication('cccccccc-0000-0000-0000-000000000001', 'home', '', 'Sodium valproate', 200, 'mg',
  'Oral', 'BD', null, null, 'Parent');
do $$ begin
  if not exists (select 1 from public.notes where content = 'Drug history: takes Sodium valproate 200 mg Oral BD (from Parent).')
    then raise exception 'NO HISTORY NOTE'; end if;
  raise notice 'nurse records drug history';
end $$;
do $$ begin perform public.change_medication((select id from public.patient_medications where context = 'home'),
    1, 'mg', 'Oral', 'OD');
  raise exception 'CHANGED HOME MED';
exception when insufficient_privilege or invalid_parameter_value then raise notice 'history entries are not changed'; end $$;

-- Allergies and "no known allergies".
select public.set_no_known_allergies('cccccccc-0000-0000-0000-000000000001');
do $$ begin
  if (select nka_recorded_by_name from public.patients) <> 'Nurse B' then raise exception 'NKA NOT STAMPED'; end if;
end $$;
select public.add_allergy('cccccccc-0000-0000-0000-000000000001', 'Penicillin', 'Urticaria', 'moderate', 'drug', 'Parent');
do $$ begin
  if (select nka_recorded_at from public.patients) is not null then raise exception 'NKA KEPT WITH AN ALLERGY'; end if;
  if not exists (select 1 from public.notes where category = 'Allergy'
                 and content = 'Allergy recorded: Penicillin — Urticaria (moderate).') then raise exception 'NO ALLERGY NOTE'; end if;
  perform public.set_no_known_allergies('cccccccc-0000-0000-0000-000000000001');
  raise exception 'NKA WITH ALLERGY';
exception when invalid_parameter_value then raise notice 'allergy clears NKA; NKA refused while one exists'; end $$;
do $$ begin perform public.remove_allergy((select id from public.patient_allergies), 'Wrong patient');
  raise exception 'NURSE REMOVED ALLERGY';
exception when insufficient_privilege then raise notice 'only doctors remove allergies'; end $$;
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
do $$ begin perform public.remove_allergy((select id from public.patient_allergies), '  ');
  raise exception 'REMOVED WITHOUT REASON';
exception when invalid_parameter_value then raise notice 'removal needs a reason'; end $$;

-- Privacy.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.patient_medications) + (select count(*) from public.patient_allergies)
     + (select count(*) from public.patient_medication_events) <> 0 then raise exception 'OUTSIDER SEES MEDS'; end if;
  perform public.add_allergy('cccccccc-0000-0000-0000-000000000001', 'X');
  raise exception 'OUTSIDER ADDED';
exception when insufficient_privilege then raise notice 'outsiders see and add nothing'; end $$;

-- Stop, then transfer moves everything.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.stop_medication((select id from public.patient_medications where context = 'inpatient'), 'Course complete');
do $$ begin
  if (select stopped_by_name from public.patient_medications where context = 'inpatient') <> 'Dr A'
    then raise exception 'STOP NOT STAMPED'; end if;
  if (select count(*) from public.patient_medication_events) <> 3 then raise exception 'EVENTS MISSING'; end if;
end $$;
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if exists (select 1 from public.patient_medications where ward_id <> '22222')
     or exists (select 1 from public.patient_allergies where ward_id <> '22222')
     or exists (select 1 from public.patient_medication_events where ward_id <> '22222')
    then raise exception 'DID NOT MOVE'; end if;
  raise notice 'medicines and allergies follow transfer';
end $$;
