import { z } from "zod/v4";

export const patientFormSchema = z.object({
  mrd_number: z.string().min(1, "MRD number is required"),
  ip_number: z.string().optional(),
  first_name: z.string().min(1, "First name is required"),
  last_name: z.string().optional(),
  date_of_birth: z.string().optional(),
  sex: z.enum(["male", "female", "other"]).optional(),
  weight_kg: z.coerce.number().positive().optional(),
  height_cm: z.coerce.number().positive().optional(),
  head_circumference: z.coerce.number().positive().optional(),
  gestational_age_weeks: z.coerce.number().int().min(22).max(45).optional(),
  birth_weight_kg: z.coerce.number().positive().optional(),
  apgar_1min: z.coerce.number().int().min(0).max(10).optional(),
  apgar_5min: z.coerce.number().int().min(0).max(10).optional(),
  immunization_status: z.string().optional(),
  mother_name: z.string().optional(),
  father_name: z.string().optional(),
  guardian_contact: z.string().optional(),
  address: z.string().optional(),
  ward: z.string().optional(),
  bed_number: z.string().optional(),
  unit: z.string().optional(),
  admission_date: z.string().optional(),
  diagnosis: z.string().optional(),
  is_stable: z.boolean().optional(),
  consent_for_teaching: z.boolean().optional(),
  visibility: z.enum(["private", "department"]).optional(),
});

export type PatientFormValues = z.infer<typeof patientFormSchema>;
