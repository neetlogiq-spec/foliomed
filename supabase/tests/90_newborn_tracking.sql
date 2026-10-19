-- Bilirubin readings, phototherapy, weights, mother details.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}'),
 ('dddddddd-0000-0000-0000-000000000004','d@x.com','{"name":"Outsider D"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001'),('22222','NICU','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111'); select public.join_ward('22222');
insert into public.patients (id, name, ward_id, born_at, gestation_weeks, mother_name, mother_age, gravida_para, birth_weight_g) values
 ('cccccccc-0000-0000-0000-000000000001','Baby of Priya','11111', now() - interval '50 hours', 39, 'Priya Sharma', 27, 'G2P1', 3100);
do $$ begin update public.patients set mother_age = 70; raise exception 'AGE ACCEPTED'; exception when check_violation then raise notice 'mother age range enforced'; end $$;
insert into public.weights (patient_id, ward_id, measured_at, grams) values
 ('cccccccc-0000-0000-0000-000000000001','11111', now() - interval '26 hours', 2950),
 ('cccccccc-0000-0000-0000-000000000001','11111', now() - interval '2 hours', 2760);
select 'weights: '||count(*)||', stamped='||bool_and(created_by_name = 'Dr A') from public.weights;
insert into public.bilirubin_readings (patient_id, ward_id, measured_at, value, unit, method) values
 ('cccccccc-0000-0000-0000-000000000001','11111', now() - interval '20 hours', 9.8, 'mgdl', 'transcutaneous');
do $$ begin insert into public.bilirubin_readings (patient_id, ward_id, measured_at, value, unit) values ('cccccccc-0000-0000-0000-000000000001','22222', now(), 10, 'mgdl'); raise exception 'WRONG WARD ACCEPTED'; exception when insufficient_privilege then raise notice 'reading must use the patient''s ward'; end $$;

-- Phototherapy: one open session at a time; start/stop on timeline.
insert into public.phototherapy_sessions (patient_id, ward_id, started_at) values ('cccccccc-0000-0000-0000-000000000001','11111', now() - interval '6 hours');
do $$ begin insert into public.phototherapy_sessions (patient_id, ward_id, started_at) values ('cccccccc-0000-0000-0000-000000000001','11111', now()); raise exception 'SECOND OPEN SESSION'; exception when unique_violation then raise notice 'only one running phototherapy per baby'; end $$;
update public.phototherapy_sessions set stopped_at = now() where stopped_at is null;
select 'timeline: '||string_agg(content, ' | ' order by created_at) from public.notes where category = 'Phototherapy';

-- Results add one chart point; correction replaces it.
select public.plan_newborn_screen('cccccccc-0000-0000-0000-000000000001', 48, 12);
select public.mark_newborn_screen_sent(id) from public.newborn_screens;
select public.save_newborn_results(id, '{"tsb_total": 13.2, "bili_unit": "mgdl"}', 'x') from public.newborn_screens;
select public.save_newborn_results(id, '{"tsb_total": 14.1, "bili_unit": "mgdl"}', 'x') from public.newborn_screens;
select 'readings: '||count(*)||', serum from results='||max(value) filter (where screen_id is not null) from public.bilirubin_readings;

-- Outsider sees nothing.
set request.jwt.claim.sub = 'dddddddd-0000-0000-0000-000000000004';
select 'outsider sees: '||(select count(*) from public.weights)+(select count(*) from public.bilirubin_readings)+(select count(*) from public.phototherapy_sessions);

-- Transfer carries everything.
set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.transfer_patient('cccccccc-0000-0000-0000-000000000001','22222','');
select 'after transfer wards: '||(select string_agg(distinct ward_id, ',') from public.weights)||'/'||(select string_agg(distinct ward_id, ',') from public.bilirubin_readings)||'/'||(select string_agg(distinct ward_id, ',') from public.phototherapy_sessions);
reset role;
