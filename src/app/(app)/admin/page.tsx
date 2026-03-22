import { createClient } from "@/lib/supabase/server";
import { AdminClient } from "./AdminClient";

export default async function AdminPage() {
  const supabase = await createClient();

  const [usersRes, auditRes, deptsRes] = await Promise.all([
    supabase.from("profiles").select("*").order("created_at", { ascending: false }),
    supabase.from("audit_logs").select(`*, profiles:performed_by ( full_name )`).order("created_at", { ascending: false }).limit(50),
    supabase.from("departments").select("*").order("name"),
  ]);

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Admin</h1>
        <p className="text-sm text-slate-400 mt-1">User management, audit logs, and department configuration</p>
      </div>
      <AdminClient
        users={usersRes.data ?? []}
        auditLogs={auditRes.data ?? []}
        departments={deptsRes.data ?? []}
      />
    </div>
  );
}
