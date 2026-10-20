\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (id, name, ward_id) values ('cccccccc-0000-0000-0000-000000000001','Baby','11111');
select 'not assessed: '||(neuro_risk_factors is null) from public.patients;
update public.patients set neuro_risk_factors = '{}';
select 'none: '||cardinality(neuro_risk_factors) from public.patients;
update public.patients set neuro_risk_factors = '{isoimmune,sepsis}';
select 'factors: '||array_to_string(neuro_risk_factors, ',') from public.patients;
do $$ begin update public.patients set neuro_risk_factors = '{jaundice}'; raise exception 'UNKNOWN FACTOR ACCEPTED'; exception when check_violation then raise notice 'only known risk factors accepted'; end $$;
reset role;
