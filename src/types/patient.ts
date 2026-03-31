export type PatientStatus = "admitted" | "discharged" | "lama" | "referred" | "expired";
export type PatientSex = "male" | "female" | "other";
export type PatientVisibility = "private" | "department";

export interface Patient {
  id: string;
  ip_number: string;
  first_name: string;
  last_name: string | null;
  date_of_birth: string | null;
  age_days: number | null;
  sex: PatientSex | null;
  weight_kg: number | null;
  height_cm: number | null;
  head_circumference: number | null;
  gestational_age_weeks: number | null;
  birth_weight_kg: number | null;
  apgar_1min: number | null;
  apgar_5min: number | null;
  immunization_status: string | null;
  mother_name: string | null;
  father_name: string | null;
  guardian_contact: string | null;
  address: string | null;
  ward: string | null;
  bed_number: string | null;
  unit: string | null;
  admission_date: string | null;
  discharge_date: string | null;
  diagnosis: string | null;
  is_stable: boolean;
  status: PatientStatus;
  tags: string[];
  primary_pg_id: string | null;
  department_id: string | null;
  consent_for_teaching: boolean;
  visibility: PatientVisibility;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export const CASE_TAGS: { value: string; label: string; color: string; icon: string }[] = [
  { value: "interesting", label: "Interesting", color: "text-amber-400 bg-amber-500/10", icon: "⭐" },
  { value: "suggested", label: "Suggested", color: "text-blue-400 bg-blue-500/10", icon: "💡" },
  { value: "review", label: "Review", color: "text-purple-400 bg-purple-500/10", icon: "🔍" },
  { value: "rare", label: "Rare Case", color: "text-pink-400 bg-pink-500/10", icon: "💎" },
  { value: "teaching", label: "Teaching", color: "text-emerald-400 bg-emerald-500/10", icon: "📖" },
  { value: "critical", label: "Critical", color: "text-red-400 bg-red-500/10", icon: "🚨" },
  { value: "follow_up", label: "Follow-up", color: "text-orange-400 bg-orange-500/10", icon: "🔄" },
  { value: "research", label: "Research", color: "text-cyan-400 bg-cyan-500/10", icon: "🔬" },
  { value: "discussion", label: "Discussion", color: "text-indigo-400 bg-indigo-500/10", icon: "💬" },
  { value: "long_stay", label: "Long Stay", color: "text-slate-400 bg-slate-500/10", icon: "🏥" },
  { value: "complicated", label: "Complicated", color: "text-rose-400 bg-rose-500/10", icon: "⚠️" },
  { value: "resolved", label: "Resolved", color: "text-green-400 bg-green-500/10", icon: "✅" },
];

export const PATIENT_STATUS_CONFIG: Record<
  PatientStatus,
  { label: string; color: string; dotColor: string }
> = {
  admitted: {
    label: "Admitted",
    color: "bg-emerald-500/15 text-emerald-400 border-emerald-500/20",
    dotColor: "bg-emerald-400",
  },
  discharged: {
    label: "Discharged",
    color: "bg-blue-500/15 text-blue-400 border-blue-500/20",
    dotColor: "bg-blue-400",
  },
  lama: {
    label: "LAMA",
    color: "bg-amber-500/15 text-amber-400 border-amber-500/20",
    dotColor: "bg-amber-400",
  },
  referred: {
    label: "Referred",
    color: "bg-purple-500/15 text-purple-400 border-purple-500/20",
    dotColor: "bg-purple-400",
  },
  expired: {
    label: "Expired",
    color: "bg-red-500/15 text-red-400 border-red-500/20",
    dotColor: "bg-red-400",
  },
};

// Valid status transitions
export const STATUS_TRANSITIONS: Record<PatientStatus, PatientStatus[]> = {
  admitted: ["discharged", "lama", "referred", "expired"],
  discharged: [],
  lama: [],
  referred: [],
  expired: [],
};

/**
 * Subset of Patient used on the list page — matches the partial SELECT query.
 * Includes the `profiles` join for the assigned PG name.
 */
export type PatientListRow = Pick<
  Patient,
  | "id" | "ip_number" | "first_name" | "last_name" | "sex"
  | "date_of_birth" | "age_days" | "ward" | "bed_number" | "unit"
  | "status" | "admission_date" | "primary_pg_id" | "created_at"
  | "is_stable" | "diagnosis" | "tags"
> & {
  profiles?: { full_name?: string } | { full_name?: string }[];
};

// Form schema fields for patient registration
export interface PatientFormData {
  ip_number: string;
  first_name: string;
  last_name?: string;
  date_of_birth?: string;
  sex?: PatientSex;
  weight_kg?: number;
  height_cm?: number;
  head_circumference?: number;
  gestational_age_weeks?: number;
  birth_weight_kg?: number;
  apgar_1min?: number;
  apgar_5min?: number;
  immunization_status?: string;
  mother_name?: string;
  father_name?: string;
  guardian_contact?: string;
  address?: string;
  ward?: string;
  bed_number?: string;
  unit?: string;
  admission_date?: string;
  diagnosis?: string;
  is_stable?: boolean;
  consent_for_teaching?: boolean;
  visibility?: PatientVisibility;
}
