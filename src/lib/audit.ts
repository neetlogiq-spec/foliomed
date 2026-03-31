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
  } catch (err) {
    // Audit logging must never break the main flow, but failures should be
    // visible in server logs so they can be investigated.
    process.stderr.write(`[audit] Failed to log ${action} on ${entityType}:${entityId} — ${err instanceof Error ? err.message : String(err)}\n`);
  }
}
