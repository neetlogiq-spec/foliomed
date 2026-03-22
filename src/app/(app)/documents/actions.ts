"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { DEFAULT_CASE_BLOCKS } from "@/types/document";

export async function createDocument(patientId: string, title: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const { data, error } = await supabase
    .from("case_documents")
    .insert({
      patient_id: patientId,
      title: title || "Case Document",
      content: { blocks: DEFAULT_CASE_BLOCKS },
      version: 1,
      is_draft: true,
      created_by: user.id,
    })
    .select("id")
    .single();

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  revalidatePath("/documents");
  return { id: data.id };
}

export async function saveDocument(
  docId: string,
  content: { blocks: unknown[] },
  title?: string
) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  // Get current version
  const { data: doc } = await supabase
    .from("case_documents")
    .select("version, patient_id")
    .eq("id", docId)
    .single();

  if (!doc) return { error: "Document not found" };

  const newVersion = (doc.version || 1) + 1;

  // Save version history
  await supabase.from("case_document_versions").insert({
    document_id: docId,
    content,
    version: newVersion,
    saved_by: user.id,
  });

  // Update main document
  const updates: Record<string, unknown> = {
    content,
    version: newVersion,
    updated_at: new Date().toISOString(),
  };
  if (title) updates.title = title;

  const { error } = await supabase
    .from("case_documents")
    .update(updates)
    .eq("id", docId);

  if (error) return { error: error.message };
  revalidatePath(`/documents/${docId}`);
  return { success: true, version: newVersion };
}

export async function publishDocument(docId: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from("case_documents")
    .update({ is_draft: false, updated_at: new Date().toISOString() })
    .eq("id", docId);

  if (error) return { error: error.message };
  revalidatePath(`/documents/${docId}`);
  revalidatePath("/documents");
  return { success: true };
}
