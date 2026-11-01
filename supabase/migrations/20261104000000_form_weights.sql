-- Weights from forms for any age: the weights table took newborn weights
-- only (300–8000 g); widen it so a form's vital signs record a child's
-- weight too. Newborn charts are unaffected.

alter table public.weights drop constraint if exists weights_grams_check;
alter table public.weights add constraint weights_grams_check check (grams between 300 and 250000);

create or replace function public.save_patient_form(
  p_patient uuid, p_key text, p_name text, p_version integer, p_definition jsonb, p_answers jsonb,
  p_summary text, p_abnormal integer default 0, p_vitals jsonb default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_ward text := public._med_ward(p_patient, false);
  v_name text := public._my_name();
  v_id uuid;
  v_v jsonb := coalesce(p_vitals, '{}'::jsonb);
  v_rr numeric := public._vital(v_v, 'rr', 0, 150);
  v_spo2 numeric := public._vital(v_v, 'spo2', 40, 100);
  v_hr numeric := public._vital(v_v, 'hr', 0, 300);
  v_sbp numeric := public._vital(v_v, 'sbp', 20, 300);
  v_dbp numeric := public._vital(v_v, 'dbp', 10, 250);
  v_temp numeric := public._vital(v_v, 'temp', 25, 45);
  v_wt numeric := public._vital(v_v, 'weight', 0.3, 250);
begin
  insert into public.patient_forms (patient_id, ward_id, template_key, template_name, template_version, definition,
                                    answers, summary, abnormal_count, created_by, created_by_name)
  values (p_patient, v_ward, p_key, trim(p_name), coalesce(p_version, 1), p_definition, p_answers, trim(p_summary),
          greatest(coalesce(p_abnormal, 0), 0), auth.uid(), v_name)
  returning id into v_id;
  perform public._patient_event_note(p_patient, v_ward, 'Form', trim(p_summary));
  if coalesce(v_rr, v_spo2, v_hr, v_sbp, v_dbp, v_temp) is not null then
    insert into public.observations (patient_id, ward_id, taken_at, resp_rate, spo2, heart_rate, systolic_bp,
                                     diastolic_bp, temp_c, note)
    values (p_patient, v_ward, now(), round(v_rr), round(v_spo2), round(v_hr), round(v_sbp), round(v_dbp),
            round(v_temp, 1), left(trim(p_name), 300));
  end if;
  if v_wt is not null then
    insert into public.weights (patient_id, ward_id, measured_at, grams) values (p_patient, v_ward, now(), round(v_wt * 1000));
  end if;
  return v_id;
end;
$$;
