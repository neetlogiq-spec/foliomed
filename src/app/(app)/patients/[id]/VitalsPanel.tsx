"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { addVitals } from "./clinical-actions";
import type { Vital } from "@/types/clinical";
import { cn } from "@/lib/utils";

interface VitalsPanelProps {
  patientId: string;
  vitals: Vital[];
}

export function VitalsPanel({ patientId, vitals }: VitalsPanelProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);
    const parse = (k: string) => {
      const v = fd.get(k) as string;
      return v ? Number(v) : undefined;
    };

    // Convert °F → °C for storage
    const tempF = parse("temperature_f");
    const tempC = tempF != null ? Math.round(((tempF - 32) * 5) / 9 * 10) / 10 : undefined;

    startTransition(async () => {
      const result = await addVitals(patientId, {
        heart_rate: parse("heart_rate"),
        respiratory_rate: parse("respiratory_rate"),
        temperature_c: tempC,
        systolic_bp: parse("systolic_bp"),
        diastolic_bp: parse("diastolic_bp"),
        spo2_percent: parse("spo2_percent"),
        weight_kg: parse("weight_kg"),
      });
      if (result?.error) setError(result.error);
      else setShowForm(false);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Vitals ({vitals.length})
        </h3>
        <Button
          size="sm"
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs"
        >
          {showForm ? "Cancel" : "+ Record Vitals"}
        </Button>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New Vital Signs</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <p className="text-xs text-red-400">{error}</p>
              )}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {[
                  { name: "heart_rate", label: "HR (bpm)", placeholder: "e.g. 120" },
                  { name: "respiratory_rate", label: "RR (/min)", placeholder: "e.g. 24" },
                  { name: "temperature_f", label: "Temp (°F)", placeholder: "e.g. 98.6" },
                  { name: "spo2_percent", label: "SpO2 (%)", placeholder: "e.g. 98" },
                  { name: "systolic_bp", label: "Sys BP", placeholder: "e.g. 90" },
                  { name: "diastolic_bp", label: "Dia BP", placeholder: "e.g. 60" },
                  { name: "weight_kg", label: "Weight (kg)", placeholder: "e.g. 3.5" },
                ].map((f) => (
                  <div key={f.name} className="space-y-1">
                    <Label className="text-xs text-slate-400">{f.label}</Label>
                    <Input
                      name={f.name}
                      type="number"
                      step="any"
                      placeholder={f.placeholder}
                      className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600"
                    />
                  </div>
                ))}
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Saving..." : "Save Vitals"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {vitals.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No vitals recorded yet</p>
      ) : (
        <div className="space-y-2">
          {vitals.map((v) => (
            <div
              key={v.id}
              className={cn(
                "bg-white/5 border rounded-lg p-3",
                v.is_abnormal ? "border-red-500/30" : "border-white/5"
              )}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs text-slate-400">
                  {new Date(v.recorded_at).toLocaleString("en-IN", {
                    day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit",
                  })}
                </span>
                {v.is_abnormal && (
                  <span className="text-[10px] px-1.5 py-0.5 bg-red-500/15 text-red-400 rounded-full font-medium">
                    Abnormal
                  </span>
                )}
              </div>
              <div className="grid grid-cols-4 md:grid-cols-7 gap-2 text-xs">
                {v.heart_rate != null && (
                  <div><span className="text-slate-500">HR</span> <span className="text-white font-medium">{v.heart_rate}</span></div>
                )}
                {v.respiratory_rate != null && (
                  <div><span className="text-slate-500">RR</span> <span className="text-white font-medium">{v.respiratory_rate}</span></div>
                )}
                {v.temperature_c != null && (
                  <div><span className="text-slate-500">T</span> <span className="text-white font-medium">{Math.round((v.temperature_c * 9 / 5 + 32) * 10) / 10}°F</span></div>
                )}
                {v.spo2_percent != null && (
                  <div><span className="text-slate-500">SpO2</span> <span className="text-white font-medium">{v.spo2_percent}%</span></div>
                )}
                {(v.systolic_bp != null || v.diastolic_bp != null) && (
                  <div><span className="text-slate-500">BP</span> <span className="text-white font-medium">{v.systolic_bp}/{v.diastolic_bp}</span></div>
                )}
                {v.weight_kg != null && (
                  <div><span className="text-slate-500">Wt</span> <span className="text-white font-medium">{v.weight_kg}kg</span></div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
