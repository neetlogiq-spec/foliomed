"use client";

import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { ConfidenceBadge } from "./ConfidenceBadge";

export interface LabTest {
  name: string;
  value: string;
  unit: string;
  reference: string;
  flag: "high" | "low" | "normal" | null;
  confidence?: string;
}

export interface LabReportData {
  report_date?: string;
  patient_name?: string;
  lab_name?: string;
  tests?: LabTest[];
  confidence?: Record<string, string>;
  [key: string]: unknown;
}

interface EditableLabReportProps {
  data: LabReportData;
  onChange: (updated: LabReportData) => void;
}

const FLAG_COLORS: Record<string, string> = {
  high: "text-red-400",
  low: "text-amber-400",
  normal: "text-emerald-400",
};

export function EditableLabReport({ data, onChange }: EditableLabReportProps) {
  const tests: LabTest[] = Array.isArray(data.tests) ? data.tests : [];

  const setField = (key: keyof LabReportData, value: string) => {
    onChange({ ...data, [key]: value });
  };

  const setTestField = (idx: number, key: keyof LabTest, value: string) => {
    const updated = tests.map((t, i) =>
      i === idx ? { ...t, [key]: value } : t
    );
    onChange({ ...data, tests: updated });
  };

  const addRow = () => {
    onChange({
      ...data,
      tests: [...tests, { name: "", value: "", unit: "", reference: "", flag: null }],
    });
  };

  const removeRow = (idx: number) => {
    onChange({ ...data, tests: tests.filter((_, i) => i !== idx) });
  };

  return (
    <div className="space-y-4">
      {/* Header fields */}
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Report Date</label>
          <Input
            value={data.report_date ?? ""}
            onChange={(e) => setField("report_date", e.target.value)}
            placeholder="2024-01-15"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
        <div className="space-y-1">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Patient Name</label>
          <Input
            value={data.patient_name ?? ""}
            onChange={(e) => setField("patient_name", e.target.value)}
            placeholder="Patient name"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
        <div className="space-y-1 col-span-2">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">Lab Name</label>
          <Input
            value={data.lab_name ?? ""}
            onChange={(e) => setField("lab_name", e.target.value)}
            placeholder="Lab name"
            className="bg-white/5 border-white/10 text-white text-xs h-7"
          />
        </div>
      </div>

      {/* Tests table */}
      <div className="space-y-1">
        <div className="flex items-center justify-between mb-1">
          <span className="text-[10px] text-slate-400 uppercase tracking-wide">
            Tests ({tests.length})
          </span>
          <Button
            type="button"
            size="sm"
            variant="ghost"
            onClick={addRow}
            className="text-[10px] text-blue-400 h-5 px-2 hover:text-blue-300"
          >
            + Add row
          </Button>
        </div>

        {tests.length === 0 ? (
          <p className="text-xs text-slate-500 py-2 text-center">No tests extracted</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs border-collapse">
              <thead>
                <tr className="text-[10px] text-slate-500 border-b border-white/10">
                  <th className="text-left py-1 pr-2 font-normal w-[28%]">Test</th>
                  <th className="text-left py-1 pr-2 font-normal w-[14%]">Value</th>
                  <th className="text-left py-1 pr-2 font-normal w-[10%]">Unit</th>
                  <th className="text-left py-1 pr-2 font-normal w-[20%]">Reference</th>
                  <th className="text-left py-1 pr-2 font-normal w-[12%]">Flag</th>
                  <th className="w-6" />
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {tests.map((t, i) => (
                  <tr key={i} className="group">
                    <td className="py-1 pr-2">
                      <div className="flex items-center gap-1.5">
                        <ConfidenceBadge level={t.confidence} />
                        <Input
                          value={t.name}
                          onChange={(e) => setTestField(i, "name", e.target.value)}
                          placeholder="Test name"
                          className="bg-transparent border-white/10 text-white text-xs h-6 px-1"
                        />
                      </div>
                    </td>
                    <td className="py-1 pr-2">
                      <Input
                        value={t.value}
                        onChange={(e) => setTestField(i, "value", e.target.value)}
                        placeholder="—"
                        className={`bg-transparent border-white/10 text-xs h-6 px-1 ${t.flag ? (FLAG_COLORS[t.flag] ?? "text-white") : "text-white"}`}
                      />
                    </td>
                    <td className="py-1 pr-2">
                      <Input
                        value={t.unit}
                        onChange={(e) => setTestField(i, "unit", e.target.value)}
                        placeholder="—"
                        className="bg-transparent border-white/10 text-slate-300 text-xs h-6 px-1"
                      />
                    </td>
                    <td className="py-1 pr-2">
                      <Input
                        value={t.reference}
                        onChange={(e) => setTestField(i, "reference", e.target.value)}
                        placeholder="—"
                        className="bg-transparent border-white/10 text-slate-400 text-xs h-6 px-1"
                      />
                    </td>
                    <td className="py-1 pr-2">
                      <select
                        value={t.flag ?? ""}
                        onChange={(e) =>
                          setTestField(i, "flag", e.target.value as LabTest["flag"] & string)
                        }
                        className={`bg-slate-900 border border-white/10 rounded text-xs h-6 px-1 w-full ${t.flag ? (FLAG_COLORS[t.flag] ?? "") : "text-slate-400"}`}
                      >
                        <option value="" className="text-slate-400">—</option>
                        <option value="high" className="text-red-400">High</option>
                        <option value="low" className="text-amber-400">Low</option>
                        <option value="normal" className="text-emerald-400">Normal</option>
                      </select>
                    </td>
                    <td className="py-1">
                      <button
                        type="button"
                        onClick={() => removeRow(i)}
                        className="text-slate-600 hover:text-red-400 text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                        title="Remove row"
                      >
                        ✕
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
