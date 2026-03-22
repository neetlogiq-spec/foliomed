"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { createHandoverNote, acknowledgeHandover } from "./actions";
import type { HandoverNote } from "@/types/feed";
import { cn } from "@/lib/utils";

interface HandoverClientProps {
  notes: HandoverNote[];
}

export function HandoverClient({ notes }: HandoverClientProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);
    startTransition(async () => {
      const result = await createHandoverNote({
        handover_date: (fd.get("handover_date") as string) || new Date().toISOString().split("T")[0],
        shift: (fd.get("shift") as string) || undefined,
        patients_summary: (fd.get("patients_summary") as string) || undefined,
        pending_tasks: (fd.get("pending_tasks") as string) || undefined,
        critical_alerts: (fd.get("critical_alerts") as string) || undefined,
        notes: (fd.get("notes") as string) || undefined,
      });
      if (result?.error) setError(result.error);
      else setShowForm(false);
    });
  };

  const handleAck = (id: string) => {
    startTransition(async () => {
      await acknowledgeHandover(id);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div />
        <Button size="sm" onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
          {showForm ? "Cancel" : "+ New Handover"}
        </Button>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">Create Handover Note</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Date</Label>
                  <Input name="handover_date" type="date" defaultValue={new Date().toISOString().split("T")[0]}
                    className="bg-white/5 border-white/10 text-white text-sm h-8" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Shift</Label>
                  <select name="shift"
                    className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1.5 text-sm text-white h-8">
                    <option value="" className="bg-slate-900">Select shift</option>
                    <option value="morning" className="bg-slate-900">Morning</option>
                    <option value="afternoon" className="bg-slate-900">Afternoon</option>
                    <option value="night" className="bg-slate-900">Night</option>
                  </select>
                </div>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Patients Summary</Label>
                <Textarea name="patients_summary" rows={2} placeholder="Summary of patients under care..."
                  className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[48px]" />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Pending Tasks</Label>
                <Textarea name="pending_tasks" rows={2} placeholder="Tasks to be completed..."
                  className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[48px]" />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-red-400">⚠ Critical Alerts</Label>
                <Textarea name="critical_alerts" rows={2} placeholder="Any critical patient alerts..."
                  className="bg-white/5 border-red-500/20 text-white text-sm placeholder:text-slate-600 min-h-[48px]" />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Additional Notes</Label>
                <Textarea name="notes" rows={2} placeholder="Anything else..."
                  className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[48px]" />
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Creating..." : "Create Handover"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {notes.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400 font-medium">No handover notes</p>
          <p className="text-sm text-slate-500 mt-1">Create one before ending your shift</p>
        </div>
      ) : (
        notes.map((note) => (
          <Card key={note.id} className={cn(
            "bg-white/5 border-white/5",
            !note.acknowledged && "border-amber-500/20"
          )}>
            <CardContent className="pt-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-white">
                    {note.from_profile?.full_name || "Unknown"}
                  </span>
                  {note.shift && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-white/5 text-slate-400 rounded capitalize">{note.shift}</span>
                  )}
                  {!note.acknowledged && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-amber-500/15 text-amber-400 rounded-full font-medium">Pending</span>
                  )}
                  {note.acknowledged && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-emerald-500/15 text-emerald-400 rounded-full font-medium">✓ Acknowledged</span>
                  )}
                </div>
                <span className="text-xs text-slate-500">
                  {new Date(note.handover_date).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
                </span>
              </div>

              <div className="space-y-2 text-sm">
                {note.patients_summary && (
                  <div>
                    <span className="text-xs text-slate-500 font-medium">Patients</span>
                    <p className="text-slate-300 whitespace-pre-wrap">{note.patients_summary}</p>
                  </div>
                )}
                {note.pending_tasks && (
                  <div>
                    <span className="text-xs text-slate-500 font-medium">Pending Tasks</span>
                    <p className="text-slate-300 whitespace-pre-wrap">{note.pending_tasks}</p>
                  </div>
                )}
                {note.critical_alerts && (
                  <div className="bg-red-500/5 border border-red-500/15 rounded p-2">
                    <span className="text-xs text-red-400 font-medium">⚠ Critical Alerts</span>
                    <p className="text-red-300 whitespace-pre-wrap">{note.critical_alerts}</p>
                  </div>
                )}
                {note.notes && (
                  <div>
                    <span className="text-xs text-slate-500 font-medium">Notes</span>
                    <p className="text-slate-300 whitespace-pre-wrap">{note.notes}</p>
                  </div>
                )}
              </div>

              {!note.acknowledged && (
                <div className="mt-3 pt-2 border-t border-white/5">
                  <Button size="sm" variant="outline" onClick={() => handleAck(note.id)}
                    disabled={isPending}
                    className="border-emerald-500/30 text-emerald-400 hover:bg-emerald-500/10 text-xs">
                    ✓ Acknowledge
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>
        ))
      )}
    </div>
  );
}
