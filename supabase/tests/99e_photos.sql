-- Clinical photos: bucket limits, path-based access that follows transfer, consent, timeline.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
grant all on storage.objects to authenticated;
revoke insert, update on public.patient_photos from authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
do $$ begin
  if (select public or file_size_limit <> 3145728 or allowed_mime_types <> array['image/jpeg']
        from storage.buckets where id = 'clinical-photos') then raise exception 'BUCKET SETTINGS WRONG'; end if;
  raise notice 'bucket is private, JPEG only, 3 MB max';
end $$;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Child','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Nurse B uploads (file then record).
insert into storage.objects (bucket_id, name) values
 ('clinical-photos','cccccccc-0000-0000-0000-000000000001/eeeeeeee-0000-0000-0000-000000000001.jpg'),
 ('clinical-photos','cccccccc-0000-0000-0000-000000000001/eeeeeeee-0000-0000-0000-000000000001_t.jpg');
do $$ begin
  perform public.add_patient_photo('eeeeeeee-0000-0000-0000-000000000009','cccccccc-0000-0000-0000-000000000001',
    'cccccccc-0000-0000-0000-000000000001/x.jpg', null, 'rash', 1600, 1200, 200000, false, false);
  raise exception 'NO-CONSENT ACCEPTED';
exception when invalid_parameter_value then raise notice 'consent required'; end $$;
select public.add_patient_photo('eeeeeeee-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001',
  'cccccccc-0000-0000-0000-000000000001/eeeeeeee-0000-0000-0000-000000000001.jpg',
  'cccccccc-0000-0000-0000-000000000001/eeeeeeee-0000-0000-0000-000000000001_t.jpg',
  '  Rash on trunk, day 3  ', 1600, 1200, 210000, false, true);
do $$ begin
  if (select created_by_name || '|' || caption from public.patient_photos) <> 'Nurse B|Rash on trunk, day 3' then
    raise exception 'RECORD WRONG'; end if;
  if (select content from public.notes where category = 'Photo') not like 'Photo added: Rash on trunk, day 3.%' then
    raise exception 'NO TIMELINE NOTE'; end if;
  raise notice 'photo recorded and on the timeline';
end $$;
do $$ begin
  perform public.add_patient_photo('eeeeeeee-0000-0000-0000-000000000008','cccccccc-0000-0000-0000-000000000001',
    'dddddddd-0000-0000-0000-000000000004/x.jpg', null, null, 10, 10, 10, false, true);
  raise exception 'FOREIGN PATH ACCEPTED';
exception when check_violation then raise notice 'path must be under the patient'; end $$;

-- Outsider: sees no files or records, cannot upload.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from storage.objects) + (select count(*) from public.patient_photos) <> 0 then
    raise exception 'OUTSIDER SEES PHOTOS'; end if;
  insert into storage.objects (bucket_id, name)
  values ('clinical-photos','cccccccc-0000-0000-0000-000000000001/evil.jpg');
  raise exception 'OUTSIDER UPLOADED';
exception when insufficient_privilege then raise notice 'outsiders see and upload nothing'; end $$;

-- Transfer to PICU (B not a member): B loses access, A keeps it.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
do $$ begin
  if (select count(*) from storage.objects) <> 2 then raise exception 'A LOST ACCESS'; end if;
end $$;
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin
  if (select count(*) from storage.objects) + (select count(*) from public.patient_photos) <> 0 then
    raise exception 'OLD WARD STILL SEES'; end if;
  raise notice 'access follows the patient on transfer';
end $$;

-- A deletes the record.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
delete from public.patient_photos;
do $$ begin
  if (select count(*) from public.patient_photos) <> 0 then raise exception 'NOT DELETED'; end if;
  raise notice 'members can delete';
end $$;
reset role;
