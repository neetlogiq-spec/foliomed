"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { addInvestigation } from "./clinical-actions";
import type { Investigation } from "@/types/clinical";
import { INVESTIGATION_CATEGORIES } from "@/types/clinical";
import { cn } from "@/lib/utils";
import { ScanButton } from "@/components/shared/ScanButton";

interface InvestigationsPanelProps {
  patientId: string;
  investigations: Investigation[];
}

export function InvestigationsPanel({ patientId, investigations }: InvestigationsPanelProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);

    startTransition(async () => {
      const result = await addInvestigation(patientId, {
        test_name: fd.get("test_name") as string,
        category: (fd.get("category") as string) || undefined,
        value: (fd.get("value") as string) || undefined,
        unit: (fd.get("unit") as string) || undefined,
        reference_range: (fd.get("reference_range") as string) || undefined,
        is_abnormal: fd.get("is_abnormal") === "on",
        is_critical: fd.get("is_critical") === "on",
      });
      if (result?.error) setError(result.error);
      else setShowForm(false);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
      <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Investigations ({investigations.length})
        </h3>
        <div className="flex gap-2">
          <ScanButton
            context="lab_report"
            label="📷 Scan Report"
            onExtract={(data) => {
              // Gemini returns `tests` array (not `investigations`)
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              const tests = (data as any).tests;
              if (Array.isArray(tests)) {
                startTransition(async () => {
                  for (const t of tests) {
                    const isAbnormal = t.flag === "high" || t.flag === "low";
                    await addInvestigation(patientId, {
                      test_name: t.name || t.test_name || "Unknown Test",
                      category: t.category || undefined,
                      value: t.value != null ? String(t.value) : undefined,
                      unit: t.unit || undefined,
                      reference_range: t.reference || t.reference_range || undefined,
                      is_abnormal: isAbnormal,
                      is_critical: false,
                    });
                  }
                });
              }
            }}
          />
          <Button size="sm" onClick={() => setShowForm(!showForm)} className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
            {showForm ? "Cancel" : "+ Add Investigation"}
          </Button>
        </div>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New Investigation</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                <div className="space-y-1 col-span-2 md:col-span-1">
                  <Label className="text-xs text-slate-400">Test Name *</Label>
                  <Input name="test_name" required placeholder="e.g. CBC, CRP"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Category</Label>
                  <select name="category"
                    className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1.5 text-sm text-white h-8">
                    <option value="" className="bg-slate-900">Select</option>
                    {INVESTIGATION_CATEGORIES.map((c) => (
                      <option key={c.value} value={c.value} className="bg-slate-900">{c.label}</option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Value</Label>
                  <Input name="value" placeholder="e.g. 12.5"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Unit</Label>
                  <Input name="unit" placeholder="e.g. g/dL"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Reference Range</Label>
                  <Input name="reference_range" placeholder="e.g. 11-16"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
              </div>
              <div className="flex gap-4">
                <label className="flex items-center gap-1.5 text-xs text-slate-400 cursor-pointer">
                  <input type="checkbox" name="is_abnormal" className="rounded border-white/20 bg-white/5" />
                  Abnormal
                </label>
                <label className="flex items-center gap-1.5 text-xs text-red-400 cursor-pointer">
                  <input type="checkbox" name="is_critical" className="rounded border-white/20 bg-white/5" />
                  Critical
                </label>
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Saving..." : "Save Investigation"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {investigations.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No investigations recorded yet</p>
      ) : (
        <div className="space-y-2">
          {investigations.map((inv) => (
            <div key={inv.id}
              className={cn(
                "bg-white/5 border rounded-lg p-3 flex items-center justify-between",
                inv.is_critical ? "border-red-500/40" : inv.is_abnormal ? "border-amber-500/30" : "border-white/5"
              )}>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-0.5">
                  <span className="text-sm font-medium text-white">{inv.test_name}</span>
                  {inv.category && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-white/5 text-slate-400 rounded capitalize">{inv.category}</span>
                  )}
                  {inv.is_critical && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-red-500/15 text-red-400 rounded-full font-medium">Critical</span>
                  )}
                  {inv.is_abnormal && !inv.is_critical && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-amber-500/15 text-amber-400 rounded-full font-medium">Abnormal</span>
                  )}
                </div>
                <span className="text-xs text-slate-400">
                  {new Date(inv.created_at).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}
                </span>
              </div>
              <div className="text-right">
                {inv.value && (
                  <span className={cn("text-sm font-mono font-medium",
                    inv.is_critical ? "text-red-400" : inv.is_abnormal ? "text-amber-400" : "text-white"
                  )}>
                    {inv.value} {inv.unit || ""}
                  </span>
                )}
                {inv.reference_range && (
                  <p className="text-[10px] text-slate-500">Ref: {inv.reference_range}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
