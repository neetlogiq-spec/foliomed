-- Workload report: owner/admin only, range limits, rows per kind.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','Paeds','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (id, name, ward_id, bed_number) values ('cccccccc-0000-0000-0000-000000000001','Child','11111','1');
insert into public.ward_jobs (ward_id, patient_id, title, urgent) values ('11111','cccccccc-0000-0000-0000-000000000001','Cannula', true);
update public.ward_jobs set done_at = now();
insert into public.notes (patient_id, ward_id, content, priority) values ('cccccccc-0000-0000-0000-000000000001','11111','Desaturating','Urgent');
insert into public.notes (patient_id, ward_id, content, priority) values ('cccccccc-0000-0000-0000-000000000001','11111','Routine','Normal');
insert into public.patient_reminders (patient_id, ward_id, title, due_at) values ('cccccccc-0000-0000-0000-000000000001','11111','Gas', now() - interval '1 hour');
select public.start_handover('11111');
select public.finish_handover(id) from public.handovers;

do $$ begin
  if (select array_to_string(array_agg(kind order by kind), ',') from public.ward_workload('11111', now() - interval '1 day', now() + interval '1 hour'))
     <> 'handover,job,reminder,urgent_note' then raise exception 'KINDS WRONG'; end if;
  if (select total || '/' || missed from public.ward_workload('11111', now() - interval '1 day', now() + interval '1 hour') where kind = 'handover')
     <> '1/1' then raise exception 'HANDOVER COUNTS WRONG'; end if;
  if (select (done_at is not null)::text || urgent::text from public.ward_workload('11111', now() - interval '1 day', now() + interval '1 hour') where kind = 'job')
     <> 'truetrue' then raise exception 'JOB ROW WRONG'; end if;
  raise notice 'owner gets one row per job, urgent note, reminder and handover';
end $$;
do $$ begin perform public.ward_workload('11111', now() - interval '40 days', now()); raise exception 'LONG RANGE OK';
exception when invalid_parameter_value then raise notice 'range limited to 31 days'; end $$;
update public.wards set shift_starts = '{420,1140}';
do $$ begin update public.wards set shift_starts = '{1500}'; raise exception 'BAD SHIFT ACCEPTED';
exception when check_violation then raise notice 'shift starts must be times of day'; end $$;

set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin perform public.ward_workload('11111', now() - interval '1 day', now()); raise exception 'MEMBER SAW REPORT';
exception when insufficient_privilege then raise notice 'members (not owner) refused'; end $$;
reset role;
