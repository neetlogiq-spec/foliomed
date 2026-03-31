"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { ActionResult } from "@/types/action";

export async function createHandoverNote(data: {
  handover_date: string;
  shift?: string;
  patients_summary?: string;
  pending_tasks?: string;
  critical_alerts?: string;
  notes?: string;
}): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { data: profile } = await supabase
    .from("profiles")
    .select("department_id")
    .eq("id", user.id)
    .single();

  const { error } = await supabase.from("handover_notes").insert({
    department_id: profile?.department_id,
    from_user_id: user.id,
    handover_date: data.handover_date,
    shift: data.shift || null,
    patients_summary: data.patients_summary || null,
    pending_tasks: data.pending_tasks || null,
    critical_alerts: data.critical_alerts || null,
    notes: data.notes || null,
  });

  if (error) return { error: error.message };
  revalidatePath("/handover");
  return { success: true };
}

export async function acknowledgeHandover(handoverId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase
    .from("handover_notes")
    .update({ acknowledged: true })
    .eq("id", handoverId);

  if (error) return { error: error.message };
  revalidatePath("/handover");
  return { success: true };
}
