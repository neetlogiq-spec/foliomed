"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function addCaseLogEntry(data: {
  patient_id: string;
  diagnosis: string;
  procedure_done?: string;
  learning_points?: string;
  is_interesting?: boolean;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { data: profile } = await supabase
    .from("profiles")
    .select("department_id")
    .eq("id", user.id)
    .single();

  const { error } = await supabase.from("case_log").insert({
    user_id: user.id,
    patient_id: data.patient_id,
    department_id: profile?.department_id,
    diagnosis: data.diagnosis,
    procedure_done: data.procedure_done || null,
    learning_points: data.learning_points || null,
    is_interesting: data.is_interesting ?? false,
    logged_at: new Date().toISOString(),
  });

  if (error) return { error: error.message };
  revalidatePath("/logbook");
  return { success: true };
}
