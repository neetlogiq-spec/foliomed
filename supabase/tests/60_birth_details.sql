-- Birth details columns accept real values and reject impossible ones.
\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"Dr A"}');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.wards (id, name, creator_id) values ('11111','PNC','aaaaaaaa-0000-0000-0000-000000000001');
select public.join_ward('11111');
insert into public.patients (name, ward_id, born_at, gestation_weeks, gestation_days, birth_weight_g,
  size_for_dates, delivery_mode, delivery_indication, mother_blood_group, apgar_1, apgar_5, resuscitated)
values ('Baby Anaya','11111', now() - interval '20 hours', 39, 2, 3100, 'AGA', 'LSCS', 'CPD', 'O+', 8, 9, false);
select 'stored: '||birth_weight_g||'g '||size_for_dates||' '||delivery_mode||' ('||delivery_indication||') mother '||mother_blood_group||' APGAR '||apgar_1||'/'||apgar_5 from public.patients;
do $$ begin update public.patients set birth_weight_g = 9000; raise exception 'WEIGHT ACCEPTED'; exception when check_violation then raise notice 'birth weight range enforced'; end $$;
do $$ begin update public.patients set apgar_5 = 11; raise exception 'APGAR ACCEPTED'; exception when check_violation then raise notice 'APGAR range enforced'; end $$;
do $$ begin update public.patients set delivery_mode = 'C-section'; raise exception 'MODE ACCEPTED'; exception when check_violation then raise notice 'delivery mode list enforced'; end $$;
do $$ begin update public.patients set mother_blood_group = 'Z+'; raise exception 'GROUP ACCEPTED'; exception when check_violation then raise notice 'mother blood group list enforced'; end $$;
reset role;
