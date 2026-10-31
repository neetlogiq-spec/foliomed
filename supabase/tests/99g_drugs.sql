-- Drugs: ward settings + sign-off, running infusions, privacy, transfer, discharge.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('eeeeeeee-0000-0000-0000-000000000005','e@x.com','{"name":"Dr E"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
-- Production gives clients no direct writes on these tables.
revoke insert, update, delete on public.ward_drug_settings, public.patient_infusions from authenticated;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','NICU','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Baby','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002'; select public.join_ward('11111');
set request.jwt.claim.sub = 'eeeeeeee-0000-0000-0000-000000000005'; select public.join_ward('11111');

-- Ward settings: owner only.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.set_ward_drug('11111', 'dopamine', 40, 10, false, '  Central line only  ');
do $$ begin
  if (select unit_note from public.ward_drug_settings where drug_key = 'dopamine') <> 'Central line only'
    then raise exception 'NOTE NOT TRIMMED'; end if;
  if (select updated_by_name from public.ward_drug_settings where drug_key = 'dopamine') <> 'Dr A'
    then raise exception 'EDITOR NOT STAMPED'; end if;
  raise notice 'owner sets vial, mixture and note';
end $$;
set request.jwt.claim.sub = 'eeeeeeee-0000-0000-0000-000000000005';
do $$ begin perform public.set_ward_drug('11111', 'dopamine', 80, 10);
  raise exception 'NON-OWNER CHANGED SETTINGS';
exception when insufficient_privilege then raise notice 'only the owner changes settings'; end $$;
do $$ begin insert into public.ward_drug_settings (ward_id, drug_key) values ('11111', 'x');
  raise exception 'DIRECT INSERT ALLOWED';
exception when insufficient_privilege then raise notice 'no direct writes'; end $$;

-- Sign-off: doctors of the ward; not nurses.
select public.check_ward_drug('11111', 'dopamine', 'sig1');
do $$ begin
  if (select checked_by_name from public.ward_drug_settings where drug_key = 'dopamine') <> 'Dr E'
    then raise exception 'CHECK NOT STAMPED'; end if;
  raise notice 'a doctor signs off';
end $$;
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin perform public.check_ward_drug('11111', 'adrenaline', 'sig');
  raise exception 'NURSE SIGNED OFF';
exception when insufficient_privilege then raise notice 'nurses cannot sign off'; end $$;

-- A note-only change keeps the sign-off; a new vial clears it.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.set_ward_drug('11111', 'dopamine', 40, 10, false, 'Central line preferred');
do $$ begin
  if (select checked_signature from public.ward_drug_settings where drug_key = 'dopamine') is distinct from 'sig1'
    then raise exception 'NOTE CHANGE CLEARED CHECK'; end if;
end $$;
select public.set_ward_drug('11111', 'dopamine', 80, 10, false, 'Central line preferred');
do $$ begin
  if (select checked_signature from public.ward_drug_settings where drug_key = 'dopamine') is not null
    then raise exception 'NEW VIAL KEPT CHECK'; end if;
  raise notice 'changing the vial clears the sign-off';
end $$;

set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.ward_drug_settings) <> 0 then raise exception 'OUTSIDER SEES SETTINGS'; end if;
  perform public.check_ward_drug('11111', 'dopamine', 'x');
  raise exception 'OUTSIDER SIGNED OFF';
exception when insufficient_privilege then raise notice 'outsiders see and sign nothing'; end $$;

-- Running infusions: start / change / stop, each on the timeline.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.start_infusion('cccccccc-0000-0000-0000-000000000001', 'dopamine', 'Dopamine', 10,
  'mcg/kg/min', 1, 0.6, 'mg/mL', '30 mg in 50 mL', 1);
do $$ begin
  if (select started_by_name from public.patient_infusions) <> 'Nurse B' then raise exception 'STARTER NOT STAMPED'; end if;
  if not exists (select 1 from public.notes where category = 'Infusion'
                 and content = 'Started Dopamine 10 mcg/kg/min (1.0 mL/h) — 30 mg in 50 mL.')
    then raise exception 'NO START NOTE: %', (select string_agg(content, ' | ') from public.notes); end if;
  raise notice 'start logged';
end $$;
select public.change_infusion((select id from public.patient_infusions), 15, 1.5);
do $$ begin
  if (select dose from public.patient_infusions) <> 15 then raise exception 'NOT CHANGED'; end if;
  if not exists (select 1 from public.notes where content = 'Dopamine changed from 10 to 15 mcg/kg/min (1.5 mL/h).')
    then raise exception 'NO CHANGE NOTE'; end if;
  raise notice 'change logged';
end $$;
do $$ begin perform public.change_infusion((select id from public.patient_infusions), -1, 1);
  raise exception 'NEGATIVE DOSE ACCEPTED';
exception when invalid_parameter_value then raise notice 'negative dose refused'; end $$;
do $$ begin insert into public.patient_infusions (patient_id, ward_id, drug_name, dose, dose_unit, rate_ml_h,
    concentration, conc_unit) values ('cccccccc-0000-0000-0000-000000000001','11111','X',1,'u',1,1,'u');
  raise exception 'DIRECT INFUSION INSERT';
exception when insufficient_privilege then raise notice 'infusions only through RPCs'; end $$;

set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.patient_infusions) <> 0 then raise exception 'OUTSIDER SEES INFUSIONS'; end if;
  raise notice 'outsiders see no infusions';
end $$;

-- Follows transfer; discharge stops it; discharged patients can't start one.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if (select ward_id from public.patient_infusions) <> '22222' then raise exception 'INFUSION DID NOT MOVE'; end if;
  raise notice 'infusion follows transfer';
end $$;
select public.discharge_patient('cccccccc-0000-0000-0000-000000000001', '');
do $$ begin
  if (select stopped_at from public.patient_infusions) is null then raise exception 'DISCHARGE DID NOT STOP'; end if;
  if (select stopped_by_name from public.patient_infusions) <> 'Discharge' then raise exception 'WRONG STOPPER'; end if;
  perform public.start_infusion('cccccccc-0000-0000-0000-000000000001', '', 'X', 1, 'u', 1, 1, 'u');
  raise exception 'STARTED ON DISCHARGED';
exception when invalid_parameter_value then raise notice 'discharge stops infusions; none start after'; end $$;
