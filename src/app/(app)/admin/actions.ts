"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

async function checkAdminAccess() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated", supabase: null, user: null };

  const { data: myProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!myProfile || !["admin", "hod"].includes(myProfile.role)) {
    return { error: "Only Admin or HOD can perform this action", supabase: null, user: null };
  }

  return { error: null, supabase, user };
}

export async function updateUserRole(userId: string, role: string) {
  const { error, supabase } = await checkAdminAccess();
  if (error || !supabase) return { error: error || "Error" };

  const { error: updateError } = await supabase
    .from("profiles")
    .update({ role, updated_at: new Date().toISOString() })
    .eq("id", userId);

  if (updateError) return { error: updateError.message };
  revalidatePath("/admin");
  return { success: true };
}

export async function updateUserDepartment(userId: string, departmentId: string) {
  const { error, supabase } = await checkAdminAccess();
  if (error || !supabase) return { error: error || "Error" };

  const { error: updateError } = await supabase
    .from("profiles")
    .update({ department_id: departmentId || null, updated_at: new Date().toISOString() })
    .eq("id", userId);

  if (updateError) return { error: updateError.message };
  revalidatePath("/admin");
  return { success: true };
}

export async function toggleUserActive(userId: string, isActive: boolean) {
  const { error, supabase } = await checkAdminAccess();
  if (error || !supabase) return { error: error || "Error" };

  const { error: updateError } = await supabase
    .from("profiles")
    .update({ is_active: isActive, updated_at: new Date().toISOString() })
    .eq("id", userId);

  if (updateError) return { error: updateError.message };
  revalidatePath("/admin");
  return { success: true };
}

