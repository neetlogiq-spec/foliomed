"use client";

import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

export interface CaseSection {
  title: string;
  content: string;
  type: "text" | "findings" | "plan" | string;
}

export interface CaseDocumentData {
  title?: string;
  sections?: CaseSection[];
  raw_text?: string;
  confidence?: Record<string, string>;
  [key: string]: unknown;
}

interface EditableCaseDocumentProps {
  data: CaseDocumentData;
  onChange: (updated: CaseDocumentData) => void;
}

const SECTION_COLORS: Record<string, string> = {
  findings: "border-l-blue-500",
  plan: "border-l-emerald-500",
  text: "border-l-slate-500",
};

const SECTION_TYPES = ["text", "findings", "plan"];

export function EditableCaseDocument({ data, onChange }: EditableCaseDocumentProps) {
  const sections: CaseSection[] = Array.isArray(data.sections) ? data.sections : [];

  const setTitle = (value: string) => onChange({ ...data, title: value });

  const setSection = (idx: number, key: keyof CaseSection, value: string) => {
    const updated = sections.map((s, i) =>
      i === idx ? { ...s, [key]: value } : s
    );
    onChange({ ...data, sections: updated });
  };

  const addSection = () => {
    onChange({
      ...data,
      sections: [...sections, { title: "", content: "", type: "text" }],
    });
  };

  const removeSection = (idx: number) => {
    onChange({ ...data, sections: sections.filter((_, i) => i !== idx) });
  };

  // If no sections, show raw_text fallback
  const showRawFallback = sections.length === 0;

  return (
    <div className="space-y-3">
      {/* Document title */}
      <div className="space-y-0.5">
        <label className="text-[10px] text-slate-400 uppercase tracking-wide">Document Title</label>
        <Input
          value={data.title ?? ""}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Case Summary"
          className="bg-white/5 border-white/10 text-white text-sm h-8 font-medium"
        />
      </div>

      {showRawFallback ? (
        /* Raw text fallback */
        <div className="space-y-0.5">
          <div className="flex items-center justify-between">
            <label className="text-[10px] text-slate-400 uppercase tracking-wide">Raw Text</label>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={addSection}
              className="text-[10px] text-blue-400 h-5 px-2"
            >
              + Add section
            </Button>
          </div>
          <Textarea
            value={data.raw_text ?? ""}
            onChange={(e) => onChange({ ...data, raw_text: e.target.value })}
            rows={8}
            className="bg-white/5 border-white/10 text-white text-xs resize-none font-mono"
          />
        </div>
      ) : (
        /* Structured sections */
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-[10px] text-slate-400 uppercase tracking-wide">
              Sections ({sections.length})
            </span>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={addSection}
              className="text-[10px] text-blue-400 h-5 px-2"
            >
              + Add section
            </Button>
          </div>

          {sections.map((s, i) => {
            const borderColor = SECTION_COLORS[s.type] ?? "border-l-slate-500";
            return (
              <div key={i} className={`border-l-2 pl-3 space-y-1.5 group ${borderColor}`}>
                <div className="flex items-center gap-2">
                  <Input
                    value={s.title}
                    onChange={(e) => setSection(i, "title", e.target.value)}
                    placeholder="Section title"
                    className="bg-white/5 border-white/10 text-white text-xs h-6 flex-1"
                  />
                  <select
                    value={s.type}
                    onChange={(e) => setSection(i, "type", e.target.value)}
                    className="bg-slate-900 border border-white/10 rounded text-xs h-6 px-1 text-slate-300"
                  >
                    {SECTION_TYPES.map((t) => (
                      <option key={t} value={t} className="bg-slate-900 capitalize">{t}</option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={() => removeSection(i)}
                    className="text-slate-600 hover:text-red-400 text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                    title="Remove section"
                  >
                    ✕
                  </button>
                </div>
                <Textarea
                  value={s.content}
                  onChange={(e) => setSection(i, "content", e.target.value)}
                  rows={3}
                  placeholder="Section content..."
                  className="bg-white/5 border-white/10 text-white text-xs resize-none"
                />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
