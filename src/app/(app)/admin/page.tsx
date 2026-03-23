import { createClient } from "@/lib/supabase/server";
import { AdminClient } from "./AdminClient";
import { redirect } from "next/navigation";

export default async function AdminPage() {
  const supabase = await createClient();

  // Check if current user is admin or hod
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile || !["admin", "hod"].includes(profile.role)) {
    redirect("/dashboard");
  }

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
