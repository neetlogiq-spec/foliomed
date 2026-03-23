export type Role = "pg" | "intern" | "hod" | "senior_consultant" | "consultant" | "senior_pg" | "nurse" | "admin";

export const ROLES = {
  PG: "pg" as Role,
  INTERN: "intern" as Role,
  ADMIN: "admin" as Role,
  HOD: "hod" as Role,
  SENIOR_CONSULTANT: "senior_consultant" as Role,
  CONSULTANT: "consultant" as Role,
  SENIOR_PG: "senior_pg" as Role,
  NURSE: "nurse" as Role,
};

const ADMIN_ROLES: Role[] = ["admin", "hod"];

export const CAN = {
  CREATE_PATIENT: (role: Role) => ["pg", "senior_pg", "intern"].includes(role),
  EDIT_PATIENT: (role: Role) => ["pg", "senior_pg", "intern"].includes(role),
  CREATE_CASE_DOC: (role: Role) => ["pg", "senior_pg"].includes(role),
  ADD_VITALS: (role: Role) => ["pg", "senior_pg", "intern", "nurse"].includes(role),
  ADD_INVESTIGATION: (role: Role) => ["pg", "senior_pg"].includes(role),
  ADD_MEDICATION: (role: Role) => ["pg", "senior_pg"].includes(role),
  CREATE_FEED_POST: (role: Role) => role !== "nurse",
  COMMENT: (_role: Role) => true,
  VIEW_PATIENTS: (_role: Role) => true,
  VIEW_FEED: (_role: Role) => true,
  ADMIN_ACCESS: (role: Role) => ADMIN_ROLES.includes(role),
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

