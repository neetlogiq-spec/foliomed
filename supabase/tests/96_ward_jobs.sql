-- Ward job list: stamping, assignee rules, privacy, transfer, push.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values
 ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222','NICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id) values
 ('cccccccc-0000-0000-0000-000000000001','Baby Anaya','11111');
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.join_ward('11111');

-- Dr A adds a job for Nurse B, trying to spoof the creator and patient name.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.ward_jobs (id, ward_id, patient_id, patient_name, title, urgent, due_by,
                              assigned_to, assigned_name, created_by, created_by_name)
values ('eeeeeeee-0000-0000-0000-000000000001','11111','cccccccc-0000-0000-0000-000000000001',
        'Wrong', 'Repeat TSB', true, now() + interval '3 hours',
        'bbbbbbbb-0000-0000-0000-000000000002','Spoof','dddddddd-0000-0000-0000-000000000004','Spoof');
do $$ declare j public.ward_jobs; begin
  select * into j from public.ward_jobs;
  if j.created_by <> 'aaaaaaaa-0000-0000-0000-000000000001' or j.created_by_name <> 'Dr A'
     or j.assigned_name <> 'Nurse B' or j.patient_name <> 'Baby Anaya' then
    raise exception 'STAMPS WRONG: % % % %', j.created_by, j.created_by_name, j.assigned_name, j.patient_name;
  end if;
  raise notice 'creator, assignee and patient name stamped by the server';
end $$;

-- Assignee must be in the ward.
do $$ begin
  insert into public.ward_jobs (ward_id, patient_id, title, assigned_to)
  values ('11111','cccccccc-0000-0000-0000-000000000001','x','dddddddd-0000-0000-0000-000000000004');
  raise exception 'OUTSIDER ASSIGNED';
exception when invalid_parameter_value then raise notice 'cannot assign someone outside the ward'; end $$;

-- Ward must match the patient.
do $$ begin
  insert into public.ward_jobs (ward_id, patient_id, title)
  values ('22222','cccccccc-0000-0000-0000-000000000001','wrong ward');
  raise exception 'MISMATCHED WARD ACCEPTED';
exception when insufficient_privilege then raise notice 'job must use the patient''s ward'; end $$;

-- A self-assigned job does not push.
insert into public.ward_jobs (ward_id, patient_id, title, assigned_to)
values ('11111','cccccccc-0000-0000-0000-000000000001','Check feeds','aaaaaaaa-0000-0000-0000-000000000001');

-- Nurse B ticks it done; done_by is stamped, history can't be rewritten.
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
update public.ward_jobs set done_at = now(), done_by = 'aaaaaaaa-0000-0000-0000-000000000001',
       created_by_name = 'Rewritten'
 where id = 'eeeeeeee-0000-0000-0000-000000000001';
do $$ declare j public.ward_jobs; begin
  select * into j from public.ward_jobs where id = 'eeeeeeee-0000-0000-0000-000000000001';
  if j.done_by <> 'bbbbbbbb-0000-0000-0000-000000000002' or j.done_by_name <> 'Nurse B'
     or j.created_by_name <> 'Dr A' then
    raise exception 'DONE/HISTORY WRONG: % % %', j.done_by, j.done_by_name, j.created_by_name;
  end if;
  raise notice 'done by Nurse B stamped; creator unchanged';
end $$;
-- Untick clears who did it.
update public.ward_jobs set done_at = null where id = 'eeeeeeee-0000-0000-0000-000000000001';
select 'after untick done_by is null: '||(done_by is null) from public.ward_jobs where id = 'eeeeeeee-0000-0000-0000-000000000001';

-- Outsider sees nothing and can't add.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees jobs: '||count(*) from public.ward_jobs;
do $$ begin
  insert into public.ward_jobs (ward_id, patient_id, title) values ('11111','cccccccc-0000-0000-0000-000000000001','x');
  raise exception 'OUTSIDER INSERTED';
exception when insufficient_privilege then raise notice 'outsider cannot add jobs'; end $$;

-- Transfer to NICU: jobs follow; Nurse B (not in NICU) loses the assignment.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','phototherapy');
do $$ begin
  if exists (select 1 from public.ward_jobs where ward_id <> '22222') then raise exception 'JOBS DID NOT MOVE'; end if;
  if exists (select 1 from public.ward_jobs where assigned_to = 'bbbbbbbb-0000-0000-0000-000000000002') then
    raise exception 'ASSIGNMENT KEPT FOR NON-MEMBER'; end if;
  if not exists (select 1 from public.ward_jobs where assigned_to = 'aaaaaaaa-0000-0000-0000-000000000001') then
    raise exception 'MEMBER ASSIGNMENT LOST'; end if;
  raise notice 'jobs moved with the patient; assignments kept only for NICU members';
end $$;
reset role;

-- Exactly one push: to Nurse B for the first job.
do $$ declare n int; o public.push_outbox; begin
  select count(*) into n from public.push_outbox where data->>'type' = 'job';
  if n <> 1 then raise exception 'EXPECTED 1 JOB PUSH, GOT %', n; end if;
  select * into o from public.push_outbox where data->>'type' = 'job';
  if o.only_user <> 'bbbbbbbb-0000-0000-0000-000000000002' or not o.high_priority then
    raise exception 'JOB PUSH WRONG: % %', o.only_user, o.high_priority; end if;
  raise notice 'push: % | %', o.title, o.body;
end $$;
