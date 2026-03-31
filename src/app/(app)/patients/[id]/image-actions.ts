"use server";

import { createClient, createAdminClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function uploadPatientImage(
  patientId: string,
  formData: FormData
) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  const file = formData.get("file") as File;
  if (!file || file.size === 0) return { error: "No file selected" };

  const caption = (formData.get("caption") as string) || null;
  const category = (formData.get("category") as string) || "other";

  // Generate unique path: patient_id/timestamp_filename
  const ext = file.name.split(".").pop() || "jpg";
  const fileName = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const filePath = `${patientId}/${fileName}`;

  // Upload to Supabase Storage
  const { error: uploadError } = await supabase.storage
    .from("patient-images")
    .upload(filePath, file, {
      cacheControl: "3600",
      upsert: false,
    });

  if (uploadError) return { error: uploadError.message };

  // Save record in patient_images table
  const { error: dbError } = await supabase.from("patient_images").insert({
    patient_id: patientId,
    uploaded_by: user.id,
    file_path: filePath,
    file_name: file.name,
    file_size: file.size,
    mime_type: file.type,
    caption,
    category,
  });

  if (dbError) return { error: dbError.message };

  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}

export async function getImageUrl(filePath: string) {
  const supabase = await createClient();
  const { data } = await supabase.storage
    .from("patient-images")
    .createSignedUrl(filePath, 3600); // 1 hour

  return data?.signedUrl || null;
}

export async function getImageUrls(filePaths: string[]): Promise<Record<string, string>> {
  if (!filePaths.length) return {};
  const supabase = await createClient();
  const { data } = await supabase.storage
    .from("patient-images")
    .createSignedUrls(filePaths, 3600);

  if (!data) return {};
  return Object.fromEntries(
    data.filter((d) => d.signedUrl).map((d) => [d.path, d.signedUrl])
  );
}

export async function deletePatientImage(imageId: string, filePath: string, patientId: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Not authenticated" };

  // Delete from storage (use user client — storage policies handle this)
  // Storage deletion is best-effort; proceed even if it fails so the DB record
  // is still removed and the image is no longer accessible via the app.
  await supabase.storage.from("patient-images").remove([filePath]);

  // Delete DB record via admin client to bypass RLS
  const admin = createAdminClient();
  const { error } = await admin
    .from("patient_images")
    .delete()
    .eq("id", imageId);

  if (error) return { error: error.message };
  revalidatePath(`/patients/${patientId}`);
  return { success: true };
}
