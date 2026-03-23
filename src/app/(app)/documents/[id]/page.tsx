import { createClient } from "@/lib/supabase/server";
import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { DocumentEditor } from "./DocumentEditor";
import type { Block } from "@/types/document";

export default async function DocumentDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  // Get current user for collaborative editing
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const [docRes, profileRes] = await Promise.all([
    supabase
      .from("case_documents")
      .select(`*, patients:patient_id ( first_name, last_name )`)
      .eq("id", id)
      .single(),
    supabase
      .from("profiles")
      .select("full_name, avatar_url")
      .eq("id", user.id)
      .single(),
  ]);

  if (docRes.error || !docRes.data) notFound();
  const doc = docRes.data;
  const profile = profileRes.data;

  const content = doc.content as { blocks?: Block[] } | null;
  const blocks: Block[] = content?.blocks ?? [{ id: "1", type: "text", content: "" }];
  const patient = doc.patients as { first_name: string; last_name?: string } | null;

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-4 flex items-center gap-3">
        <Link href="/documents" className="text-sm text-slate-400 hover:text-slate-200 inline-flex items-center gap-1">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
          </svg>
          Documents
        </Link>
        {patient && (
          <>
            <span className="text-slate-600">·</span>
            <Link href={`/patients/${doc.patient_id}`} className="text-xs text-blue-400 hover:text-blue-300">
              {patient.first_name} {patient.last_name || ""}
            </Link>
          </>
        )}
      </div>

      <DocumentEditor
        docId={doc.id}
        initialTitle={doc.title}
        initialBlocks={blocks}
        initialVersion={doc.version}
        isDraft={doc.is_draft}
        currentUser={{
          id: user.id,
          fullName: profile?.full_name || user.email || "Unknown",
          avatarUrl: profile?.avatar_url || null,
        }}
      />
    </div>
  );
}

