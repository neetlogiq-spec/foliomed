"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
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

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);

    startTransition(async () => {
      const result = await addMedication(patientId, {
        drug_name: fd.get("drug_name") as string,
        dose_mg_kg: fd.get("dose_mg_kg") ? Number(fd.get("dose_mg_kg")) : undefined,
        dose_calculated: fd.get("dose_calculated") ? Number(fd.get("dose_calculated")) : undefined,
        route: (fd.get("route") as string) || undefined,
        frequency: (fd.get("frequency") as string) || undefined,
        duration: (fd.get("duration") as string) || undefined,
        start_date: (fd.get("start_date") as string) || undefined,
      });
      if (result?.error) setError(result.error);
      else setShowForm(false);
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
        <Button size="sm" onClick={() => setShowForm(!showForm)} className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
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
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                <div className="space-y-1 col-span-2 md:col-span-1">
                  <Label className="text-xs text-slate-400">Drug Name *</Label>
                  <Input name="drug_name" required placeholder="e.g. Amoxicillin"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Dose (mg/kg)</Label>
                  <Input name="dose_mg_kg" type="number" step="any" placeholder="e.g. 25"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Calculated Dose</Label>
                  <Input name="dose_calculated" type="number" step="any" placeholder="mg"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Route</Label>
                  <Input name="route" placeholder="e.g. PO, IV"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Frequency</Label>
                  <Input name="frequency" placeholder="e.g. TDS, BD"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Duration</Label>
                  <Input name="duration" placeholder="e.g. 5 days"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Start Date</Label>
                  <Input name="start_date" type="date" defaultValue={new Date().toISOString().split("T")[0]}
                    className="bg-white/5 border-white/10 text-white text-sm h-8" />
                </div>
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Saving..." : "Save Prescription"}
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
                <MedicationCard key={med.id} med={med} onStatusChange={handleStatusChange} isPending={isPending} />
              ))}
            </div>
          )}
          {inactive.length > 0 && (
            <div className="space-y-2">
              <p className="text-xs text-slate-500 font-medium">Inactive ({inactive.length})</p>
              {inactive.map((med) => (
                <MedicationCard key={med.id} med={med} onStatusChange={handleStatusChange} isPending={isPending} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function MedicationCard({
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
    <div className={cn("bg-white/5 border rounded-lg p-3", med.status === "active" ? "border-emerald-500/20" : "border-white/5")}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-sm font-medium text-white">{med.drug_name}</span>
            <span className={cn("text-[10px] px-1.5 py-0.5 border rounded-full font-medium", statusConfig.color)}>
              {statusConfig.label}
            </span>
          </div>
          <div className="flex flex-wrap gap-x-3 text-xs text-slate-400">
            {med.dose_mg_kg && <span>{med.dose_mg_kg} mg/kg</span>}
            {med.dose_calculated && <span>= {med.dose_calculated} mg</span>}
            {med.route && <span>{med.route}</span>}
            {med.frequency && <span>{med.frequency}</span>}
            {med.duration && <span>{med.duration}</span>}
          </div>
          {med.start_date && (
            <span className="text-[10px] text-slate-500 mt-1 inline-block">
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
    </div>
  );
}
