"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { ActionResult } from "@/types/action";

export async function createTemplate(
  name: string,
  category: string,
  description: string,
  content: { blocks: unknown[] },
  isGlobal: boolean
): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { data: profile } = await supabase
    .from("profiles")
    .select("department_id")
    .eq("id", user.id)
    .single();

  const { error } = await supabase.from("document_templates").insert({
    name,
    description: description || null,
    content,
    category,
    department_id: profile?.department_id || null,
    created_by: user.id,
    is_global: isGlobal,
  });

  if (error) return { error: error.message };
  revalidatePath("/templates");
  return { success: true };
}

export async function deleteTemplate(templateId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("document_templates")
    .delete()
    .eq("id", templateId);

  if (error) return { error: error.message };
  revalidatePath("/templates");
  return { success: true };
}
