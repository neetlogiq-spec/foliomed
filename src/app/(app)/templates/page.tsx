import { createClient } from "@/lib/supabase/server";
import { TemplatesClient } from "./TemplatesClient";

export default async function TemplatesPage() {
  const supabase = await createClient();

  const { data: templates } = await supabase
    .from("document_templates")
    .select(`*, profiles:created_by ( full_name )`)
    .order("created_at", { ascending: false });

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <TemplatesClient templates={templates ?? []} />
    </div>
  );
}
