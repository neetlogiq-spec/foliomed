"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { ActionResult } from "@/types/action";

export async function updateProfile(data: {
  full_name?: string;
  branch?: string;
  year_of_pg?: number;
}): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const updates: Record<string, unknown> = {
    branch: data.branch || null,
    year_of_pg: data.year_of_pg ?? null,
    updated_at: new Date().toISOString(),
  };
  if (data.full_name) updates.full_name = data.full_name;

  const { error } = await supabase
    .from("profiles")
    .update(updates)
    .eq("id", user.id);

  if (error) return { error: error.message };
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}
