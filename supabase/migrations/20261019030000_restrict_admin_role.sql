-- Restrict the admin role.
--
-- Before: role came from sign-up metadata and profiles were self-editable,
-- so anyone could make themselves admin.
-- After:
--   * new accounts are doctors until they pick doctor/nurse once
--     (role_confirmed); "admin" can never be self-assigned
--   * a user may switch themselves between doctor and nurse
--   * only an admin can grant/revoke roles, via set_user_role()
--   * the last remaining admin cannot be demoted
--   * bootstrap the first admin from the SQL editor (runs as postgres):
--       update public.profiles set role = 'admin', role_confirmed = true
--       where email = 'you@example.com';

alter table public.profiles
  add column if not exists role_confirmed boolean not null default false;

create or replace function public.is_admin(p_user uuid default auth.uid())
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = p_user and role = 'admin'
  );
$$;

-- New users: never admin from metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  meta     jsonb := coalesce(new.raw_user_meta_data, '{}');
  v_role   text  := coalesce(meta ->> 'role', 'doctor');
  v_ward   text  := coalesce(meta ->> 'ward_id', '');
  v_name   text  := coalesce(
                      nullif(meta ->> 'name', ''),
                      nullif(meta ->> 'full_name', ''),
                      split_part(coalesce(new.email, 'User'), '@', 1));
begin
  if v_role not in ('doctor', 'nurse') then
    v_role := 'doctor';
  end if;
  insert into public.profiles (id, name, email, role, ward_id, ward_ids, avatar_url)
  values (
    new.id, v_name, coalesce(new.email, ''), v_role, v_ward,
    case when v_ward = '' then '{}'::text[] else array[v_ward] end,
    coalesce(meta ->> 'avatar_url', meta ->> 'picture')
  )
  on conflict (id) do nothing;
  perform public.bump_metric('user', 'New account');
  return new;
end;
$$;

-- Guard every role change.
create or replace function public.guard_profile_role()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
begin
  if new.role is not distinct from old.role then
    return new;
  end if;
  -- SQL editor / service role (no end-user JWT): trusted.
  if v_caller is null then
    return new;
  end if;
  -- set_user_role() marks its own (already authorised) changes.
  if current_setting('foliomed.role_change_authorised', true) = 'on' then
    return new;
  end if;
  -- Self-service: doctor <-> nurse only.
  if v_caller = old.id
     and old.role in ('doctor', 'nurse')
     and new.role in ('doctor', 'nurse') then
    return new;
  end if;
  raise exception 'Only an admin can change this role'
    using errcode = '42501';
end;
$$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
  before update of role on public.profiles
  for each row execute function public.guard_profile_role();

-- Admin-only role management (and the user's own one-time choice).
create or replace function public.set_user_role(p_user uuid, p_role text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_current text;
begin
  if v_caller is null then raise exception 'not signed in'; end if;
  if p_role not in ('doctor', 'nurse', 'admin') then
    raise exception 'unknown role %', p_role using errcode = '22023';
  end if;
  if not public.is_admin(v_caller) then
    raise exception 'admin only' using errcode = '42501';
  end if;
  select role into v_current from public.profiles where id = p_user for update;
  if v_current is null then
    raise exception 'no such user' using errcode = 'P0002';
  end if;
  if v_current = 'admin' and p_role <> 'admin'
     and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'cannot demote the last admin' using errcode = '42501';
  end if;
  perform set_config('foliomed.role_change_authorised', 'on', true);
  update public.profiles
     set role = p_role, role_confirmed = true
   where id = p_user;
  perform set_config('foliomed.role_change_authorised', 'off', true);
end;
$$;

-- A new user's one-time doctor/nurse choice.
create or replace function public.confirm_my_role(p_role text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_role not in ('doctor', 'nurse') then
    raise exception 'choose doctor or nurse' using errcode = '22023';
  end if;
  update public.profiles
     set role = case when role = 'admin' then role else p_role end,
         role_confirmed = true
   where id = auth.uid();
end;
$$;

revoke execute on function public.is_admin(uuid)            from public, anon;
revoke execute on function public.set_user_role(uuid, text) from public, anon;
revoke execute on function public.confirm_my_role(text)     from public, anon;
revoke execute on function public.guard_profile_role()      from public, anon, authenticated;
grant  execute on function public.is_admin(uuid)            to authenticated;
grant  execute on function public.set_user_role(uuid, text) to authenticated;
grant  execute on function public.confirm_my_role(text)     to authenticated;
