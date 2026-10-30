-- My patients: private follows, pruning on discharge / transfer, tags.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Dr B"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values
 ('cccccccc-0000-0000-0000-000000000001','One','11111'),
 ('cccccccc-0000-0000-0000-000000000002','Two','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Each follows; each sees only their own.
insert into public.patient_follows (user_id, patient_id) values
 ('bbbbbbbb-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000001'),
 ('bbbbbbbb-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002');
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.patient_follows (user_id, patient_id) values
 ('aaaaaaaa-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001');
do $$ begin
  if (select count(*) from public.patient_follows) <> 1 then raise exception 'SEES OTHERS FOLLOWS'; end if;
  raise notice 'follows are private';
end $$;
do $$ begin
  insert into public.patient_follows (user_id, patient_id)
  values ('bbbbbbbb-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000002');
  raise exception 'FOLLOWED FOR SOMEONE ELSE';
exception when insufficient_privilege then raise notice 'cannot follow on someone else''s behalf'; end $$;
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  insert into public.patient_follows (user_id, patient_id)
  values ('dddddddd-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000001');
  raise exception 'OUTSIDER FOLLOWED';
exception when insufficient_privilege then raise notice 'outsiders cannot follow'; end $$;

-- Transfer to PICU (B not a member): B's follow goes, A's stays. Discharge ends A's.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
reset role;
do $$ begin
  if (select string_agg(user_id::text || '/' || right(patient_id::text, 1), ',' order by user_id, patient_id)
        from public.patient_follows)
     <> 'aaaaaaaa-0000-0000-0000-000000000001/1,bbbbbbbb-0000-0000-0000-000000000002/2' then
    raise exception 'TRANSFER PRUNE WRONG: %', (select string_agg(user_id::text, ',') from public.patient_follows); end if;
  raise notice 'transfer drops follows of people not in the new ward';
end $$;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.discharge_patient('cccccccc-0000-0000-0000-000000000001', '');
reset role;
do $$ begin
  if exists (select 1 from public.patient_follows where patient_id = 'cccccccc-0000-0000-0000-000000000001') then
    raise exception 'DISCHARGE DID NOT END FOLLOW'; end if;
  raise notice 'discharge ends follows';
end $$;

-- Consultant and tags: limits; wards start with a tag list.
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
update public.patients set consultant = 'Dr Rao', tags = '{NPO,Isolation}' where name = 'Two';
do $$ begin
  if (select array_to_string(tags, ',') from public.patients where name = 'Two') <> 'NPO,Isolation' then raise exception 'TAGS'; end if;
  if (select cardinality(tag_options) from public.wards where id = '11111') < 5 then raise exception 'NO STARTER TAGS'; end if;
  update public.patients set tags = '{"this tag is far too long to fit"}' where name = 'Two';
  raise exception 'LONG TAG ACCEPTED';
exception when check_violation then raise notice 'tags limited; wards start with a tag list'; end $$;
reset role;
