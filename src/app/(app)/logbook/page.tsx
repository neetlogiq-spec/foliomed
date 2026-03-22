import { createClient } from "@/lib/supabase/server";
import { LogbookClient } from "./LogbookClient";

export default async function LogbookPage() {
  const supabase = await createClient();

  const { data: entries } = await supabase
    .from("case_log")
    .select(`*, profiles:user_id ( full_name ), patients:patient_id ( first_name, last_name, mrd_number )`)
    .order("logged_at", { ascending: false })
    .limit(100);

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Case Logbook</h1>
        <p className="text-sm text-slate-400 mt-1">Your clinical case portfolio with diagnoses and procedures</p>
      </div>
      <LogbookClient entries={entries ?? []} />
    </div>
  );
}
