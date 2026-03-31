"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { ActionResult } from "@/types/action";

// ============ FEED POSTS ============

export async function createFeedPost(data: {
  type: string;
  title: string;
  body?: string;
  linked_patient_id?: string;
}): Promise<ActionResult> {
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

export async function addComment(postId: string, body: string): Promise<ActionResult> {
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

