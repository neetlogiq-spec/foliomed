import { createClient } from "@/lib/supabase/server";
import { HandoverClient } from "./HandoverClient";
import { RealtimeProvider } from "@/components/shared/RealtimeProvider";

export default async function HandoverPage() {
  const supabase = await createClient();

  const { data: notes } = await supabase
    .from("handover_notes")
    .select(`*, from_profile:from_user_id ( full_name ), to_profile:to_user_id ( full_name )`)
    .order("handover_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(50);

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Handover Notes</h1>
        <p className="text-sm text-slate-400 mt-1">Shift handover with patient summaries and pending tasks</p>
      </div>
      <HandoverClient notes={notes ?? []} />
      <RealtimeProvider tables={["handover_notes"]} />
    </div>
  );
}
