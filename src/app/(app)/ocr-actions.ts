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

/**
 * Extract the first valid JSON object or array from a string.
 * Handles cases where Gemini wraps JSON in prose or markdown fences.
 */
function extractJson(raw: string): Record<string, unknown> | null {
  // Strip markdown code fences
  let text = raw
    .replace(/^```(?:json)?\s*/im, "")
    .replace(/\s*```\s*$/m, "")
    .trim();

  // Try direct parse first
  try { return JSON.parse(text); } catch { /* fall through */ }

  // Find the outermost { … } block
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start !== -1 && end > start) {
    try { return JSON.parse(text.slice(start, end + 1)); } catch { /* fall through */ }
  }

  return null;
}

/* ── Prompts ──────────────────────────────── */

function buildPrompt(context: ExtractionContext): string {
  const preamble = `You are a medical document OCR and data extraction assistant specialising in Indian hospital records.
Carefully read every part of the image and extract all visible information.

STRICT OUTPUT RULES:
- Return ONLY a valid JSON object. No explanation, no prose, no markdown.
- Use JSON null (not the string "null") for any field you cannot find.
- Never copy placeholder text or field names as values.
- When in doubt about a value, still extract your best reading and mark confidence "low".`;

  switch (context) {
    case "patient_admission":
      return `${preamble}

Extract patient admission details from the image. Return exactly this JSON (replace example values with what you read):

{
  "ip_number": "123456",
  "first_name": "Ravi",
  "last_name": "Kumar",
  "date_of_birth": "2020-03-15",
  "age_years": 4,
  "age_months": 2,
  "gender": "male",
  "weight_kg": 14.5,
  "height_cm": 98,
  "blood_group": "B+",
  "guardian_name": "Suresh Kumar",
  "guardian_relation": "Father",
  "phone": "9876543210",
  "address": "123 Main Road, Chennai",
  "diagnosis": "Acute gastroenteritis",
  "ward": "Paediatric Ward",
  "bed_number": "12",
  "admission_date": "2024-01-15",
  "confidence": {
    "ip_number": "high",
    "first_name": "high",
    "diagnosis": "medium"
  }
}`;

    case "lab_report":
      return `${preamble}

Extract ALL laboratory test results from this lab report. Include every test row visible.
For "flag": use "high" if value is above reference range, "low" if below, "normal" if within range, null if unclear.
Return exactly this JSON structure:

{
  "report_date": "2024-01-15",
  "patient_name": "Ravi Kumar",
  "lab_name": "City Diagnostic Centre",
  "tests": [
    {
      "name": "Haemoglobin",
      "value": "9.8",
      "unit": "g/dL",
      "reference": "11.0 - 17.0",
      "flag": "low",
      "confidence": "high"
    },
    {
      "name": "Total WBC",
      "value": "11200",
      "unit": "cells/μL",
      "reference": "4000 - 11000",
      "flag": "high",
      "confidence": "medium"
    }
  ],
  "confidence": {
    "overall": "high"
  }
}`;

    case "progress_note":
      return `${preamble}

Extract the clinical progress note / SOAP note from this document.
For vitals, extract the exact values written (e.g. "38.5°C", "110/min") — do not convert units.
Return exactly this JSON structure:

{
  "date": "2024-01-15",
  "subjective": "Child has had fever for 3 days. Decreased oral intake. No vomiting.",
  "objective": "Child is irritable. Mild dehydration present.",
  "assessment": "Viral fever with mild dehydration",
  "plan": "IV fluids at 60 mL/hr. Tab Paracetamol 15 mg/kg TDS. Monitor input-output.",
  "vitals": {
    "temperature": "38.5°C",
    "pulse": "118/min",
    "bp": "90/60 mmHg",
    "spo2": "98%",
    "rr": "28/min",
    "weight": "14 kg"
  },
  "fluid_input_ml": 450,
  "fluid_output_ml": 320,
  "confidence": {
    "subjective": "high",
    "objective": "high",
    "assessment": "medium",
    "plan": "high",
    "vitals": "high"
  }
}`;

    case "case_document":
      return `${preamble}

Extract all clinical content from this case document. Identify distinct sections (headings and their content).
Preserve the exact text — do not summarise or paraphrase.
Return exactly this JSON structure:

{
  "title": "Case Summary — Ravi Kumar",
  "sections": [
    {
      "title": "Chief Complaint",
      "content": "Fever for 3 days, decreased oral intake",
      "type": "text"
    },
    {
      "title": "Examination Findings",
      "content": "Temp 38.5°C, HR 118/min, mildly dehydrated, no rash",
      "type": "findings"
    },
    {
      "title": "Treatment Plan",
      "content": "IV fluids, antipyretics, monitor vitals 4-hourly",
      "type": "plan"
    }
  ],
  "raw_text": "Full verbatim text of the document goes here",
  "confidence": {
    "overall": "high"
  }
}`;
  }
}

