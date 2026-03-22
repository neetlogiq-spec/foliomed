"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// ============ VITALS ============

export async function addVitals(patientId: string, data: {
  heart_rate?: number;
  respiratory_rate?: number;
  temperature_c?: number;
  systolic_bp?: number;
  diastolic_bp?: number;
  spo2_percent?: number;
  weight_kg?: number;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const isAbnormal =
    (data.heart_rate != null && (data.heart_rate < 60 || data.heart_rate > 180)) ||
    (data.spo2_percent != null && data.spo2_percent < 90) ||
    (data.temperature_c != null && (data.temperature_c < 36 || data.temperature_c > 39));

  const { error } = await supabase.from("vitals").insert({
    patient_id: patientId,
    recorded_by: user.id,
    ...data,
    is_abnormal: isAbnormal,
  });

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}

// ============ INVESTIGATIONS ============

export async function addInvestigation(patientId: string, data: {
  test_name: string;
  category?: string;
  value?: string;
  unit?: string;
  reference_range?: string;
  is_abnormal?: boolean;
  is_critical?: boolean;
  reported_at?: string;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase.from("investigations").insert({
    patient_id: patientId,
    ordered_by: user.id,
    ...data,
  });

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}

// ============ MEDICATIONS ============

export async function addMedication(patientId: string, data: {
  drug_name: string;
  dose_mg_kg?: number;
  dose_calculated?: number;
  route?: string;
  frequency?: string;
  duration?: string;
  start_date?: string;
  end_date?: string;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase.from("medications").insert({
    patient_id: patientId,
    prescribed_by: user.id,
    status: "active",
    ...data,
  });

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}

export async function updateMedicationStatus(
  medicationId: string,
  patientId: string,
  status: "active" | "stopped" | "on_hold"
) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase
    .from("medications")
    .update({ status })
    .eq("id", medicationId);

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}

// ============ PROGRESS NOTES ============

export async function addProgressNote(patientId: string, data: {
  note_date: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
  fluid_input_ml?: number;
  fluid_output_ml?: number;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase.from("progress_notes").insert({
    patient_id: patientId,
    written_by: user.id,
    ...data,
  });

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}
