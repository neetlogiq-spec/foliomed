"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { createTemplate, deleteTemplate } from "./actions";
import { DEFAULT_CASE_BLOCKS } from "@/types/document";
import { cn } from "@/lib/utils";

const CATEGORIES = [
  { value: "case_sheet", label: "Case Sheet" },
  { value: "discharge_summary", label: "Discharge Summary" },
  { value: "procedure_note", label: "Procedure Note" },
  { value: "consultation", label: "Consultation" },
  { value: "custom", label: "Custom" },
];

interface Template {
  id: string;
  name: string;
  description: string | null;
  category: string | null;
  is_global: boolean;
  created_at: string;
  profiles?: { full_name: string } | null;
}

export function TemplatesClient({ templates }: { templates: Template[] }) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleCreate = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);

    startTransition(async () => {
      const result = await createTemplate(
        fd.get("name") as string,
        fd.get("category") as string,
        fd.get("description") as string,
        { blocks: DEFAULT_CASE_BLOCKS },
        fd.has("is_global")
      );
      if (result?.error) setError(result.error);
      else setShowForm(false);
    });
  };

  const handleDelete = (id: string) => {
    if (!confirm("Delete this template?")) return;
    startTransition(async () => {
      await deleteTemplate(id);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Templates</h1>
          <p className="text-sm text-slate-400 mt-1">Reusable document templates for quick case creation</p>
        </div>
        <Button
          size="sm"
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs"
        >
          {showForm ? "Cancel" : "+ New Template"}
        </Button>
      </div>

      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">New Template</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreate} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Name *</Label>
                  <Input name="name" required className="bg-white/5 border-white/10 text-white h-8 text-sm" />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Category</Label>
                  <select name="category" className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1.5 text-sm text-white h-8">
                    {CATEGORIES.map((c) => (
                      <option key={c.value} value={c.value} className="bg-slate-900">{c.label}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Description</Label>
                <Textarea name="description" rows={2} className="bg-white/5 border-white/10 text-white text-sm resize-none placeholder:text-slate-600" placeholder="What is this template for?" />
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" name="is_global" id="is_global" className="rounded border-white/10" />
                <Label htmlFor="is_global" className="text-xs text-slate-400">Available to all departments</Label>
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Creating..." : "Create Template"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {templates.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No templates yet</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {templates.map((t) => (
            <Card key={t.id} className="bg-white/5 border-white/5 hover:border-white/10 transition-colors">
              <CardContent className="py-3">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold text-white">{t.name}</p>
                    {t.description && <p className="text-xs text-slate-400 mt-0.5">{t.description}</p>}
                    <div className="flex items-center gap-2 mt-1.5">
                      <span className={cn(
                        "text-[10px] px-1.5 py-0.5 rounded",
                        t.category === "case_sheet" ? "text-blue-400 bg-blue-500/10" :
                        t.category === "discharge_summary" ? "text-amber-400 bg-amber-500/10" :
                        t.category === "procedure_note" ? "text-purple-400 bg-purple-500/10" :
                        "text-slate-400 bg-white/5"
                      )}>
                        {CATEGORIES.find((c) => c.value === t.category)?.label || t.category}
                      </span>
                      {t.is_global && <span className="text-[10px] text-emerald-400">Global</span>}
                      {t.profiles && <span className="text-[10px] text-slate-500">{(t.profiles as { full_name: string }).full_name}</span>}
                    </div>
                  </div>
                  <button
                    onClick={() => handleDelete(t.id)}
                    disabled={isPending}
                    className="text-slate-600 hover:text-red-400 text-xs shrink-0"
                    title="Delete"
                  >
                    ✕
                  </button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
