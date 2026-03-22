"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// ============ FEED POSTS ============

export async function createFeedPost(data: {
  type: string;
  title: string;
  body?: string;
  linked_patient_id?: string;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { data: profile } = await supabase
    .from("profiles")
    .select("department_id")
    .eq("id", user.id)
    .single();

  const { error } = await supabase.from("department_feed").insert({
    department_id: profile?.department_id,
    author_id: user.id,
    type: data.type,
    title: data.title,
    body: data.body || null,
    linked_patient_id: data.linked_patient_id || null,
  });

  if (error) return { error: error.message };
  revalidatePath("/feed");
  return { success: true };
}

// ============ COMMENTS ============

export async function addComment(postId: string, body: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { error } = await supabase.from("comments").insert({
    post_id: postId,
    author_id: user.id,
    body,
  });

  if (error) return { error: error.message };
  revalidatePath("/feed");
  return { success: true };
}

// ============ HANDOVER NOTES ============

export async function createHandoverNote(data: {
  to_user_id?: string;
  handover_date: string;
  shift?: string;
  patients_summary?: string;
  pending_tasks?: string;
  critical_alerts?: string;
  notes?: string;
}) {
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
    to_user_id: data.to_user_id || null,
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

export async function acknowledgeHandover(handoverId: string) {
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

// ============ CASE LOG ============

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
