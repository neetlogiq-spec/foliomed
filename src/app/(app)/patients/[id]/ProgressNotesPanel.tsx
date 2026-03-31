"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { addProgressNote } from "./clinical-actions";
import { SpeechInput } from "@/components/shared/SpeechInput";
import type { ProgressNote } from "@/types/clinical";
import { ScanButton } from "@/components/shared/ScanButton";

interface ProgressNotesPanelProps {
  patientId: string;
  notes: ProgressNote[];
}

export function ProgressNotesPanel({ patientId, notes }: ProgressNotesPanelProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [soap, setSoap] = useState({ subjective: "", objective: "", assessment: "", plan: "" });

  const appendSpeech = (field: keyof typeof soap, text: string) => {
    setSoap((prev) => ({ ...prev, [field]: prev[field] + (prev[field] ? " " : "") + text }));
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);

    startTransition(async () => {
      const result = await addProgressNote(patientId, {
        note_date: (fd.get("note_date") as string) || new Date().toISOString().split("T")[0],
        subjective: soap.subjective || undefined,
        objective: soap.objective || undefined,
        assessment: soap.assessment || undefined,
        plan: soap.plan || undefined,
        fluid_input_ml: fd.get("fluid_input_ml") ? Number(fd.get("fluid_input_ml")) : undefined,
        fluid_output_ml: fd.get("fluid_output_ml") ? Number(fd.get("fluid_output_ml")) : undefined,
      });
      if (result?.error) setError(result.error);
      else {
        setShowForm(false);
        setSoap({ subjective: "", objective: "", assessment: "", plan: "" });
      }
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Progress Notes ({notes.length})
        </h3>
        <div className="flex gap-2">
          <ScanButton
            context="progress_note"
            label="📷 Scan Note"
            onExtract={(data) => {
              const asStr = (v: unknown) => (typeof v === "string" ? v : "");
              setSoap({
                subjective: asStr(data.subjective),
                objective: asStr(data.objective),
                assessment: asStr(data.assessment),
                plan: asStr(data.plan),
              });
              setShowForm(true);
            }}
          />
          <Button size="sm" onClick={() => setShowForm(!showForm)} className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
            {showForm ? "Cancel" : "+ SOAP Note"}
          </Button>
        </div>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New SOAP Note</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Date</Label>
                  <Input name="note_date" type="date" defaultValue={new Date().toISOString().split("T")[0]}
                    className="bg-white/5 border-white/10 text-white text-sm h-8" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Fluid Input (ml)</Label>
                  <Input name="fluid_input_ml" type="number" placeholder="ml"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Fluid Output (ml)</Label>
                  <Input name="fluid_output_ml" type="number" placeholder="ml"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
              </div>
              {(["subjective", "objective", "assessment", "plan"] as const).map((field) => (
                <div key={field} className="space-y-1">
                  <div className="flex items-center justify-between">
                    <Label className="text-xs text-slate-400 capitalize">
                      <span className="font-bold text-blue-400">{field[0].toUpperCase()}</span>
                      {" — "}{field}
                    </Label>
                    <SpeechInput onTranscript={(text) => appendSpeech(field, text)} />
                  </div>
                  <Textarea
                    value={soap[field]}
                    onChange={(e) => setSoap((prev) => ({ ...prev, [field]: e.target.value }))}
                    rows={2}
                    placeholder={`${field.charAt(0).toUpperCase() + field.slice(1)}...`}
                    className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[48px]"
                  />
                </div>
              ))}
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Saving..." : "Save Note"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {notes.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No progress notes yet</p>
      ) : (
        <div className="space-y-3">
          {notes.map((note) => (
            <Card key={note.id} className="bg-white/5 border-white/5">
              <CardContent className="pt-4">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-medium text-blue-400">
                    {new Date(note.note_date).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
                  </span>
                  {(note.fluid_input_ml != null || note.fluid_output_ml != null) && (
                    <span className="text-[10px] text-slate-500">
                      I/O: {note.fluid_input_ml ?? "—"}/{note.fluid_output_ml ?? "—"} ml
                    </span>
                  )}
                </div>
                <div className="space-y-2 text-sm">
                  {note.subjective && (
                    <div><span className="text-blue-400 font-bold">S</span> <span className="text-slate-300">{note.subjective}</span></div>
                  )}
                  {note.objective && (
                    <div><span className="text-blue-400 font-bold">O</span> <span className="text-slate-300">{note.objective}</span></div>
                  )}
                  {note.assessment && (
                    <div><span className="text-blue-400 font-bold">A</span> <span className="text-slate-300">{note.assessment}</span></div>
                  )}
                  {note.plan && (
                    <div><span className="text-blue-400 font-bold">P</span> <span className="text-slate-300">{note.plan}</span></div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
