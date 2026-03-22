import { createClient } from "@/lib/supabase/server";

export async function logAudit(
  action: string,
  entityType: string,
  entityId: string,
  metadata?: Record<string, unknown>
) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data: profile } = await supabase
      .from("profiles")
      .select("department_id")
      .eq("id", user.id)
      .single();

    await supabase.from("audit_logs").insert({
      action,
      entity_type: entityType,
      entity_id: entityId,
      performed_by: user.id,
      department_id: profile?.department_id || null,
      metadata: metadata || null,
    });
  } catch {
    // Silent fail — audit logging should never break the main flow
  }
}
