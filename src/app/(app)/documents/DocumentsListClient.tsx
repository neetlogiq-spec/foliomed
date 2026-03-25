"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { deleteDocument } from "./actions";

interface Doc {
  id: string;
  title: string;
  is_draft: boolean;
  version: number;
  updated_at: string;
  patient_id: string;
  patients: { first_name: string; last_name?: string } | null;
  profiles: { full_name: string } | null;
}

export function DocumentsListClient({ docs }: { docs: Doc[] }) {
  const router = useRouter();
  const [confirmId, setConfirmId] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleDelete = (id: string) => {
    setError(null);
    startTransition(async () => {
      const result = await deleteDocument(id);
      if (result?.error) {
        setError(result.error);
      } else {
        setConfirmId(null);
        router.refresh();
      }
    });
  };

  if (!docs.length) {
    return (
      <div className="text-center py-16">
        <p className="text-slate-400">No documents yet</p>
        <p className="text-sm text-slate-500 mt-1">Create one from a patient&apos;s detail page</p>
      </div>
    );
  }

  return (
    <>
      {error && (
        <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-xs text-red-400">
          {error}
        </div>
      )}

      <div className="space-y-2">
        {docs.map((doc) => (
          <div key={doc.id} className="group relative">
            <Link href={`/documents/${doc.id}`}>
              <Card className="bg-white/5 border-white/5 hover:border-blue-500/20 transition-colors cursor-pointer pr-10">
                <CardContent className="py-3 flex items-center justify-between gap-4">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="text-sm font-semibold text-white truncate">{doc.title}</span>
                      <span className={cn(
                        "text-[10px] px-1.5 py-0.5 rounded shrink-0",
                        doc.is_draft
                          ? "bg-amber-500/10 text-amber-400"
                          : "bg-emerald-500/10 text-emerald-400"
                      )}>
                        {doc.is_draft ? "Draft" : "Published"}
                      </span>
                      <span className="text-[10px] text-slate-500">v{doc.version}</span>
                    </div>
                    <div className="flex items-center gap-3 text-xs text-slate-400">
                      {doc.patients && (
                        <span className="text-blue-400">
                          {doc.patients.first_name} {doc.patients.last_name || ""}
                        </span>
                      )}
                      {doc.profiles && <span>{doc.profiles.full_name}</span>}
                    </div>
                  </div>
                  <span className="text-[10px] text-slate-500 shrink-0">
                    {new Date(doc.updated_at).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}
                  </span>
                </CardContent>
              </Card>
            </Link>

            {/* Delete button — shown on hover */}
            <button
              onClick={(e) => { e.preventDefault(); setConfirmId(doc.id); }}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1.5 rounded-lg text-slate-600 hover:text-red-400 hover:bg-red-500/10 opacity-0 group-hover:opacity-100 transition-all z-10"
              title="Delete document"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
              </svg>
            </button>
          </div>
        ))}
      </div>

      {/* Confirm delete dialog */}
      {confirmId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-white/10 rounded-xl p-6 w-full max-w-sm shadow-2xl">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-9 h-9 rounded-full bg-red-500/10 flex items-center justify-center shrink-0">
                <svg className="w-4 h-4 text-red-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                </svg>
              </div>
              <div>
                <p className="text-sm font-semibold text-white">Delete document?</p>
                <p className="text-xs text-slate-400 mt-0.5">
                  &ldquo;{docs.find((d) => d.id === confirmId)?.title}&rdquo; will be permanently removed.
                </p>
              </div>
            </div>
            <div className="flex gap-2 mt-4">
              <button
                onClick={() => setConfirmId(null)}
                disabled={isPending}
                className="flex-1 py-2 rounded-lg text-xs font-medium border border-white/10 text-slate-300 hover:bg-white/5 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => handleDelete(confirmId)}
                disabled={isPending}
                className="flex-1 py-2 rounded-lg text-xs font-medium bg-red-600 hover:bg-red-700 text-white transition-colors disabled:opacity-60"
              >
                {isPending ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
