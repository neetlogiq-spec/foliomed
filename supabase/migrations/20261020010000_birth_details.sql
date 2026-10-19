-- Structured birth details for newborns, so the app can compose the usual
-- line: "TERM/MALE/AGA/LSCS (CPD) on 19/10/2026 at 10:19pm with birth
-- weight of 3.1kgs". Maturity (term/preterm) is derived from gestation in
-- the app, so it is not stored.

alter table public.patients
  add column if not exists birth_weight_g      integer,
  add column if not exists size_for_dates      text,
  add column if not exists delivery_mode       text,
  add column if not exists delivery_indication text,
  add column if not exists mother_blood_group  text,
  add column if not exists apgar_1             smallint,
  add column if not exists apgar_5             smallint,
  add column if not exists resuscitated        boolean;

do $$ begin
  alter table public.patients add constraint patients_birth_details_check check (
    (birth_weight_g is null or birth_weight_g between 300 and 7000)
    and (size_for_dates is null or size_for_dates in ('AGA', 'SGA', 'LGA'))
    and (delivery_mode is null or delivery_mode in ('NVD', 'LSCS', 'Vacuum', 'Forceps'))
    and (delivery_indication is null or length(delivery_indication) <= 120)
    and (mother_blood_group is null or mother_blood_group in
          ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'))
    and (apgar_1 is null or apgar_1 between 0 and 10)
    and (apgar_5 is null or apgar_5 between 0 and 10));
exception when duplicate_object then null; end $$;
