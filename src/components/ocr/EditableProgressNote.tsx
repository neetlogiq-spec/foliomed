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

export interface MedicationEntry {
  name?: string;
  dose?: string;
  route?: string;
  frequency?: string;
  duration?: string;
}

export interface NeonatalData {
  gestational_age?: string;
  birth_weight_kg?: number | string;
  mode_of_delivery?: string;
  apgar_score?: string;
  downe_score?: string;
  respiratory_support?: string;
  feeding?: string;
  diagnosis?: string;
  blood_culture?: string;
  investigations_pending?: string[];
}

export interface ProgressNoteData {
  date?: string;
  day_of_life?: number | string;
  doctor?: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
  vitals?: ProgressNoteVitals;
  fluid_input_ml?: string | number;
  fluid_output_ml?: string | number;
  medications?: MedicationEntry[];
  neonatal?: NeonatalData;
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
  const medications: MedicationEntry[] = (data.medications as MedicationEntry[]) ?? [];
  const neonatal: NeonatalData = (data.neonatal as NeonatalData) ?? {};
  const hasNeonatal = data.neonatal && Object.values(data.neonatal).some((v) => v != null && v !== "");

  const setField = (key: keyof ProgressNoteData, value: string) => {
    onChange({ ...data, [key]: value });
  };

  const setVital = (key: keyof ProgressNoteVitals, value: string) => {
    onChange({ ...data, vitals: { ...vitals, [key]: value } });
  };

  const setNeonatal = (key: keyof NeonatalData, value: string) => {
    onChange({ ...data, neonatal: { ...neonatal, [key]: value } });
  };

  const setMedication = (index: number, key: keyof MedicationEntry, value: string) => {
    const updated = [...medications];
    updated[index] = { ...updated[index], [key]: value };
    onChange({ ...data, medications: updated });
  };

  const addMedication = () => {
    onChange({ ...data, medications: [...medications, { name: "", dose: "", route: "", frequency: "", duration: "" }] });
  };

  const removeMedication = (index: number) => {
    onChange({ ...data, medications: medications.filter((_, i) => i !== index) });
  };

  return (
    <div className="space-y-3">
      {/* Date + Day of Life + Doctor */}
      <div className="grid grid-cols-3 gap-2">
        <div className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Date</label>
          <Input
            value={data.date ?? ""}
            onChange={(e) => setField("date", e.target.value)}
            placeholder="2024-01-15"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
        <div className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Day of Life</label>
          <Input
            value={data.day_of_life != null ? String(data.day_of_life) : ""}
            onChange={(e) => setField("day_of_life", e.target.value)}
            placeholder="7"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
        <div className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Doctor</label>
          <Input
            value={data.doctor ?? ""}
            onChange={(e) => setField("doctor", e.target.value)}
            placeholder="Dr. Name"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
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

      {/* Medications */}
      {medications.length > 0 && (
        <div className="space-y-1.5">
          <div className="flex items-center gap-1.5">
            <ConfidenceBadge level={confidence.medications} />
            <label className="text-[10px] text-slate-400 uppercase tracking-wide">Medications</label>
          </div>
          {medications.map((med, i) => (
            <div key={i} className="rounded-lg border border-white/10 bg-white/[0.02] p-2 space-y-1.5">
              <div className="flex items-center justify-between">
                <span className="text-[10px] text-slate-500">#{i + 1}</span>
                <button type="button" onClick={() => removeMedication(i)} className="text-[10px] text-red-400 hover:text-red-300">Remove</button>
              </div>
              <div className="grid grid-cols-2 gap-1.5">
                <Input value={med.name ?? ""} onChange={(e) => setMedication(i, "name", e.target.value)} placeholder="Drug name" className="bg-white/5 border-white/10 text-white text-xs h-7 col-span-2" />
                <Input value={med.dose ?? ""} onChange={(e) => setMedication(i, "dose", e.target.value)} placeholder="Dose" className="bg-white/5 border-white/10 text-white text-xs h-7" />
                <Input value={med.route ?? ""} onChange={(e) => setMedication(i, "route", e.target.value)} placeholder="Route (IV/PO)" className="bg-white/5 border-white/10 text-white text-xs h-7" />
                <Input value={med.frequency ?? ""} onChange={(e) => setMedication(i, "frequency", e.target.value)} placeholder="Frequency" className="bg-white/5 border-white/10 text-white text-xs h-7" />
                <Input value={med.duration ?? ""} onChange={(e) => setMedication(i, "duration", e.target.value)} placeholder="Duration" className="bg-white/5 border-white/10 text-white text-xs h-7" />
              </div>
            </div>
          ))}
          <button type="button" onClick={addMedication} className="text-[10px] text-violet-400 hover:text-violet-300">+ Add medication</button>
        </div>
      )}
      {medications.length === 0 && (
        <button type="button" onClick={addMedication} className="text-[10px] text-violet-400 hover:text-violet-300">+ Add medication</button>
      )}

      {/* Neonatal section */}
      {hasNeonatal && (
        <div className="space-y-1.5 border-l-2 border-l-pink-500 pl-3">
          <div className="flex items-center gap-1.5">
            <ConfidenceBadge level={confidence.neonatal} />
            <label className="text-[10px] text-pink-300 font-medium uppercase tracking-wide">Neonatal</label>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {([
              { key: "gestational_age" as const, label: "Gestational Age", placeholder: "Term / 36 weeks" },
              { key: "birth_weight_kg" as const, label: "Birth Weight (kg)", placeholder: "3.4" },
              { key: "mode_of_delivery" as const, label: "Mode of Delivery", placeholder: "NVD / LSCS" },
              { key: "apgar_score" as const, label: "Apgar Score", placeholder: "8/10, 9/10" },
              { key: "downe_score" as const, label: "Downe Score", placeholder: "2/10" },
              { key: "respiratory_support" as const, label: "Respiratory Support", placeholder: "HFNC / CPAP / Room air" },
              { key: "feeding" as const, label: "Feeding", placeholder: "DBF / EBM / NPO" },
              { key: "blood_culture" as const, label: "Blood Culture", placeholder: "No growth" },
            ]).map(({ key, label, placeholder }) => (
              <div key={key} className="space-y-0.5">
                <label className="text-[10px] text-slate-500">{label}</label>
                <Input
                  value={neonatal[key] != null ? String(neonatal[key]) : ""}
                  onChange={(e) => setNeonatal(key, e.target.value)}
                  placeholder={placeholder}
                  className="bg-white/5 border-white/10 text-white text-xs h-7"
                />
              </div>
            ))}
          </div>
          <div className="space-y-0.5">
            <label className="text-[10px] text-slate-500">Diagnosis</label>
            <Textarea
              value={neonatal.diagnosis ?? ""}
              onChange={(e) => setNeonatal("diagnosis", e.target.value)}
              rows={2}
              placeholder="TTNB, Laryngomalacia..."
              className="bg-white/5 border-white/10 text-white text-xs resize-none"
            />
          </div>
          <div className="space-y-0.5">
            <label className="text-[10px] text-slate-500">Investigations Pending</label>
            <Input
              value={Array.isArray(neonatal.investigations_pending) ? neonatal.investigations_pending.join(", ") : (neonatal.investigations_pending ?? "")}
              onChange={(e) => setNeonatal("investigations_pending", e.target.value)}
              placeholder="OAE, 2D Echo..."
              className="bg-white/5 border-white/10 text-white text-xs h-7"
            />
          </div>
        </div>
      )}
    </div>
  );
}
