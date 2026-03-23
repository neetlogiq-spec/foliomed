"use server";

import { createClient } from "@/lib/supabase/server";

interface ExtractResult {
  success?: boolean;
  data?: Record<string, unknown>;
  error?: string;
}

export async function extractCaseData(
  imageBase64: string,
  context: "patient_admission" | "lab_report" | "progress_note"
): Promise<ExtractResult> {
  const supabase = await createClient();

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return { error: "Not authenticated" };
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!supabaseUrl) {
    return { error: "Supabase URL not configured" };
  }

  try {
    const res = await fetch(
      `${supabaseUrl}/functions/v1/extract-case-data`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ image_base64: imageBase64, context }),
      }
    );

    if (!res.ok) {
      const errData = await res.json().catch(() => ({}));
      return { error: errData.error || `Extraction failed (${res.status})` };
    }

    const result = await res.json();
    return { success: true, data: result.data };
  } catch (err) {
    console.error("OCR extraction error:", err);
    return { error: "Network error. Please try again." };
  }
}
