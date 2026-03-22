export type Role = "pg" | "intern";

// Future roles reserved but not used in v1
export type FutureRole =
  | "hod"
  | "senior_consultant"
  | "consultant"
  | "senior_pg"
  | "nurse";

export const ROLES = {
  PG: "pg" as Role,
  INTERN: "intern" as Role,
};

export const CAN = {
  CREATE_PATIENT: (role: Role) => role === "pg",
  EDIT_PATIENT: (role: Role) => role === "pg",
  CREATE_CASE_DOC: (role: Role) => role === "pg",
  ADD_VITALS: (role: Role) => role === "pg",
  ADD_INVESTIGATION: (role: Role) => role === "pg",
  ADD_MEDICATION: (role: Role) => role === "pg",
  CREATE_FEED_POST: (role: Role) => role === "pg",
  COMMENT: (role: Role) => role === "pg",
  VIEW_PATIENTS: (_role: Role) => true,
  VIEW_FEED: (_role: Role) => true,
} as const;

export interface Profile {
  id: string;
  full_name: string;
  email: string;
  avatar_url: string | null;
  role: Role;
  branch: string | null;
  department_id: string | null;
  year_of_pg: number | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export const BRANCHES = [
  "Paediatrics",
  "General Medicine",
  "General Surgery",
  "Orthopaedics",
  "Obstetrics & Gynaecology",
  "Ophthalmology",
  "ENT",
  "Dermatology",
  "Psychiatry",
  "Anaesthesiology",
  "Radiology",
  "Pathology",
  "Community Medicine",
  "Pulmonology",
  "Cardiology",
  "Nephrology",
  "Neurology",
  "Gastroenterology",
  "Neonatology",
  "Emergency Medicine",
] as const;
