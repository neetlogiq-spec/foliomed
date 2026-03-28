"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { addMedication, updateMedicationStatus } from "./clinical-actions";
import type { Medication, MedicationStatus } from "@/types/clinical";
import { MEDICATION_STATUS_CONFIG } from "@/types/clinical";
import { cn } from "@/lib/utils";

interface MedicationsPanelProps {
  patientId: string;
  medications: Medication[];
}

export function MedicationsPanel({ patientId, medications }: MedicationsPanelProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [text, setText] = useState("");

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const trimmed = text.trim();
    if (!trimmed) return;

    startTransition(async () => {
      const result = await addMedication(patientId, { drug_name: trimmed });
      if (result?.error) setError(result.error);
      else {
        setShowForm(false);
        setText("");
      }
    });
  };

  const handleStatusChange = (medId: string, status: MedicationStatus) => {
    startTransition(async () => {
      await updateMedicationStatus(medId, patientId, status);
    });
  };

  const active = medications.filter((m) => m.status === "active");
  const inactive = medications.filter((m) => m.status !== "active");

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Medications ({medications.length})
        </h3>
        <Button
          size="sm"
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs"
        >
          {showForm ? "Cancel" : "+ Prescribe"}
        </Button>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New Prescription</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">
                  Prescription text <span className="text-slate-600">(e.g. Tab Amoxicillin 250mg TDS × 5 days)</span>
                </Label>
                <textarea
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  required
                  rows={3}
                  placeholder={"Tab Amoxicillin 250mg TDS × 5 days\nSyp Paracetamol 5ml TDS PRN"}
                  className="w-full rounded-md border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder:text-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500 resize-none"
                />
              </div>
              <Button
                type="submit"
                disabled={isPending || !text.trim()}
                size="sm"
                className="bg-blue-600 hover:bg-blue-700"
              >
                {isPending ? "Saving..." : "Save"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {medications.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No medications prescribed yet</p>
      ) : (
        <div className="space-y-4">
          {active.length > 0 && (
            <div className="space-y-2">
              <p className="text-xs text-emerald-400 font-medium">Active ({active.length})</p>
              {active.map((med) => (
                <MedicationRow key={med.id} med={med} onStatusChange={handleStatusChange} isPending={isPending} />
              ))}
            </div>
          )}
          {inactive.length > 0 && (
            <div className="space-y-2">
              <p className="text-xs text-slate-500 font-medium">Inactive ({inactive.length})</p>
              {inactive.map((med) => (
                <MedicationRow key={med.id} med={med} onStatusChange={handleStatusChange} isPending={isPending} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function MedicationRow({
  med,
  onStatusChange,
  isPending,
}: {
  med: Medication;
  onStatusChange: (id: string, status: MedicationStatus) => void;
  isPending: boolean;
}) {
  const statusConfig = MEDICATION_STATUS_CONFIG[med.status];

  return (
    <div
      className={cn(
        "bg-white/5 border rounded-lg px-3 py-2.5 flex items-start justify-between gap-3",
        med.status === "active" ? "border-emerald-500/20" : "border-white/5"
      )}
    >
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm text-white">{med.drug_name}</span>
          <span className={cn("text-[10px] px-1.5 py-0.5 border rounded-full font-medium", statusConfig.color)}>
            {statusConfig.label}
          </span>
        </div>
        {med.start_date && (
          <span className="text-[10px] text-slate-500 mt-0.5 inline-block">
            Started {new Date(med.start_date).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}
          </span>
        )}
      </div>
      {med.status === "active" && (
        <div className="flex gap-1 shrink-0">
          <button
            onClick={() => onStatusChange(med.id, "on_hold")}
            disabled={isPending}
            className="text-[10px] px-2 py-1 rounded text-amber-400 hover:bg-amber-500/10 transition-colors"
          >
            Hold
          </button>
          <button
            onClick={() => onStatusChange(med.id, "stopped")}
            disabled={isPending}
            className="text-[10px] px-2 py-1 rounded text-red-400 hover:bg-red-500/10 transition-colors"
          >
            Stop
          </button>
        </div>
      )}
    </div>
  );
}