/* ── Direct Gemini call ───────────────────── */

async function callGeminiDirect(
  base64: string,
  mimeType: string,
  context: ExtractionContext
): Promise<ExtractResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return { error: "GEMINI_API_KEY not configured" };

  // gemini-2.5-flash is a thinking model — disable thinking for structured extraction:
  // thinking tokens interfere with JSON output mode and produce empty/malformed responses.
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
      temperature: 0,          // deterministic — no creativity needed for data extraction
      responseMimeType: "application/json",
      thinkingConfig: {
        thinkingBudget: 0,     // disable thinking mode — produces cleaner JSON output
      },
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
    if (res.status === 400 && msg.toLowerCase().includes("api key")) {
      msg = "Gemini API key invalid — check GEMINI_API_KEY in .env.local.";
    }
    console.error("[OCR] Gemini error:", res.status, msg);
    return { error: msg };
  }

  const json = await res.json();

  // Check for content blocks (e.g. safety filter triggered)
  const finishReason = json?.candidates?.[0]?.finishReason;
  if (finishReason && finishReason !== "STOP") {
    console.warn("[OCR] Gemini finish reason:", finishReason);
  }

  const rawText: string = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!rawText) return { error: "Gemini returned an empty response — image may be unreadable or blocked by safety filters." };

  const data = extractJson(rawText);
  if (data) return { success: true, data };

  // Last resort: return raw text so the user can see what Gemini read
  console.warn("[OCR] Could not parse JSON from Gemini response:", rawText.slice(0, 200));
  return { success: true, data: { raw_text: rawText } };
}

/* ── Supabase edge function fallback ─────── */

type EdgeContext = "patient_admission" | "lab_report" | "progress_note";
const EDGE_CONTEXT_MAP: Record<ExtractionContext, EdgeContext> = {
  patient_admission: "patient_admission",
  lab_report: "lab_report",
  progress_note: "progress_note",
  case_document: "progress_note",
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

  if (process.env.GEMINI_API_KEY) {
    return callGeminiDirect(base64, mimeType, context);
  }

  console.warn("[OCR] GEMINI_API_KEY not set — using edge function fallback.");
  return callEdgeFunction(base64, mimeType, context);
}

export async function extractCaseDataBatch(
  images: string[],
  context: ExtractionContext
): Promise<ExtractResult[]> {
  return Promise.all(images.map((img) => extractCaseData(img, context)));
}

/* ── Auto-detect + extract ────────────────── */

export async function detectAndExtract(
  imageBase64: string
): Promise<{ context: ExtractionContext; result: ExtractResult }> {
  const { detectDocumentType } = await import("@/lib/ocr/detect-document-type");
  const { base64, mimeType } = parseDataUrl(imageBase64);
  const context = await detectDocumentType(base64, mimeType);
  const result = await extractCaseData(imageBase64, context);
  return { context, result };
}
