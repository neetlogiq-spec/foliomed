"use client";

import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { ConfidenceBadge } from "./ConfidenceBadge";

export interface ProgressNoteVitals {
  temperature?: string;
  pulse?: string;
  bp?: string;
  spo2?: string;
  rr?: string;
  weight?: string;
}

export interface ProgressNoteData {
  date?: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
  vitals?: ProgressNoteVitals;
  fluid_input_ml?: string | number;
  fluid_output_ml?: string | number;
  confidence?: Record<string, string>;
  [key: string]: unknown;
}

interface EditableProgressNoteProps {
  data: ProgressNoteData;
  onChange: (updated: ProgressNoteData) => void;
}

const SOAP_SECTIONS: { key: keyof ProgressNoteData; label: string; color: string }[] = [
  { key: "subjective", label: "S — Subjective", color: "border-l-blue-500" },
  { key: "objective", label: "O — Objective", color: "border-l-purple-500" },
  { key: "assessment", label: "A — Assessment", color: "border-l-amber-500" },
  { key: "plan", label: "P — Plan", color: "border-l-emerald-500" },
];

const VITAL_FIELDS: { key: keyof ProgressNoteVitals; label: string; placeholder: string }[] = [
  { key: "temperature", label: "Temp", placeholder: "38.5°C" },
  { key: "pulse", label: "HR", placeholder: "118/min" },
  { key: "bp", label: "BP", placeholder: "90/60" },
  { key: "spo2", label: "SpO₂", placeholder: "98%" },
  { key: "rr", label: "RR", placeholder: "28/min" },
  { key: "weight", label: "Wt", placeholder: "14 kg" },
];

export function EditableProgressNote({ data, onChange }: EditableProgressNoteProps) {
  const confidence = (data.confidence as Record<string, string>) ?? {};
  const vitals: ProgressNoteVitals = (data.vitals as ProgressNoteVitals) ?? {};

  const setField = (key: keyof ProgressNoteData, value: string) => {
    onChange({ ...data, [key]: value });
  };

  const setVital = (key: keyof ProgressNoteVitals, value: string) => {
    onChange({ ...data, vitals: { ...vitals, [key]: value } });
  };

  return (
    <div className="space-y-3">
      {/* Date */}
      <div className="space-y-0.5">
        <label className="text-[10px] text-slate-400 uppercase tracking-wide">Date</label>
        <Input
          value={data.date ?? ""}
          onChange={(e) => setField("date", e.target.value)}
          placeholder="2024-01-15"
          className="bg-white/5 border-white/10 text-white text-xs h-7 max-w-[160px]"
        />
      </div>

      {/* SOAP sections */}
      {SOAP_SECTIONS.map(({ key, label, color }) => (
        <div key={key} className={`border-l-2 pl-3 space-y-1 ${color}`}>
          <div className="flex items-center gap-1.5">
            <ConfidenceBadge level={confidence[key as string]} />
            <label className="text-[10px] text-slate-300 font-medium uppercase tracking-wide">{label}</label>
          </div>
          <Textarea
            value={(data[key] as string) ?? ""}
            onChange={(e) => setField(key, e.target.value)}
            rows={3}
            placeholder={`${label}...`}
            className="bg-white/5 border-white/10 text-white text-xs resize-none"
          />
        </div>
      ))}

      {/* Vitals */}
      <div className="space-y-1">
        <div className="flex items-center gap-1.5">
          <ConfidenceBadge level={confidence.vitals} />
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Vitals</label>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {VITAL_FIELDS.map(({ key, label, placeholder }) => (
            <div key={key} className="space-y-0.5">
              <label className="text-[10px] text-slate-500">{label}</label>
              <Input
                value={vitals[key] ?? ""}
                onChange={(e) => setVital(key, e.target.value)}
                placeholder={placeholder}
                className="bg-white/5 border-white/10 text-white text-xs h-7"
              />
            </div>
          ))}
        </div>
      </div>

      {/* Fluid balance */}
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Fluid In (mL)</label>
          <Input
            type="number"
            value={data.fluid_input_ml != null ? String(data.fluid_input_ml) : ""}
            onChange={(e) => setField("fluid_input_ml", e.target.value)}
            placeholder="450"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
        <div className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Fluid Out (mL)</label>
          <Input
            type="number"
            value={data.fluid_output_ml != null ? String(data.fluid_output_ml) : ""}
            onChange={(e) => setField("fluid_output_ml", e.target.value)}
            placeholder="320"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
      </div>
    </div>
  );
}
