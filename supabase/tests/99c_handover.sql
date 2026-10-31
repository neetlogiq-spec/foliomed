-- Handover: summary stamping, contingencies, sessions, privacy, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Dr B"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
-- The test grants table writes to everyone; the app must not rely on that,
-- so take it back for the handover tables like production.
revoke insert, update, delete on public.handovers, public.handover_entries from authenticated;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id, bed_number) values
 ('cccccccc-0000-0000-0000-000000000001','Child Ten','11111','10'),
 ('cccccccc-0000-0000-0000-000000000002','Child Two','11111','2'),
 ('cccccccc-0000-0000-0000-000000000003','Child NoBed','11111', '');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Summary stamped; untouched by other edits; blank clears.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.patients set handover_summary = '  Bronchiolitis day 2, on HFNC 1 L/kg  ' where bed_number = '2';
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
update public.patients set diagnosis = 'Bronchiolitis' where bed_number = '2';
do $$ declare p public.patients; begin
  select * into p from public.patients where bed_number = '2';
  if p.handover_summary <> 'Bronchiolitis day 2, on HFNC 1 L/kg' or p.handover_summary_by_name <> 'Dr A'
     or p.handover_summary_at is null then raise exception 'SUMMARY STAMP WRONG'; end if;
  raise notice 'summary trimmed and stamped; other edits keep the stamp';
end $$;

-- Contingency stamped; wrong ward refused.
insert into public.patient_contingencies (patient_id, ward_id, if_text, then_text)
values ('cccccccc-0000-0000-0000-000000000002','11111','SpO2 below 92% on 2 L/kg','Call PICU registrar');
do $$ begin
  if (select created_by_name from public.patient_contingencies) <> 'Dr B' then raise exception 'NOT STAMPED'; end if;
  raise notice 'contingency stamped';
end $$;

-- Session: bed order captured, receive / unreceive, finish, finished is locked.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.start_handover('11111') as hid \gset
do $$ begin
  if (select string_agg(bed_number, ',' order by position) from public.handover_entries) <> '2,10,' then
    raise exception 'ORDER WRONG: %', (select string_agg(bed_number, ',' order by position) from public.handover_entries); end if;
  if (select given_by_name from public.handovers) <> 'Dr A' then raise exception 'GIVER WRONG'; end if;
  raise notice 'handover started: beds in order, no-bed last';
end $$;
do $$ begin insert into public.handovers (ward_id) values ('11111'); raise exception 'DIRECT INSERT ALLOWED';
exception when insufficient_privilege then raise notice 'sessions only through the functions'; end $$;

set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.receive_handover_entry(id, ' Is the 6 pm gas due? ') from public.handover_entries where bed_number = '2';
select public.receive_handover_entry(id) from public.handover_entries where bed_number = '10';
select public.unreceive_handover_entry(id) from public.handover_entries where bed_number = '10';
do $$ declare e public.handover_entries; begin
  select * into e from public.handover_entries where bed_number = '2';
  if e.received_by_name <> 'Dr B' or e.question <> 'Is the 6 pm gas due?' then raise exception 'RECEIVE WRONG'; end if;
  if (select received_at from public.handover_entries where bed_number = '10') is not null then raise exception 'UNRECEIVE FAILED'; end if;
  raise notice 'received with question; undo works';
end $$;
select public.finish_handover(:'hid');
do $$ begin
  perform public.receive_handover_entry(id) from public.handover_entries where bed_number = '10';
  raise exception 'RECEIVED AFTER FINISH';
exception when invalid_parameter_value then raise notice 'finished handovers are locked'; end $$;
do $$ begin
  if (select count(*) from public.handover_entries where received_at is null) <> 2 then raise exception 'MISSED COUNT WRONG'; end if;
  raise notice '2 patients recorded as missed';
end $$;

-- Outsider sees and does nothing.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.handovers) + (select count(*) from public.patient_contingencies) <> 0 then
    raise exception 'OUTSIDER SEES HANDOVER'; end if;
  perform public.start_handover('11111'); raise exception 'OUTSIDER STARTED';
exception when insufficient_privilege then raise notice 'outsiders refused'; end $$;

-- Contingencies follow the patient on transfer.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000002','22222','');
do $$ begin
  if (select ward_id from public.patient_contingencies) <> '22222' then raise exception 'DID NOT MOVE'; end if;
  raise notice 'contingencies follow the patient';
end $$;
reset role;
