-- Patient lifecycle smoke test: codes, age units, discharge, transfer.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','ICU','aaaaaaaa-0000-0000-0000-000000000001'),('22222','HDU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, age, age_unit, ward_id, bed_number) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya',12,'days','11111','3'),
 ('cccccccc-0000-0000-0000-000000000002','Mr Rao',61,'years','11111','12');
select name, patient_code, age, age_unit, status, is_active from public.patients order by name;
do $$ begin insert into public.patients (name, age_unit, ward_id) values ('x','weeks','11111'); raise exception 'BAD AGE UNIT ACCEPTED'; exception when check_violation then raise notice 'invalid age unit rejected'; end $$;
update public.patients set patient_code = 'HACKED' where name = 'Mr Rao';
select 'code immutable: '||patient_code from public.patients where name='Mr Rao';
insert into public.notes (patient_id, ward_id, author_id, content) values ('cccccccc-0000-0000-0000-000000000002','11111','aaaaaaaa-0000-0000-0000-000000000001','BP 86/50');
insert into public.note_comments (note_id, text) select id, 'on it' from public.notes where content='BP 86/50';
-- B is only in ICU
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');
do $$ begin perform public.transfer_patient('cccccccc-0000-0000-0000-000000000002','22222','step down'); raise exception 'NON-MEMBER TRANSFER ALLOWED'; exception when insufficient_privilege then raise notice 'transfer needs membership of both wards'; end $$;
-- A transfers Mr Rao to HDU, bed 4
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000002','22222','step down','4');
select 'after transfer: ward '||ward_id||' bed '||bed_number from public.patients where name='Mr Rao';
select 'notes moved: '||count(*) filter (where ward_id='22222')||'/'||count(*) from public.notes where patient_id='cccccccc-0000-0000-0000-000000000002';
select 'timeline: '||category||' — '||content from public.notes where category='Transfer';
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select 'B (ICU only) now sees Mr Rao rows: '||count(*) from public.patients where name='Mr Rao';
select 'B sees Mr Rao notes/replies: '||(select count(*) from public.notes where patient_id='cccccccc-0000-0000-0000-000000000002')||'/'||(select count(*) from public.note_comments);
-- B discharges Baby Anaya (ICU)
select public.discharge_patient('cccccccc-0000-0000-0000-000000000001','Feeding well, follow-up in 1 week');
select 'discharged: '||status||' active='||is_active||' by B='||(discharged_by='bbbbbbbb-0000-0000-0000-000000000002')||' summary='||discharge_summary from public.patients where name='Baby Anaya';
select 'timeline: '||content from public.notes where category='Discharge';
select public.readmit_patient('cccccccc-0000-0000-0000-000000000001');
select 'readmitted: '||status||' active='||is_active||' summary cleared='||(discharge_summary is null) from public.patients where name='Baby Anaya';
reset role;
