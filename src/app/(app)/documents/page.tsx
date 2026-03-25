import { createClient } from "@/lib/supabase/server";
import { DocumentsListClient } from "./DocumentsListClient";

export default async function DocumentsListPage() {
  const supabase = await createClient();

  const { data: docs } = await supabase
    .from("case_documents")
    .select(`*, patients:patient_id ( first_name, last_name ), profiles:created_by ( full_name )`)
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
      <DocumentsListClient docs={(docs ?? []) as Parameters<typeof DocumentsListClient>[0]["docs"]} />
    </div>
  );
}
