import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import Link from "next/link";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, branch, full_name")
    .eq("id", user.id)
    .single();

  // Fetch real counts in parallel
  const [
    admittedRes,
    totalPatientsRes,
    docsRes,
    feedRes,
    casesRes,
    handoversRes,
  ] = await Promise.all([
    supabase.from("patients").select("id", { count: "exact", head: true }).eq("status", "admitted"),
    supabase.from("patients").select("id", { count: "exact", head: true }),
    supabase.from("case_documents").select("id", { count: "exact", head: true }),
    supabase.from("department_feed").select("id", { count: "exact", head: true }),
    supabase.from("case_log").select("id", { count: "exact", head: true }),
    supabase.from("handover_notes").select("id", { count: "exact", head: true }),
  ]);

  const stats = [
    { label: "Admitted", value: admittedRes.count ?? 0, href: "/patients", color: "text-emerald-400", bg: "bg-emerald-500/10" },
    { label: "Total Patients", value: totalPatientsRes.count ?? 0, href: "/patients", color: "text-blue-400", bg: "bg-blue-500/10" },
    { label: "Documents", value: docsRes.count ?? 0, href: "/documents", color: "text-purple-400", bg: "bg-purple-500/10" },
    { label: "Feed Posts", value: feedRes.count ?? 0, href: "/feed", color: "text-amber-400", bg: "bg-amber-500/10" },
    { label: "Case Logs", value: casesRes.count ?? 0, href: "/logbook", color: "text-teal-400", bg: "bg-teal-500/10" },
    { label: "Handovers", value: handoversRes.count ?? 0, href: "/handover", color: "text-rose-400", bg: "bg-rose-500/10" },
  ];

  const quickActions = [
    { label: "Admit Patient", href: "/patients/new", icon: "➕" },
    { label: "View Patients", href: "/patients", icon: "👥" },
    { label: "Department Feed", href: "/feed", icon: "💬" },
    { label: "Case Documents", href: "/documents", icon: "📄" },
    { label: "Handover Notes", href: "/handover", icon: "🔄" },
    { label: "Logbook", href: "/logbook", icon: "📚" },
  ];

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Welcome */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-white">
          Welcome, {profile?.full_name?.split(" ")[0] || "Doctor"}
        </h1>
        <p className="text-sm text-slate-400 mt-1">
          {profile?.branch || "PG PMS"} · {profile?.role === "pg" ? "PG Resident" : profile?.role || "PG"}
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
        {stats.map((s) => (
          <Link key={s.label} href={s.href}>
            <Card className="bg-white/5 border-white/5 hover:border-white/10 transition-colors cursor-pointer">
              <CardContent className="pt-4 pb-3 text-center">
                <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-slate-500 mt-0.5">{s.label}</p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {/* Quick Actions */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm text-slate-400 uppercase tracking-wider">Quick Actions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
            {quickActions.map((action) => (
              <Link
                key={action.href}
                href={action.href}
                className="flex items-center gap-3 px-4 py-3 rounded-lg bg-white/[0.02] border border-white/5 hover:border-blue-500/20 hover:bg-white/[0.04] transition-all text-sm text-slate-300 hover:text-white"
              >
                <span className="text-lg">{action.icon}</span>
                {action.label}
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
