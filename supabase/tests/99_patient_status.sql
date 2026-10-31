-- Patient status: ward kind, stamping, RPC + timeline note, privacy.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (id, name, ward_id) values
 ('cccccccc-0000-0000-0000-000000000001','Child','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Ward kind: defaults to other; owner sets it; a member's update changes nothing.
do $$ begin
  if (select kind from public.wards) <> 'other' then raise exception 'DEFAULT KIND WRONG'; end if;
end $$;
update public.wards set kind = 'adult';
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
do $$ begin
  if (select kind from public.wards) <> 'other' then raise exception 'MEMBER CHANGED KIND'; end if;
  raise notice 'only the owner sets the ward type';
end $$;
update public.wards set kind = 'picu';
do $$ begin update public.wards set kind = 'icu'; raise exception 'UNKNOWN KIND ACCEPTED';
exception when check_violation then raise notice 'only known ward types accepted'; end $$;

-- New patient: no status, no stamps.
do $$ declare p public.patients; begin
  select * into p from public.patients;
  if p.acuity is not null or p.acuity_set_at is not null or cardinality(p.support_tags) <> 0 then
    raise exception 'NEW PATIENT HAS STATUS'; end if;
end $$;

-- Nurse B sets Sick with tags; stamped as Nurse B; timeline note written.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.set_patient_status('cccccccc-0000-0000-0000-000000000001', 'sick',
  '  desaturating  ', '{niv,inotropes}');
do $$ declare p public.patients; n text; begin
  select * into p from public.patients;
  if p.acuity <> 'sick' or p.acuity_reason <> 'desaturating'
     or p.acuity_set_by <> 'bbbbbbbb-0000-0000-0000-000000000002' or p.acuity_set_by_name <> 'Nurse B'
     or p.acuity_set_at < now() - interval '1 minute' then
    raise exception 'STATUS WRONG: % % % %', p.acuity, p.acuity_reason, p.acuity_set_by_name, p.acuity_set_at; end if;
  select content into n from public.notes where category = 'Status';
  if n <> 'Status: Sick — desaturating. Support: NIV / HFNC, Inotropes.' then
    raise exception 'NOTE WRONG: %', n; end if;
  raise notice 'status stamped and logged: %', n;
end $$;

-- An ordinary patient edit leaves the status stamps alone.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.patients set bed_number = '3';
do $$ begin
  if (select acuity_set_by_name from public.patients) <> 'Nurse B' then
    raise exception 'EDIT MOVED THE STAMP'; end if;
  raise notice 'patient edits keep the status stamp';
end $$;

-- Spoofing the stamp directly is overwritten.
update public.patients set acuity_set_by = 'bbbbbbbb-0000-0000-0000-000000000002',
  acuity_set_at = now() - interval '3 days', acuity = 'stable';
do $$ declare p public.patients; begin
  select * into p from public.patients;
  if p.acuity_set_by <> 'aaaaaaaa-0000-0000-0000-000000000001'
     or p.acuity_set_at < now() - interval '1 minute' then
    raise exception 'SPOOF KEPT'; end if;
  raise notice 'direct writes are stamped as the writer, now';
end $$;

-- Same status again = reviewed; clearing; bad values refused.
select public.set_patient_status('cccccccc-0000-0000-0000-000000000001', 'stable');
select public.set_patient_status('cccccccc-0000-0000-0000-000000000001', null);
do $$ declare notes text; begin
  select string_agg(content, ' | ' order by created_at, content) into notes from public.notes where category = 'Status';
  if notes not like '%Status reviewed: Stable.%' or notes not like '%Status cleared.%' then
    raise exception 'REVIEW/CLEAR NOTES WRONG: %', notes; end if;
  if (select acuity from public.patients) is not null then raise exception 'NOT CLEARED'; end if;
  raise notice 'review and clear logged';
end $$;
do $$ begin perform public.set_patient_status('cccccccc-0000-0000-0000-000000000001', 'critical');
  raise exception 'UNKNOWN ACUITY ACCEPTED';
exception when check_violation then raise notice 'only stable/watch/sick accepted'; end $$;
do $$ begin perform public.set_patient_status('cccccccc-0000-0000-0000-000000000001', 'watch', null, '{ecmo}');
  raise exception 'UNKNOWN TAG ACCEPTED';
exception when check_violation then raise notice 'only known support tags accepted'; end $$;

-- Outsiders can't set it.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
do $$ begin perform public.set_patient_status('cccccccc-0000-0000-0000-000000000001', 'sick');
  raise exception 'OUTSIDER SET STATUS';
exception when insufficient_privilege then raise notice 'outsiders refused'; end $$;
reset role;
