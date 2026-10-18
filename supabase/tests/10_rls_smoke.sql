-- RLS / trigger smoke test. Run after 00_supabase_stub.sql + the migration.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
grant select on public.metrics to anon;
grant all on storage.objects to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A","role":"doctor"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"Nurse B","role":"nurse"}'),
 ('cccccccc-0000-0000-0000-000000000003','c@x.com','{"role":"superuser"}');
select name, role, ward_ids from public.profiles order by email;

-- as A
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id, creator_email) values ('12345','ICU','aaaaaaaa-0000-0000-0000-000000000001','a@x.com');
select public.join_ward('12345') as a_join;
insert into public.patients (id, name, ward_id) values ('11111111-0000-0000-0000-000000000000','Pt One','12345');
insert into public.notes (id, patient_id, ward_id, author_id, content) values ('22222222-0000-0000-0000-000000000000','11111111-0000-0000-0000-000000000000','12345','aaaaaaaa-0000-0000-0000-000000000001','BP 120/80');
insert into public.note_comments (note_id, text) values ('22222222-0000-0000-0000-000000000000','ok');
select public.bump_metric('note','test');
do $$ begin
  perform public.dashboard_counts();
  raise exception 'doctor should not read dashboard counts';
exception when insufficient_privilege then
  raise notice 'doctor blocked from dashboard_counts (expected)';
end $$;
insert into storage.objects (bucket_id, name) values ('monitor-snapshots','11111111-0000-0000-0000-000000000000/latest.jpg');

-- as B (not a member)
set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select count(*) as b_sees_wards_before from public.wards;
select count(*) as b_sees_notes_before from public.notes;
select public.join_ward('99999') as b_join_bad;
select public.join_ward('12345') as b_join;
select count(*) as b_sees_notes_after from public.notes;
select count(*) as b_sees_comments from public.note_comments;
with d as (delete from public.wards where id='12345' returning 1) select count(*) as b_deleted_wards from d;
with u as (update public.profiles set name='hacked' where id='aaaaaaaa-0000-0000-0000-000000000001' returning 1) select count(*) as b_updated_a from u;
do $$ begin
  insert into public.patients (name, ward_id) values ('x','54321');
  raise exception 'SHOULD NOT INSERT';
exception when others then
  if sqlerrm = 'SHOULD NOT INSERT' then raise; end if;
  raise notice 'b insert into unknown ward rejected: %', sqlerrm;
end $$;
select public.leave_ward('12345');
select count(*) as b_sees_notes_after_leave from public.notes;
select public.join_ward('12345');

-- as A: delete ward -> cascade + B cleanup
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
delete from public.wards where id='12345';
reset role;
select (select count(*) from public.patients) p, (select count(*) from public.notes) n, (select count(*) from public.note_comments) c;
select email, ward_ids, ward_id from public.profiles order by email;
select type, count from public.metrics order by type;

-- anon can read metrics, not activity
set role anon;
select count(*) as anon_metrics from public.metrics;
do $$ begin perform count(*) from public.recent_activity; raise notice 'anon read activity?!'; exception when others then raise notice 'anon activity blocked: %', sqlerrm; end $$;
reset role;

-- delete account for B
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
select public.delete_my_account();
reset role;
select email from auth.users order by email;
select email from public.profiles order by email;
