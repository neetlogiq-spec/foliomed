export interface Vital {
  id: string;
  patient_id: string;
  recorded_by: string | null;
  recorded_at: string;
  heart_rate: number | null;
  respiratory_rate: number | null;
  temperature_c: number | null;
  systolic_bp: number | null;
  diastolic_bp: number | null;
  spo2_percent: number | null;
  weight_kg: number | null;
  is_abnormal: boolean;
}

export type InvestigationCategory =
  | "hematology"
  | "biochemistry"
  | "microbiology"
  | "imaging"
  | "other";

export interface Investigation {
  id: string;
  patient_id: string;
  test_name: string;
  category: InvestigationCategory | null;
  value: string | null;
  unit: string | null;
  reference_range: string | null;
  is_abnormal: boolean;
  is_critical: boolean;
  report_file_url: string | null;
  ordered_by: string | null;
  reported_at: string | null;
  created_at: string;
}

export type MedicationStatus = "active" | "stopped" | "on_hold";

export interface Medication {
  id: string;
  patient_id: string;
  drug_name: string;
  dose_mg_kg: number | null;
  dose_calculated: number | null;
  route: string | null;
  frequency: string | null;
  duration: string | null;
  start_date: string | null;
  end_date: string | null;
  status: MedicationStatus;
  prescribed_by: string | null;
  created_at: string;
}

export interface ProgressNote {
  id: string;
  patient_id: string;
  note_date: string;
  subjective: string | null;
  objective: string | null;
  assessment: string | null;
  plan: string | null;
  fluid_input_ml: number | null;
  fluid_output_ml: number | null;
  written_by: string | null;
  created_at: string;
  updated_at: string;
}

export const INVESTIGATION_CATEGORIES: {
  value: InvestigationCategory;
  label: string;
}[] = [
  { value: "hematology", label: "Hematology" },
  { value: "biochemistry", label: "Biochemistry" },
  { value: "microbiology", label: "Microbiology" },
  { value: "imaging", label: "Imaging" },
  { value: "other", label: "Other" },
];

export const MEDICATION_STATUS_CONFIG: Record<
  MedicationStatus,
  { label: string; color: string }
> = {
  active: { label: "Active", color: "bg-emerald-500/15 text-emerald-400 border-emerald-500/20" },
  stopped: { label: "Stopped", color: "bg-red-500/15 text-red-400 border-red-500/20" },
  on_hold: { label: "On Hold", color: "bg-amber-500/15 text-amber-400 border-amber-500/20" },
};
