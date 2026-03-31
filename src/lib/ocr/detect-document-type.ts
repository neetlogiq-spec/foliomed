import type { ExtractionContext } from "@/app/(app)/ocr-actions";

const VALID_CONTEXTS = new Set<ExtractionContext>([
  "patient_admission",
  "lab_report",
  "progress_note",
  "case_document",
]);

/**
 * Gemini first-pass: classify a medical document image into one of the four
 * extraction contexts. Returns "case_document" as a safe fallback on failure.
 */
export async function detectDocumentType(
  base64: string,
  mimeType: string
): Promise<ExtractionContext> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return "case_document";

  const model = "gemini-2.5-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const prompt = `You are classifying a medical document image from an Indian hospital.

Classify this image as exactly ONE of these types:
- patient_admission  (admission form, registration form, OP/IP card with patient demographics)
- lab_report         (laboratory test results, blood reports, urine reports, imaging reports)
- progress_note      (daily progress note, SOAP note, nursing note, doctor's note)
- case_document      (discharge summary, referral letter, case sheet, case summary, consent form, or anything else)

Return ONLY this JSON with no explanation:
{"type": "lab_report"}`;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { inline_data: { mime_type: mimeType, data: base64 } },
              { text: prompt },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          responseMimeType: "application/json",
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    });

    if (!res.ok) return "case_document";

    const json = await res.json();
    const rawText: string = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!rawText) return "case_document";

    // Parse and validate
    const stripped = rawText
      .replace(/^```(?:json)?\s*/im, "")
      .replace(/\s*```\s*$/m, "")
      .trim();

    const parsed = JSON.parse(stripped);
    const detectedType = parsed?.type as string;

    if (VALID_CONTEXTS.has(detectedType as ExtractionContext)) {
      return detectedType as ExtractionContext;
    }
    return "case_document";
  } catch {
    return "case_document";
  }
}
