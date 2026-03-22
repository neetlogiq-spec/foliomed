"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { addCaseLogEntry } from "./actions";
import type { CaseLogEntry } from "@/types/feed";
import { cn } from "@/lib/utils";

interface LogbookClientProps {
  entries: CaseLogEntry[];
}

export function LogbookClient({ entries }: LogbookClientProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);
    startTransition(async () => {
      const result = await addCaseLogEntry({
        patient_id: fd.get("patient_id") as string,
        diagnosis: fd.get("diagnosis") as string,
        procedure_done: (fd.get("procedure_done") as string) || undefined,
        learning_points: (fd.get("learning_points") as string) || undefined,
        is_interesting: fd.get("is_interesting") === "on",
      });
      if (result?.error) setError(result.error);
      else setShowForm(false);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-xs text-slate-500">{entries.length} entries logged</p>
        <Button size="sm" onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
          {showForm ? "Cancel" : "+ Log Case"}
        </Button>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New Case Log Entry</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Patient ID *</Label>
                  <Input name="patient_id" required placeholder="Paste patient UUID"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Diagnosis *</Label>
                  <Input name="diagnosis" required placeholder="e.g. Pneumonia, Sepsis"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Procedure Done</Label>
                <Input name="procedure_done" placeholder="e.g. Lumbar Puncture, IV access"
                  className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Learning Points</Label>
                <Textarea name="learning_points" rows={2} placeholder="What did you learn from this case?"
                  className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[48px]" />
              </div>
              <label className="flex items-center gap-1.5 text-xs text-amber-400 cursor-pointer">
                <input type="checkbox" name="is_interesting" className="rounded border-white/20 bg-white/5" />
                ⭐ Mark as interesting case
              </label>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Saving..." : "Log Case"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {entries.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400 font-medium">No cases logged yet</p>
          <p className="text-sm text-slate-500 mt-1">Start logging cases to build your portfolio</p>
        </div>
      ) : (
        <div className="space-y-2">
          {entries.map((entry) => (
            <Card key={entry.id} className={cn("bg-white/5", entry.is_interesting ? "border-amber-500/20" : "border-white/5")}>
              <CardContent className="pt-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-semibold text-white">{entry.diagnosis}</span>
                      {entry.is_interesting && <span className="text-[10px]">⭐</span>}
                    </div>
                    {entry.patients && (
                      <p className="text-xs text-blue-400 mb-1">
                        {entry.patients.first_name} {entry.patients.last_name || ""} — {entry.patients.mrd_number}
                      </p>
                    )}
                    {entry.procedure_done && (
                      <p className="text-xs text-slate-400">
                        <span className="text-slate-500">Procedure:</span> {entry.procedure_done}
                      </p>
                    )}
                    {entry.learning_points && (
                      <p className="text-xs text-slate-400 mt-1">
                        <span className="text-slate-500">Learning:</span> {entry.learning_points}
                      </p>
                    )}
                  </div>
                  <span className="text-[10px] text-slate-500 shrink-0">
                    {new Date(entry.logged_at).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}
                  </span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
