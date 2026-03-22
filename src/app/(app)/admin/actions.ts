"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function updateUserRole(userId: string, role: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  // Check if current user is hod or admin
  const { data: myProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!myProfile || !["hod", "senior_consultant"].includes(myProfile.role)) {
    return { error: "Only HOD or Senior Consultants can change roles" };
  }

  const { error } = await supabase
    .from("profiles")
    .update({ role, updated_at: new Date().toISOString() })
    .eq("id", userId);

  if (error) return { error: error.message };
  revalidatePath("/admin");
  return { success: true };
}

export async function toggleUserActive(userId: string, isActive: boolean) {
  const supabase = await createClient();
  const { error } = await supabase
    .from("profiles")
    .update({ is_active: isActive, updated_at: new Date().toISOString() })
    .eq("id", userId);

  if (error) return { error: error.message };
  revalidatePath("/admin");
  return { success: true };
}
