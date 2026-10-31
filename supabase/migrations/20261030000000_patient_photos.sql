-- Clinical photos (rash, wound, X-ray) on the patient record.
--
-- * Files live in the private bucket "clinical-photos" at
--   <patient_id>/<photo_id>.jpg (+ <photo_id>_t.jpg thumbnail). Only
--   members of the patient's CURRENT ward can read, upload or delete
--   them (the path's patient id is checked against patient_ward(), so
--   access follows the patient on transfer). The app shows them through
--   short-lived signed links and never saves them to the phone's gallery.
-- * The app shrinks photos before upload (long side 1600 px, JPEG ~70%;
--   "high detail" 2560 px for X-rays); the bucket refuses anything over
--   3 MB or not JPEG as a backstop.
-- * patient_photos: one row per photo (caption, size, consent stamped).
--   add_patient_photo() records it and logs a timeline note.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clinical-photos', 'clinical-photos', false, 3 * 1024 * 1024, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists clinical_photos_read on storage.objects;
create policy clinical_photos_read on storage.objects for select to authenticated
  using (bucket_id = 'clinical-photos'
         and public.is_ward_member(public.patient_ward(((storage.foldername(name))[1])::uuid)));
drop policy if exists clinical_photos_upload on storage.objects;
create policy clinical_photos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'clinical-photos'
              and public.is_ward_member(public.patient_ward(((storage.foldername(name))[1])::uuid)));
drop policy if exists clinical_photos_delete on storage.objects;
create policy clinical_photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'clinical-photos'
         and public.is_ward_member(public.patient_ward(((storage.foldername(name))[1])::uuid)));

create table if not exists public.patient_photos (
  id               uuid primary key,
  patient_id       uuid not null references public.patients (id) on delete cascade,
  path             text not null unique,
  thumb_path       text,
  caption          text check (caption is null or length(caption) <= 200),
  width            int check (width between 1 and 10000),
  height           int check (height between 1 and 10000),
  bytes            int check (bytes between 1 and 3145728),
  high_detail      boolean not null default false,
  consent          boolean not null check (consent),
  created_by       uuid references public.profiles (id) on delete set null,
  created_by_name  text,
  created_at       timestamptz not null default now(),
  check (path like patient_id::text || '/%'),
  check (thumb_path is null or thumb_path like patient_id::text || '/%')
);
create index if not exists patient_photos_patient_idx on public.patient_photos (patient_id, created_at);

alter table public.patient_photos enable row level security;
drop policy if exists patient_photos_read on public.patient_photos;
create policy patient_photos_read on public.patient_photos for select to authenticated
  using (public.is_ward_member(public.patient_ward(patient_id)));
drop policy if exists patient_photos_delete on public.patient_photos;
create policy patient_photos_delete on public.patient_photos for delete to authenticated
  using (public.is_ward_member(public.patient_ward(patient_id)));
-- Added only through add_patient_photo().
grant select, delete on public.patient_photos to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.patient_photos;
exception when duplicate_object then null; end $$;

-- Records an uploaded photo (the app uploads the file first) and logs it
-- on the timeline. Consent must be confirmed.
create or replace function public.add_patient_photo(
  p_id uuid, p_patient uuid, p_path text, p_thumb_path text, p_caption text,
  p_width int, p_height int, p_bytes int, p_high_detail boolean, p_consent boolean)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text;
  v_active boolean;
  v_caption text := nullif(trim(coalesce(p_caption, '')), '');
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select ward_id, is_active into v_ward, v_active from public.patients where id = p_patient;
  if v_ward is null then raise exception 'no such patient' using errcode = 'P0002'; end if;
  if not public.is_ward_member(v_ward) then
    raise exception 'not a member of this ward' using errcode = '42501';
  end if;
  if not v_active then raise exception 'patient is discharged' using errcode = '22023'; end if;
  if not coalesce(p_consent, false) then
    raise exception 'consent must be confirmed' using errcode = '22023';
  end if;
  insert into public.patient_photos (id, patient_id, path, thumb_path, caption, width, height, bytes,
                                     high_detail, consent, created_by, created_by_name)
  values (p_id, p_patient, p_path, p_thumb_path, v_caption, p_width, p_height, p_bytes,
          coalesce(p_high_detail, false), true, auth.uid(), public._my_name());
  perform public._patient_event_note(p_patient, v_ward, 'Photo',
    'Photo added' || coalesce(': ' || v_caption, '') || '. Open the patient’s Photos to view.');
end;
$$;
revoke execute on function public.add_patient_photo(uuid, uuid, text, text, text, int, int, int, boolean, boolean)
  from public, anon;
grant execute on function public.add_patient_photo(uuid, uuid, text, text, text, int, int, int, boolean, boolean)
  to authenticated;
