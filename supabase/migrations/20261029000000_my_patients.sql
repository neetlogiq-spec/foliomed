-- "My patients": per-person follows, consultant, and clinical tags.
--
-- * patient_follows: private to each person (only they see or change
--   theirs). A follow ends when the patient is discharged, or moves to a
--   ward the follower isn't in.
-- * patients.consultant: free text (the app suggests names already used
--   in the ward), filterable on the board.
-- * wards.tag_options: the ward's clinical tags (owner edits; a starter
--   list by default). patients.tags: any members set them per patient.

create table if not exists public.patient_follows (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  patient_id  uuid not null references public.patients (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, patient_id)
);
create index if not exists patient_follows_patient_idx on public.patient_follows (patient_id);

alter table public.patient_follows enable row level security;
drop policy if exists patient_follows_own on public.patient_follows;
create policy patient_follows_own on public.patient_follows for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_ward_member(public.patient_ward(patient_id)));
grant select, insert, delete on public.patient_follows to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.patient_follows;
exception when duplicate_object then null; end $$;

-- Follows end on discharge, and for people not in the new ward on transfer.
create or replace function public.patients_prune_follows()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not new.is_active and old.is_active then
    delete from public.patient_follows where patient_id = new.id;
  elsif new.ward_id is distinct from old.ward_id then
    delete from public.patient_follows f
     where f.patient_id = new.id
       and not exists (select 1 from public.wards w
                        where w.id = new.ward_id and f.user_id = any (w.member_ids));
  end if;
  return new;
end;
$$;
revoke execute on function public.patients_prune_follows() from public, anon, authenticated;

drop trigger if exists patients_prune_follows on public.patients;
create trigger patients_prune_follows
  after update of status, is_active, ward_id on public.patients
  for each row execute function public.patients_prune_follows();

-- Consultant and tags.
create or replace function public._max_text_length(p text[])
returns int
language sql immutable
as $$ select coalesce(max(length(t)), 0) from unnest(p) t $$;

alter table public.patients
  add column if not exists consultant text,
  add column if not exists tags text[] not null default '{}';

do $$ begin
  alter table public.patients add constraint patients_consultant_check
    check (consultant is null or length(consultant) between 1 and 80);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.patients add constraint patients_tags_check
    check (cardinality(tags) <= 12 and public._max_text_length(tags) <= 24);
exception when duplicate_object then null; end $$;

alter table public.wards
  add column if not exists tag_options text[] not null
    default array['NPO', 'Isolation', 'Fall risk', 'Allergy', 'Awaiting scan', 'Awaiting results', 'For discharge'];

do $$ begin
  alter table public.wards add constraint wards_tag_options_check
    check (cardinality(tag_options) <= 30 and public._max_text_length(tag_options) <= 24);
exception when duplicate_object then null; end $$;
