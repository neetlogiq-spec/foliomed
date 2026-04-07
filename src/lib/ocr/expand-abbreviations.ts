/**
 * Post-process OCR extraction results to expand common medical abbreviations.
 * Only expands standalone abbreviations that are NOT already followed by their expansion.
 *
 * Usage: call expandAbbreviationsInData(data) on the extracted JSON before displaying.
 */

const ABBREVIATIONS: Record<string, string> = {
  // Neonatal
  TTNB: "Transient Tachypnea of the Newborn",
  NVD: "Normal Vaginal Delivery",
  AGA: "Appropriate for Gestational Age",
  SGA: "Small for Gestational Age",
  LGA: "Large for Gestational Age",
  LBW: "Low Birth Weight",
  VLBW: "Very Low Birth Weight",
  ELBW: "Extremely Low Birth Weight",
  NNH: "Neonatal Hyperbilirubinemia",
  RDS: "Respiratory Distress Syndrome",
  NEC: "Necrotizing Enterocolitis",
  PDA: "Patent Ductus Arteriosus",
  ROP: "Retinopathy of Prematurity",
  NICU: "Neonatal Intensive Care Unit",
  PICU: "Paediatric Intensive Care Unit",
  OAE: "Otoacoustic Emissions",
  BERA: "Brainstem Evoked Response Audiometry",
  LSCS: "Lower Segment Caesarean Section",

  // Respiratory support
  HFNC: "High Flow Nasal Cannula",
  CPAP: "Continuous Positive Airway Pressure",
  IPPV: "Intermittent Positive Pressure Ventilation",
  SIMV: "Synchronized Intermittent Mandatory Ventilation",
  PEEP: "Positive End-Expiratory Pressure",
  FiO2: "Fraction of Inspired Oxygen",

  // Feeding
  DBF: "Direct Breast Feeding",
  EBM: "Expressed Breast Milk",
  NPO: "Nil Per Os",
  OGT: "Orogastric Tube",
  NGT: "Nasogastric Tube",

  // Frequency / Route
  TDS: "Three Times Daily",
  TID: "Three Times Daily",
  BD: "Twice Daily",
  BID: "Twice Daily",
  QID: "Four Times Daily",
  OD: "Once Daily",
  SOS: "If Needed",
  PRN: "As Needed",
  PO: "Per Oral",
  IV: "Intravenous",
  IM: "Intramuscular",
  SC: "Subcutaneous",
  Q6H: "Every 6 Hours",
  Q8H: "Every 8 Hours",
  Q12H: "Every 12 Hours",

  // Investigations & labs
  CBC: "Complete Blood Count",
  CRP: "C-Reactive Protein",
  RFT: "Renal Function Test",
  LFT: "Liver Function Test",
  TFT: "Thyroid Function Test",
  TSH: "Thyroid Stimulating Hormone",
  ABG: "Arterial Blood Gas",
  USG: "Ultrasonography",
  MRI: "Magnetic Resonance Imaging",
  CT: "Computed Tomography",
  ECG: "Electrocardiogram",
  NSG: "Neurosonogram",

  // General
  RLS: "Revised Lumbar Score",
  ENT: "Ear Nose Throat",
  GCS: "Glasgow Coma Scale",
  CVS: "Cardiovascular System",
  CNS: "Central Nervous System",
  GIT: "Gastrointestinal Tract",
  RS: "Respiratory System",
  BP: "Blood Pressure",
  HR: "Heart Rate",
  RR: "Respiratory Rate",
  SpO2: "Oxygen Saturation",
};

/**
 * Expand a standalone abbreviation in text.
 * Only expands if the abbreviation is NOT already followed by parenthesised expansion.
 * E.g. "TTNB" → "TTNB (Transient Tachypnea of the Newborn)"
 * But  "TTNB (Transient Tachypnea of the Newborn)" stays unchanged.
 */
function expandInText(text: string): string {
  let result = text;
  for (const [abbr, full] of Object.entries(ABBREVIATIONS)) {
    // Match the abbreviation as a standalone word, not already followed by " (expansion)"
    const regex = new RegExp(
      `\\b${escapeRegex(abbr)}\\b(?!\\s*\\(${escapeRegex(full.slice(0, 10))})`,
      "g"
    );
    result = result.replace(regex, `${abbr} (${full})`);
  }
  return result;
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Recursively walk an extracted data object and expand abbreviations in all string values.
 * Skips keys that are likely not free-text (dates, numbers, confidence).
 */
const SKIP_KEYS = new Set([
  "date", "report_date", "admission_date", "date_of_birth",
  "confidence", "flag", "unit", "reference", "ip_number",
  "phone", "bed_number", "ward", "_source", "_fallback",
]);

export function expandAbbreviationsInData<T>(data: T): T {
  if (data === null || data === undefined) return data;
  if (typeof data === "string") return expandInText(data) as T;
  if (Array.isArray(data)) return data.map((item) => expandAbbreviationsInData(item)) as T;
  if (typeof data === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(data as Record<string, unknown>)) {
      if (SKIP_KEYS.has(key) || typeof value === "number" || typeof value === "boolean") {
        result[key] = value;
      } else {
        result[key] = expandAbbreviationsInData(value);
      }
    }
    return result as T;
  }
  return data;
}
