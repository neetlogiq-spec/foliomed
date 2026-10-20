-- Newborn discharge checklist: the items staff tick by hand (Vitamin K,
-- birth vaccines, feeding, counselling, follow-up). Items FolioMed can
-- work out from recorded data (investigations, OAE, bilirubin, weight,
-- phototherapy) are computed in the app and not stored here.
--
-- One row per ticked item; unticking deletes it. Who ticked it and when
-- are stamped by the server. Rows are keyed by patient, so they need no
-- change on transfer.

create table if not exists public.discharge_checks (
  patient_id    uuid not null references public.patients (id) on delete cascade,
  item          text not null check (item ~ '^[a-z0-9_]{1,40}$'),
  detail        text check (detail is null or length(detail) <= 200),
  done_at       timestamptz not null default now(),
  done_by       uuid references public.profiles (id) on delete set null,
  done_by_name  text,
  primary key (patient_id, item)
);

alter table public.discharge_checks enable row level security;

drop policy if exists discharge_checks_all on public.discharge_checks;
create policy discharge_checks_all on public.discharge_checks
  for all to authenticated
  using (public.is_ward_member(public.patient_ward(patient_id)))
  with check (public.is_ward_member(public.patient_ward(patient_id)));

create or replace function public.stamp_discharge_check()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.done_at := now();
  new.done_by := auth.uid();
  select name into new.done_by_name from public.profiles where id = auth.uid();
  new.detail := nullif(trim(coalesce(new.detail, '')), '');
  return new;
end;
$$;

drop trigger if exists discharge_checks_stamp on public.discharge_checks;
create trigger discharge_checks_stamp
  before insert or update on public.discharge_checks
  for each row execute function public.stamp_discharge_check();

grant select, insert, update, delete on public.discharge_checks to authenticated;
revoke execute on function public.stamp_discharge_check() from public, anon, authenticated;

do $$ begin
  alter publication supabase_realtime add table public.discharge_checks;
exception when duplicate_object then null; end $$;
