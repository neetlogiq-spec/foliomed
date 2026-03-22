import { createClient } from "@/lib/supabase/server";
import Link from "next/link";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export default async function DocumentsListPage() {
  const supabase = await createClient();

  const { data: docs } = await supabase
    .from("case_documents")
    .select(`*, patients:patient_id ( first_name, last_name, mrd_number ), profiles:created_by ( full_name )`)
    .order("updated_at", { ascending: false })
    .limit(50);

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white">Case Documents</h1>
          <p className="text-sm text-slate-400 mt-1">Block-based clinical case sheets</p>
        </div>
      </div>

      {!docs || docs.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400">No documents yet</p>
          <p className="text-sm text-slate-500 mt-1">Create one from a patient&apos;s detail page</p>
        </div>
      ) : (
        <div className="space-y-2">
          {docs.map((doc) => {
            const patient = doc.patients as { first_name: string; last_name?: string; mrd_number: string } | null;
            const author = doc.profiles as { full_name: string } | null;
            return (
              <Link key={doc.id} href={`/documents/${doc.id}`}>
                <Card className="bg-white/5 border-white/5 hover:border-blue-500/20 transition-colors cursor-pointer">
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
                        {patient && (
                          <span className="text-blue-400">
                            {patient.first_name} {patient.last_name || ""} — {patient.mrd_number}
                          </span>
                        )}
                        {author && <span>{author.full_name}</span>}
                      </div>
                    </div>
                    <span className="text-[10px] text-slate-500 shrink-0">
                      {new Date(doc.updated_at).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}
                    </span>
                  </CardContent>
                </Card>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
