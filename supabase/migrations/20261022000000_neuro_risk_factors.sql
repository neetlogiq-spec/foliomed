-- AAP 2022 neurotoxicity risk factors per baby (selects the "with risk
-- factors" threshold curves). NULL = not yet assessed (the app then won't
-- apply AAP thresholds); empty array = assessed, none present.

alter table public.patients
  add column if not exists neuro_risk_factors text[];

do $$ begin
  alter table public.patients add constraint patients_neuro_risk_check check (
    neuro_risk_factors is null
    or neuro_risk_factors <@ array['isoimmune', 'g6pd', 'otherHaemolysis',
                                   'sepsis', 'instability', 'lowAlbumin']::text[]);
exception when duplicate_object then null; end $$;
