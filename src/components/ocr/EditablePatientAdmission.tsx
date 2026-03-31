"use client";

import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { ConfidenceBadge } from "./ConfidenceBadge";

export interface PatientAdmissionData {
  ip_number?: string;
  first_name?: string;
  last_name?: string;
  date_of_birth?: string;
  age_years?: string | number;
  age_months?: string | number;
  gender?: string;
  weight_kg?: string | number;
  height_cm?: string | number;
  blood_group?: string;
  guardian_name?: string;
  guardian_relation?: string;
  phone?: string;
  address?: string;
  diagnosis?: string;
  ward?: string;
  bed_number?: string;
  admission_date?: string;
  confidence?: Record<string, string>;
  [key: string]: unknown;
}

interface EditablePatientAdmissionProps {
  data: PatientAdmissionData;
  onChange: (updated: PatientAdmissionData) => void;
}

const FIELDS: { key: keyof PatientAdmissionData; label: string; multiline?: boolean }[] = [
  { key: "ip_number", label: "IP Number" },
  { key: "first_name", label: "First Name" },
  { key: "last_name", label: "Last Name" },
  { key: "date_of_birth", label: "Date of Birth" },
  { key: "age_years", label: "Age (years)" },
  { key: "age_months", label: "Age (months)" },
  { key: "gender", label: "Gender" },
  { key: "weight_kg", label: "Weight (kg)" },
  { key: "height_cm", label: "Height (cm)" },
  { key: "blood_group", label: "Blood Group" },
  { key: "guardian_name", label: "Guardian Name" },
  { key: "guardian_relation", label: "Relation" },
  { key: "phone", label: "Phone" },
  { key: "ward", label: "Ward" },
  { key: "bed_number", label: "Bed No." },
  { key: "admission_date", label: "Admission Date" },
  { key: "diagnosis", label: "Diagnosis", multiline: true },
  { key: "address", label: "Address", multiline: true },
];

export function EditablePatientAdmission({ data, onChange }: EditablePatientAdmissionProps) {
  const confidence = (data.confidence as Record<string, string>) ?? {};

  const setField = (key: keyof PatientAdmissionData, value: string) => {
    onChange({ ...data, [key]: value });
  };

  return (
    <div className="grid grid-cols-2 gap-x-3 gap-y-2">
      {FIELDS.map(({ key, label, multiline }) => {
        const conf = confidence[key as string];
        const rawVal = data[key];
        const val = rawVal != null ? String(rawVal) : "";

        return (
          <div key={key} className={`space-y-0.5 ${multiline ? "col-span-2" : ""}`}>
            <div className="flex items-center gap-1.5">
              <ConfidenceBadge level={conf} />
              <label className="text-[10px] text-slate-400 uppercase tracking-wide">{label}</label>
            </div>
            {multiline ? (
              <Textarea
                value={val}
                onChange={(e) => setField(key, e.target.value)}
                rows={2}
                className="bg-white/5 border-white/10 text-white text-xs resize-none"
              />
            ) : (
              <Input
                value={val}
                onChange={(e) => setField(key, e.target.value)}
                className="bg-white/5 border-white/10 text-white text-xs h-7"
              />
            )}
          </div>
        );
      })}
    </div>
  );
}
