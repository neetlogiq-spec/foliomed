-- Follow-up to 20261019010000: Postgres grants EXECUTE on every new
-- function to PUBLIC (all roles), so revoking from `anon` alone was a
-- no-op. Revoke from PUBLIC and grant back only to signed-in users.
revoke execute on function public.ward_member_count(text) from public, anon;
revoke execute on function public.is_ward_member(text)    from public, anon;
revoke execute on function public.patient_ward(uuid)      from public, anon;
revoke execute on function public.note_ward(uuid)         from public, anon;
grant  execute on function public.ward_member_count(text) to authenticated;
grant  execute on function public.is_ward_member(text)    to authenticated;
grant  execute on function public.patient_ward(uuid)      to authenticated;
grant  execute on function public.note_ward(uuid)         to authenticated;

-- Trigger-only functions: nobody should call these directly.
revoke execute on function public.handle_new_user()        from public, anon, authenticated;
revoke execute on function public.handle_ward_deleted()    from public, anon, authenticated;
revoke execute on function public.handle_profile_deleted() from public, anon, authenticated;
revoke execute on function public.touch_updated_at()       from public, anon, authenticated;
