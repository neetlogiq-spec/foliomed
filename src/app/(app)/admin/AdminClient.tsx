"use client";

import { useState, useTransition } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { updateUserRole, updateUserDepartment, toggleUserActive } from "./actions";
import { cn } from "@/lib/utils";

const ROLES = ["pg", "intern", "senior_pg", "consultant", "senior_consultant", "hod", "nurse", "admin"];

interface UserRow {
  id: string;
  full_name: string;
  email: string;
  role: string;
  branch: string | null;
  year_of_pg: number | null;
  is_active: boolean;
  department_id: string | null;
  created_at: string;
}

interface AuditRow {
  id: string;
  action: string;
  entity_type: string | null;
  entity_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  profiles?: { full_name: string } | null;
}

interface AdminClientProps {
  users: UserRow[];
  auditLogs: AuditRow[];
  departments: { id: string; name: string; hospital_name: string }[];
}

export function AdminClient({ users, auditLogs, departments }: AdminClientProps) {
  const [isPending, startTransition] = useTransition();
  const [tab, setTab] = useState<"users" | "audit" | "departments">("users");

  const handleRoleChange = (userId: string, role: string) => {
    startTransition(async () => {
      await updateUserRole(userId, role);
    });
  };

  const handleToggleActive = (userId: string, isActive: boolean) => {
    startTransition(async () => {
      await toggleUserActive(userId, isActive);
    });
  };

  const handleDepartmentChange = (userId: string, departmentId: string) => {
    startTransition(async () => {
      await updateUserDepartment(userId, departmentId);
    });
  };

  return (
    <div className="space-y-4">
      {/* Tabs */}
      <div className="flex gap-1 bg-white/5 border border-white/10 rounded-lg p-1">
        {(["users", "audit", "departments"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "px-4 py-1.5 rounded-md text-xs font-medium transition-colors capitalize",
              tab === t ? "bg-white/10 text-white" : "text-slate-400 hover:text-slate-200"
            )}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "users" && (
        <div className="space-y-2">
          <p className="text-xs text-slate-500">{users.length} users</p>
          {users.map((u) => (
            <Card key={u.id} className={cn("border-white/5", u.is_active ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
              <CardContent className="py-3 flex items-center justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-white truncate">{u.full_name}</p>
                  <p className="text-[10px] text-slate-500">{u.email}</p>
                  {u.branch && <span className="text-[10px] text-slate-400">{u.branch}</span>}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <select
                    value={u.role}
                    onChange={(e) => handleRoleChange(u.id, e.target.value)}
                    disabled={isPending}
                    className="rounded border border-white/10 bg-white/5 px-2 py-1 text-xs text-white"
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r} className="bg-slate-900">{r}</option>
                    ))}
                  </select>
                  <select
                    value={u.department_id || ""}
                    onChange={(e) => handleDepartmentChange(u.id, e.target.value)}
                    disabled={isPending}
                    className="rounded border border-white/10 bg-white/5 px-2 py-1 text-xs text-white"
                  >
                    <option value="" className="bg-slate-900">No Dept</option>
                    {departments.map((d) => (
                      <option key={d.id} value={d.id} className="bg-slate-900">{d.name}</option>
                    ))}
                  </select>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleToggleActive(u.id, !u.is_active)}
                    disabled={isPending}
                    className={cn(
                      "text-[10px] h-7 border-white/10",
                      u.is_active ? "text-red-400 hover:text-red-300" : "text-emerald-400 hover:text-emerald-300"
                    )}
                  >
                    {u.is_active ? "Deactivate" : "Activate"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {tab === "audit" && (
        <div className="space-y-1">
          <p className="text-xs text-slate-500">Recent audit logs</p>
          {auditLogs.length === 0 ? (
            <p className="text-sm text-slate-500 py-8 text-center">No audit logs yet</p>
          ) : (
            auditLogs.map((log) => (
              <div key={log.id} className="flex items-center gap-3 px-3 py-2 rounded bg-white/[0.02] border border-white/5 text-xs">
                <span className="text-white font-medium">{log.action}</span>
                <span className="text-slate-500">{log.entity_type}</span>
                {log.profiles && <span className="text-slate-400">by {(log.profiles as { full_name: string }).full_name}</span>}
                <span className="text-[10px] text-slate-600 ml-auto">
                  {new Date(log.created_at).toLocaleString("en-IN", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                </span>
              </div>
            ))
          )}
        </div>
      )}

      {tab === "departments" && (
        <div className="space-y-2">
          <p className="text-xs text-slate-500">{departments.length} departments</p>
          {departments.map((d) => (
            <Card key={d.id} className="bg-white/5 border-white/5">
              <CardContent className="py-3">
                <p className="text-sm font-medium text-white">{d.name}</p>
                <p className="text-xs text-slate-400">{d.hospital_name}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
