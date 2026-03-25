"use server";

export type ExtractionContext =
  | "patient_admission"
  | "lab_report"
  | "progress_note"
  | "case_document";

export interface ExtractResult {
  success?: boolean;
  data?: Record<string, unknown>;
  error?: string;
}

/* ── Helpers ──────────────────────────────── */

function parseDataUrl(dataUrl: string): { base64: string; mimeType: string } {
  const match = dataUrl.match(/^data:([^;]+);base64,([\s\S]+)$/);
  if (match) return { mimeType: match[1], base64: match[2] };
  return { mimeType: "image/jpeg", base64: dataUrl };
}

function buildPrompt(context: ExtractionContext): string {
  const base =
    "Analyse the image and extract information. Return ONLY valid JSON — no markdown, no code fences, no explanation.";

  const schemas: Record<ExtractionContext, string> = {
    patient_admission: `${base}
Schema:
{
  "ip_number": "string or null",
  "first_name": "string or null",
  "last_name": "string or null",
  "date_of_birth": "YYYY-MM-DD or null",
  "age_years": number or null,
  "gender": "male|female|other or null",
  "weight_kg": number or null,
  "height_cm": number or null,
  "blood_group": "string or null",
  "guardian_name": "string or null",
  "guardian_relation": "string or null",
  "phone": "string or null",
  "address": "string or null",
  "diagnosis": "string or null",
  "confidence": { "<field>": "high|medium|low" }
}`,

    lab_report: `${base}
Schema:
{
  "report_date": "YYYY-MM-DD or null",
  "patient_name": "string or null",
  "tests": [
    { "name": "string", "value": "string", "unit": "string or null", "reference": "string or null", "flag": "normal|high|low or null" }
  ],
  "lab_name": "string or null",
  "confidence": { "<field>": "high|medium|low" }
}`,

    progress_note: `${base}
Schema:
{
  "date": "YYYY-MM-DD or null",
  "subjective": "string or null",
  "objective": "string or null",
  "assessment": "string or null",
  "plan": "string or null",
  "vitals": {
    "temperature": "string or null",
    "pulse": "string or null",
    "bp": "string or null",
    "spo2": "string or null",
    "rr": "string or null",
    "weight": "string or null"
  },
  "fluid_input_ml": number or null,
  "fluid_output_ml": number or null,
  "confidence": { "<field>": "high|medium|low" }
}`,

    case_document: `${base}
Extract all clinical content from this document. Return sections as an array.
Schema:
{
  "title": "string or null",
  "sections": [
    { "title": "string", "content": "string", "type": "heading|text|findings|plan|list" }
  ],
  "raw_text": "full extracted text as a single string",
  "confidence": { "overall": "high|medium|low" }
}`,
  };

  return schemas[context];
}

/* ── Direct Gemini call ───────────────────── */

async function callGeminiDirect(
  base64: string,
  mimeType: string,
  context: ExtractionContext
): Promise<ExtractResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return { error: "GEMINI_API_KEY not configured" };

  const model = "gemini-2.5-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const body = {
    contents: [
      {
        parts: [
          { inline_data: { mime_type: mimeType, data: base64 } },
          { text: buildPrompt(context) },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      responseMimeType: "application/json",
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    let msg = `Gemini API error (${res.status})`;
    try { msg = JSON.parse(errText)?.error?.message ?? msg; } catch { /* ignore */ }
    if (res.status === 429) msg = "Gemini quota exceeded — try again in a moment.";
    if (res.status === 400 && msg.includes("API key")) msg = "Gemini API key invalid — restart the dev server after updating .env.local.";
    console.error("[OCR] Gemini direct error:", res.status, msg);
    return { error: msg };
  }

  const json = await res.json();
  const text: string = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  if (!text) return { error: "Gemini returned empty response" };

  try {
    // Strip any accidental markdown fences
    const cleaned = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
    const data = JSON.parse(cleaned) as Record<string, unknown>;
    return { success: true, data };
  } catch {
    // Gemini sometimes returns free text — wrap it
    return { success: true, data: { raw_text: text } };
  }
}

/* ── Supabase edge function fallback ─────── */

// Edge function only supports these three contexts
type EdgeContext = "patient_admission" | "lab_report" | "progress_note";
const EDGE_CONTEXT_MAP: Record<ExtractionContext, EdgeContext> = {
  patient_admission: "patient_admission",
  lab_report: "lab_report",
  progress_note: "progress_note",
  case_document: "progress_note", // closest supported equivalent
};

async function callEdgeFunction(
  base64: string,
  mimeType: string,
  context: ExtractionContext
): Promise<ExtractResult> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) return { error: "Supabase not configured" };

  const edgeContext = EDGE_CONTEXT_MAP[context];

  try {
    const res = await fetch(`${supabaseUrl}/functions/v1/extract-case-data`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
      },
      body: JSON.stringify({ image_base64: base64, mime_type: mimeType, context: edgeContext }),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      let message = `Edge function error (${res.status})`;
      try { message = JSON.parse(text)?.error ?? message; } catch { if (text) message = text.slice(0, 200); }
      console.error("[OCR] edge function error:", res.status, message);
      return { error: message };
    }

    const result = await res.json();
    return { success: true, data: result.data };
  } catch (err) {
    return { error: `Network error: ${err instanceof Error ? err.message : String(err)}` };
  }
}

/* ── Public API ───────────────────────────── */

export async function extractCaseData(
  imageBase64: string,
  context: ExtractionContext
): Promise<ExtractResult> {
  const { base64, mimeType } = parseDataUrl(imageBase64);

  // Prefer direct Gemini if key is available — avoids edge function entirely
  if (process.env.GEMINI_API_KEY) {
    return callGeminiDirect(base64, mimeType, context);
  }

  // No direct key — fall back to Supabase edge function
  console.warn(
    "[OCR] GEMINI_API_KEY not set. Using edge function fallback. " +
    "Add GEMINI_API_KEY to .env.local for direct Gemini access."
  );
  return callEdgeFunction(base64, mimeType, context);
}

export async function extractCaseDataBatch(
  images: string[],
  context: ExtractionContext
): Promise<ExtractResult[]> {
  return Promise.all(images.map((img) => extractCaseData(img, context)));
}
