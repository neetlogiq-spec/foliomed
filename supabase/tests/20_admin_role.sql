\set ON_ERROR_STOP 1
grant all on all tables in schema public to authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.com','{"name":"A"}'),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.com','{"name":"B","role":"admin"}');
select email, role, role_confirmed from public.profiles order by email;
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
do $$ begin update public.profiles set role='admin' where id=auth.uid(); raise exception 'SELF-PROMOTION ALLOWED'; exception when insufficient_privilege then raise notice 'self-promotion to admin blocked'; end $$;
update public.profiles set role='nurse' where id=auth.uid();
select 'self doctor->nurse ok: '||role from public.profiles where id=auth.uid();
do $$ begin perform public.set_user_role('aaaaaaaa-0000-0000-0000-000000000001','admin'); raise exception 'NON-ADMIN GRANTED'; exception when insufficient_privilege then raise notice 'non-admin cannot grant roles'; end $$;
select public.confirm_my_role('nurse');
do $$ begin perform public.confirm_my_role('admin'); raise exception 'CONFIRM ADMIN ALLOWED'; exception when invalid_parameter_value then raise notice 'confirm_my_role rejects admin'; end $$;
reset role;
set request.jwt.claim.sub = '';
-- bootstrap first admin from SQL editor (no end-user JWT)
update public.profiles set role='admin', role_confirmed=true where email='a@x.com';
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.set_user_role('bbbbbbbb-0000-0000-0000-000000000002','doctor');
select 'admin set B to: '||role from public.profiles where email='b@x.com';
do $$ begin perform public.set_user_role('aaaaaaaa-0000-0000-0000-000000000001','doctor'); raise exception 'LAST ADMIN DEMOTED'; exception when insufficient_privilege then raise notice 'last admin cannot be demoted'; end $$;
select public.set_user_role('bbbbbbbb-0000-0000-0000-000000000002','admin');
select public.set_user_role('aaaaaaaa-0000-0000-0000-000000000001','doctor');
reset role;
select email, role, role_confirmed from public.profiles order by email;
