"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import type { PatientFormValues } from "@/lib/validations/patient";
import type { PatientStatus } from "@/types/patient";
import { logAudit } from "@/lib/audit";

export async function createPatient(data: PatientFormValues) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) throw new Error("Not authenticated");

  // Get user's profile for department
  const { data: profile } = await supabase
    .from("profiles")
    .select("department_id, role")
    .eq("id", user.id)
    .single();

  if (!profile || profile.role !== "pg") {
    throw new Error("Only PGs can create patients");
  }

  const { data: patient, error } = await supabase
    .from("patients")
    .insert({
      ...data,
      weight_kg: data.weight_kg || null,
      height_cm: data.height_cm || null,
      head_circumference: data.head_circumference || null,
      gestational_age_weeks: data.gestational_age_weeks || null,
      birth_weight_kg: data.birth_weight_kg || null,
      apgar_1min: data.apgar_1min || null,
      apgar_5min: data.apgar_5min || null,
      status: "admitted",
      primary_pg_id: user.id,
      department_id: profile.department_id,
      created_by: user.id,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") {
      return { error: "A patient with this MRD number already exists" };
    }
    return { error: error.message };
  }

  revalidatePath("/patients");
  await logAudit("patient_created", "patient", patient.id, { mrd: data.mrd_number });
  redirect(`/patients/${patient.id}`);
}

export async function updatePatientStatus(
  patientId: string,
  newStatus: PatientStatus
) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { error: "Not authenticated" };

  const updateData: Record<string, unknown> = {
    status: newStatus,
    updated_at: new Date().toISOString(),
  };

  if (newStatus === "discharged") {
    updateData.discharge_date = new Date().toISOString().split("T")[0];
  }

  const { error } = await supabase
    .from("patients")
    .update(updateData)
    .eq("id", patientId);

  if (error) return { error: error.message };

  revalidatePath(`/patients/${patientId}`);
  revalidatePath("/patients");
  await logAudit("status_changed", "patient", patientId, { new_status: newStatus });
  return { success: true };
}

export async function updatePatient(
  patientId: string,
  data: Partial<PatientFormValues>
) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase
    .from("patients")
    .update({
      ...data,
      updated_at: new Date().toISOString(),
    })
    .eq("id", patientId);

  if (error) return { error: error.message };

  revalidatePath(`/patients/${patientId}`);
  revalidatePath("/patients");
  return { success: true };
}

export async function updatePatientTags(patientId: string, tags: string[]) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase
    .from("patients")
    .update({ tags, updated_at: new Date().toISOString() })
    .eq("id", patientId);

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  revalidatePath("/patients");
  return { success: true };
}
