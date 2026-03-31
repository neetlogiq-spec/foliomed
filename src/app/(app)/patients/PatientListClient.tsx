"use client";

import { useState } from "react";
import Link from "next/link";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import type { PatientListRow, PatientStatus } from "@/types/patient";
import { PATIENT_STATUS_CONFIG, CASE_TAGS } from "@/types/patient";
import { TagBadges } from "@/components/patients/CaseTags";
import { cn } from "@/lib/utils";

type PatientRow = PatientListRow;

function getPgName(profiles: unknown): string {
  if (!profiles) return "—";
  if (Array.isArray(profiles)) return profiles[0]?.full_name ?? "—";
  return (profiles as { full_name?: string }).full_name ?? "—";
}

const STATUS_TABS: { key: string; label: string }[] = [
  { key: "all", label: "All" },
  { key: "admitted", label: "Admitted" },
  { key: "discharged", label: "Discharged" },
  { key: "lama", label: "LAMA" },
  { key: "referred", label: "Referred" },
  { key: "expired", label: "Expired" },
];

export function PatientListClient({ patients }: { patients: PatientRow[] }) {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  const filtered = patients.filter((p) => {
    const matchesSearch =
      !search ||
      `${p.first_name} ${p.last_name || ""}`
        .toLowerCase()
        .includes(search.toLowerCase()) ||
      p.ip_number?.toLowerCase().includes(search.toLowerCase()) ||
      p.diagnosis?.toLowerCase().includes(search.toLowerCase()) ||
      (p.tags || []).some((t: string) => {
        const tag = CASE_TAGS.find((ct) => ct.value === t);
        return tag?.label.toLowerCase().includes(search.toLowerCase());
      });
    const matchesStatus =
      statusFilter === "all" || p.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  // Count per status
  const counts: Record<string, number> = { all: patients.length };
  patients.forEach((p) => {
    counts[p.status] = (counts[p.status] || 0) + 1;
  });

  return (
    <div className="space-y-4">
      {/* Search + New patient */}
      <div className="flex gap-3">
        <Input
          placeholder="Search by name, MRD, IP, or diagnosis…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-500 max-w-md"
        />
        <Link href="/patients/new">
          <Button size="sm" className="bg-blue-600 hover:bg-blue-700 text-white text-xs whitespace-nowrap">
            + Admit Patient
          </Button>
        </Link>
      </div>

      {/* Status tabs */}
      <div className="flex gap-1 bg-white/5 border border-white/10 rounded-lg p-1 overflow-x-auto">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setStatusFilter(tab.key)}
            className={cn(
              "px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap",
              statusFilter === tab.key
                ? "bg-white/10 text-white"
                : "text-slate-400 hover:text-slate-200"
            )}
          >
            {tab.label}
            {counts[tab.key] != null && (
              <span className="ml-1.5 text-[10px] text-slate-500">
                {counts[tab.key]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Patient table */}
      {filtered.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400">No patients found</p>
        </div>
      ) : (
        <div className="border border-white/10 rounded-lg overflow-hidden">
          {/* Header */}
          <div className="hidden md:grid md:grid-cols-[auto_60px_60px_1fr_1fr_100px_auto_80px] gap-3 px-4 py-2.5 bg-white/5 border-b border-white/10 text-[10px] font-semibold text-slate-500 uppercase tracking-wider">
            <div className="w-3"></div>
            <div>Unit</div>
            <div>IP-ID</div>
            <div>Patient Name</div>
            <div>Diagnosis</div>
            <div>Admitted</div>
            <div>Tags</div>
            <div>Status</div>
          </div>

          {/* Rows */}
          {filtered.map((p) => {
            const statusConf =
              PATIENT_STATUS_CONFIG[p.status as PatientStatus];
            const fullName = `${p.first_name} ${p.last_name || ""}`.trim();
            return (
              <Link
                key={p.id}
                href={`/patients/${p.id}`}
                className="flex flex-col md:grid md:grid-cols-[auto_60px_60px_1fr_1fr_100px_auto_80px] gap-2 md:gap-3 px-4 py-3 border-b border-white/5 hover:bg-white/5 transition-colors items-start md:items-center group"
              >
                {/* Mobile Top Row: Stable dot, Name, Status */}
                <div className="flex md:hidden items-start justify-between w-full">
                  <div className="flex items-center gap-2 min-w-0">
                    <span
                      className={cn(
                        "w-2 h-2 rounded-full shrink-0",
                        p.is_stable === false
                          ? "bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.5)]"
                          : "bg-emerald-500 shadow-[0_0_6px_rgba(16,185,129,0.4)]"
                      )}
                    />
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-white truncate">{fullName}</p>
                      <p className="text-[10px] text-slate-500">IP: {p.ip_number || "—"}</p>
                    </div>
                  </div>
                  <span
                    className={cn(
                      "text-[10px] px-1.5 py-0.5 rounded-full font-medium border shrink-0",
                      statusConf?.color || "text-slate-400"
                    )}
                  >
                    {statusConf?.label || p.status}
                  </span>
                </div>

                {/* Desktop Stable/Unstable dot */}
                <div className="hidden md:flex items-center justify-center w-3">
                  <span
                    className={cn(
                      "w-2.5 h-2.5 rounded-full shrink-0",
                      p.is_stable === false
                        ? "bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.5)]"
                        : "bg-emerald-500 shadow-[0_0_6px_rgba(16,185,129,0.4)]"
                    )}
                    title={p.is_stable === false ? "Unstable" : "Stable"}
                  />
                </div>

                {/* Unit & IP-ID (Mobile row, Desktop columns) */}
                <div className="flex md:contents gap-4 text-xs">
                  <div className="flex items-center gap-1 md:block">
                    <span className="md:hidden text-slate-500">Unit:</span>
                    <span className="font-medium text-slate-300">{p.unit || "—"}</span>
                  </div>
                  <div className="flex items-center gap-1 md:block">
                    <span className="md:hidden text-slate-500">IP:</span>
                    <span className="font-mono text-blue-400">{p.ip_number || "—"}</span>
                  </div>
                </div>

                {/* Patient Name + MRD (Desktop only) */}
                <div className="hidden md:block min-w-0">
                  <p className="text-sm font-medium text-white truncate group-hover:text-blue-300 transition-colors">
                    {fullName}
                  </p>
                  <p className="text-[10px] text-slate-500">IP: {p.ip_number || "—"}</p>
                </div>

                {/* Diagnosis */}
                <div className="text-xs text-slate-300 truncate w-full md:w-auto">
                  <span className="md:hidden text-slate-500 mr-1">Dx:</span>
                  {p.diagnosis || "—"}
                </div>

                {/* Admission date */}
                <div className="text-xs text-slate-400">
                  <span className="md:hidden text-slate-500 mr-1">Adm:</span>
                  {p.admission_date
                    ? new Date(p.admission_date).toLocaleDateString("en-IN", {
                        day: "2-digit",
                        month: "short",
                      })
                    : "—"}
                </div>

                {/* Tags */}
                <div className="w-full md:w-auto mt-1 md:mt-0">
                  <TagBadges tags={p.tags || []} />
                </div>

                {/* Status badge (Desktop only) */}
                <div className="hidden md:block">
                  <span
                    className={cn(
                      "text-[10px] px-1.5 py-0.5 rounded-full font-medium border",
                      statusConf?.color || "text-slate-400"
                    )}
                  >
                    {statusConf?.label || p.status}
                  </span>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
