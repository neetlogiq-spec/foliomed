"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createDocument } from "../../documents/actions";

interface CaseDoc {
  id: string;
  title: string;
  is_draft: boolean;
  version: number;
  updated_at: string;
}

interface PatientDocumentsTabProps {
  patientId: string;
  documents: CaseDoc[];
}

export function PatientDocumentsTab({ patientId, documents }: PatientDocumentsTabProps) {
  const [isPending, startTransition] = useTransition();
  const router = useRouter();

  const handleCreate = () => {
    startTransition(async () => {
      const result = await createDocument(patientId, "Case Document");
      if (result?.id) router.push(`/documents/${result.id}`);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Case Documents ({documents.length})
        </h3>
        <button
          onClick={handleCreate}
          disabled={isPending}
          className="text-xs px-3 py-1.5 rounded-md bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white transition-colors"
        >
          {isPending ? "Creating…" : "+ New Document"}
        </button>
      </div>

      {documents.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No case documents yet</p>
      ) : (
        <div className="space-y-2">
          {documents.map((doc) => (
            <Link
              key={doc.id}
              href={`/documents/${doc.id}`}
              className="flex items-center justify-between bg-white/5 border border-white/5 hover:border-blue-500/30 rounded-lg p-3 transition-colors group"
            >
              <div className="flex items-center gap-3 min-w-0">
                <svg
                  className="w-4 h-4 text-slate-500 group-hover:text-blue-400 shrink-0 transition-colors"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                  />
                </svg>
                <span className="text-sm text-white truncate">{doc.title}</span>
              </div>
              <div className="flex items-center gap-3 shrink-0 ml-3">
                <span
                  className={`text-[10px] px-1.5 py-0.5 rounded-full border font-medium ${
                    doc.is_draft
                      ? "bg-amber-500/15 text-amber-400 border-amber-500/20"
                      : "bg-emerald-500/15 text-emerald-400 border-emerald-500/20"
                  }`}
                >
                  {doc.is_draft ? "Draft" : "Published"}
                </span>
                <span className="text-[10px] text-slate-500">
                  v{doc.version} ·{" "}
                  {new Date(doc.updated_at).toLocaleDateString("en-IN", {
                    day: "2-digit",
                    month: "short",
                  })}
                </span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
