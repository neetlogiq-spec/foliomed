-- Supabase grants EXECUTE on new public functions to `anon` by default.
-- Anonymous visitors only need public_activity(); everything else is for
-- signed-in users (RLS policies call the helpers as `authenticated`).
revoke execute on function public.ward_member_count(text) from anon;
revoke execute on function public.is_ward_member(text)    from anon;
revoke execute on function public.patient_ward(uuid)      from anon;
revoke execute on function public.note_ward(uuid)         from anon;
revoke execute on function public.handle_new_user()       from anon, authenticated;
revoke execute on function public.handle_ward_deleted()   from anon, authenticated;
revoke execute on function public.handle_profile_deleted() from anon, authenticated;
