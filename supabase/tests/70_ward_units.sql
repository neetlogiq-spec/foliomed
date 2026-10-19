-- Units inside a ward: owner-managed list, member moves, transfer clears.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001'),('22222','NICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.ward_units (id, ward_id, name, position) values
 ('eeeeeeee-0000-0000-0000-00000000000a','11111','Unit A',0),
 ('eeeeeeee-0000-0000-0000-00000000000b','11111','Unit B',1),
 ('eeeeeeee-0000-0000-0000-00000000000c','22222','Unit A',0);
do $$ begin insert into public.ward_units (ward_id, name) values ('11111',' unit a '); raise exception 'DUPLICATE UNIT ACCEPTED'; exception when unique_violation then raise notice 'unit names unique per ward (case-insensitive)'; end $$;
insert into public.patients (id, name, ward_id, unit_id) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111','eeeeeeee-0000-0000-0000-00000000000a');
do $$ begin insert into public.patients (name, ward_id, unit_id) values ('x','11111','eeeeeeee-0000-0000-0000-00000000000c'); raise exception 'FOREIGN UNIT ACCEPTED'; exception when check_violation then raise notice 'unit must belong to the patient''s ward'; end $$;

-- Nurse B: can read units and move patients, cannot edit the list.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');
select 'nurse sees units: '||count(*) from public.ward_units;
do $$ begin insert into public.ward_units (ward_id, name) values ('11111','Unit Z'); raise exception 'NON-OWNER CREATED UNIT'; exception when insufficient_privilege then raise notice 'only the owner manages units'; end $$;
select public.move_patient_unit('cccccccc-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-00000000000b');
select public.move_patient_unit('cccccccc-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-00000000000b'); -- no-op
select 'unit now: '||u.name from public.patients p join public.ward_units u on u.id = p.unit_id;
select 'timeline: '||string_agg(content, ' | ') from public.notes;
do $$ begin perform public.move_patient_unit('cccccccc-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-00000000000c'); raise exception 'MOVED TO OTHER WARD UNIT'; exception when sqlstate 'P0002' then raise notice 'cannot move to a unit of another ward'; end $$;

-- Outsider: sees no units, can't move.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees units: '||count(*) from public.ward_units;
do $$ begin perform public.move_patient_unit('cccccccc-0000-0000-0000-000000000001', null); raise exception 'OUTSIDER MOVED'; exception when sqlstate 'P0002' or insufficient_privilege then raise notice 'outsider cannot move patients'; end $$;

-- Transfer to NICU clears the PNC unit; deleting a unit unassigns.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
select 'unit after transfer: '||coalesce(unit_id::text,'none') from public.patients;
select public.move_patient_unit('cccccccc-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-00000000000c');
delete from public.ward_units where id = 'eeeeeeee-0000-0000-0000-00000000000c';
select 'unit after unit deleted: '||coalesce(unit_id::text,'none') from public.patients;
reset role;
