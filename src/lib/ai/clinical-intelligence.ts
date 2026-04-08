"use server";

/**
 * Clinical AI Intelligence Layer
 *
 * Runs a second Gemini pass on extracted OCR data to:
 * 1. Validate lab values against paediatric reference ranges
 * 2. Flag critical/abnormal values with clinical significance
 * 3. Check medication doses against weight-based paediatric guidelines
 * 4. Cross-reference findings (e.g. raised urea + creatinine → renal impairment)
 * 5. Generate a concise clinical summary with actionable insights
 *
 * This is NOT a diagnostic tool — it assists clinicians by surfacing important patterns.
 */

export interface ClinicalAlert {
  severity: "critical" | "warning" | "info";
  field: string;
  message: string;
}

export interface ClinicalInsight {
  alerts: ClinicalAlert[];
  summary: string;
  suggestions: string[];
}

export async function analyzeClinicalData(
  extractedData: Record<string, unknown>,
  context: string,
  patientContext?: {
    age_days?: number;
    weight_kg?: number;
    diagnosis?: string;
    active_medications?: string[];
  }
): Promise<ClinicalInsight | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const patientInfo = patientContext
    ? `\nPatient context: Age ${patientContext.age_days ?? "unknown"} days, Weight ${patientContext.weight_kg ?? "unknown"} kg, Diagnosis: ${patientContext.diagnosis ?? "unknown"}, Current medications: ${patientContext.active_medications?.join(", ") || "none"}`
    : "";

  const prompt = `You are a clinical decision support assistant for a paediatric/neonatal unit in an Indian hospital.
You are NOT making diagnoses — you are flagging important patterns for the attending clinician.

Analyze the following extracted medical data and provide clinical insights.${patientInfo}

EXTRACTED DATA (${context}):
${JSON.stringify(extractedData, null, 2)}

TASKS:
1. FLAG abnormal values with clinical significance:
   - Lab values: compare against age-appropriate paediatric reference ranges
   - Vitals: flag values outside safe ranges for the patient's age
   - Medication doses: check if weight-based doses are within standard paediatric guidelines
2. CROSS-REFERENCE findings (e.g. elevated urea + creatinine = renal concern)
3. GENERATE a 1-2 sentence clinical summary highlighting the most important findings
4. SUGGEST up to 3 actionable next steps based on the data

SEVERITY LEVELS:
- "critical": Immediate attention needed (e.g. creatinine 1.92 in a child, SpO2 < 90%)
- "warning": Abnormal, needs monitoring (e.g. mildly elevated urea, borderline vitals)
- "info": Notable but not urgent (e.g. pending investigations, resolved conditions)

Return ONLY this JSON:
{
  "alerts": [
    { "severity": "critical", "field": "creatinine", "message": "Creatinine 1.92 mg/dL is significantly elevated for a paediatric patient (ref: 0.4-1.2). Suggests acute kidney injury." },
    { "severity": "warning", "field": "urea", "message": "Urea 112 mg/dL is elevated (ref: 16.6-48.5). Consistent with renal impairment." }
  ],
  "summary": "Lab results show significantly impaired renal function with elevated creatinine and urea. Chloride is mildly elevated. Electrolytes otherwise within normal limits.",
  "suggestions": [
    "Repeat RFT in 12-24 hours to assess trend",
    "Check urine output and fluid balance",
    "Consider nephrology consultation if creatinine does not improve"
  ]
}`;

  const model = "gemini-2.5-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1, // Slightly above 0 to allow clinical reasoning nuance
          responseMimeType: "application/json",
          thinkingConfig: {
            thinkingBudget: 2048, // Allow thinking for clinical reasoning
          },
        },
      }),
    });

    if (!res.ok) {
      console.error("[Clinical AI] Gemini error:", res.status);
      return null;
    }

    const json = await res.json();
    const rawText: string = json?.candidates?.[0]?.content?.parts
      ?.filter((p: { text?: string }) => p.text)
      ?.map((p: { text: string }) => p.text)
      ?.join("") ?? "";

    if (!rawText) return null;

    const stripped = rawText
      .replace(/^```(?:json)?\s*/im, "")
      .replace(/\s*```\s*$/m, "")
      .trim();

    const parsed = JSON.parse(stripped) as ClinicalInsight;

    // Validate structure
    if (!Array.isArray(parsed.alerts) || typeof parsed.summary !== "string") {
      return null;
    }

    return parsed;
  } catch (err) {
    console.error("[Clinical AI] Error:", err instanceof Error ? err.message : err);
    return null;
  }
}
