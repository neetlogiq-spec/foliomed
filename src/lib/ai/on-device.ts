/**
 * On-Device AI using Chrome Built-in AI (Gemini Nano)
 *
 * Chrome 127+ ships Gemini Nano on-device. When available, we use it for:
 * - Instant field validation (no network round-trip)
 * - Quick text summarization
 * - Abbreviation expansion
 * - Offline fallback for basic AI tasks
 *
 * Feature detection:
 *   window.ai?.languageModel → Prompt API (Chrome 127+)
 *
 * If unavailable, all functions return null and callers fall back to server-side.
 */

/* ── Type declarations for Chrome Built-in AI ── */

interface AILanguageModel {
  prompt(input: string, options?: { signal?: AbortSignal }): Promise<string>;
  destroy(): void;
}

interface AILanguageModelFactory {
  capabilities(): Promise<{ available: "readily" | "after-download" | "no" }>;
  create(options?: {
    systemPrompt?: string;
    temperature?: number;
    topK?: number;
  }): Promise<AILanguageModel>;
}

interface AIWindow {
  ai?: {
    languageModel?: AILanguageModelFactory;
  };
}

/* ── Singleton session ── */

let _session: AILanguageModel | null = null;
let _available: boolean | null = null;

/**
 * Check if on-device AI is available in the current browser.
 * Caches the result after first check.
 */
export async function isOnDeviceAIAvailable(): Promise<boolean> {
  if (_available !== null) return _available;

  try {
    const win = window as unknown as AIWindow;
    const factory = win.ai?.languageModel;
    if (!factory) {
      _available = false;
      return false;
    }
    const caps = await factory.capabilities();
    _available = caps.available === "readily";
    return _available;
  } catch {
    _available = false;
    return false;
  }
}

/**
 * Get or create a reusable on-device AI session.
 */
async function getSession(): Promise<AILanguageModel | null> {
  if (_session) return _session;

  const available = await isOnDeviceAIAvailable();
  if (!available) return null;

  try {
    const win = window as unknown as AIWindow;
    _session = await win.ai!.languageModel!.create({
      systemPrompt:
        "You are a medical data assistant for a paediatric hospital. " +
        "Respond concisely in JSON when asked. Do not add explanations.",
      temperature: 0,
      topK: 1,
    });
    return _session;
  } catch {
    _available = false;
    return null;
  }
}

/**
 * Destroy the on-device session (e.g. on page unload).
 */
export function destroySession(): void {
  _session?.destroy();
  _session = null;
}

/* ── On-Device AI Functions ── */

/**
 * Validate a single field value using on-device AI.
 * Returns a brief validation result or null if unavailable.
 */
export async function validateFieldOnDevice(
  fieldName: string,
  value: string,
  context?: string
): Promise<{ valid: boolean; message?: string } | null> {
  const session = await getSession();
  if (!session) return null;

  try {
    const response = await session.prompt(
      `Validate this medical field. Return JSON: {"valid": true/false, "message": "brief reason if invalid"}
Field: ${fieldName}
Value: ${value}
${context ? `Context: ${context}` : ""}`,
      { signal: AbortSignal.timeout(3000) }
    );

    const parsed = JSON.parse(response);
    return { valid: !!parsed.valid, message: parsed.message };
  } catch {
    return null;
  }
}

/**
 * Generate a quick summary of extracted data using on-device AI.
 * Useful for generating one-liner descriptions.
 */
export async function summarizeOnDevice(
  text: string,
  maxWords = 30
): Promise<string | null> {
  const session = await getSession();
  if (!session) return null;

  try {
    const response = await session.prompt(
      `Summarize this medical text in ${maxWords} words or less. Return plain text, no JSON:\n${text}`,
      { signal: AbortSignal.timeout(5000) }
    );
    return response.trim();
  } catch {
    return null;
  }
}

/**
 * Expand medical abbreviations using on-device AI.
 * Faster than a server round-trip for real-time editing.
 */
export async function expandAbbreviationOnDevice(
  abbreviation: string
): Promise<string | null> {
  const session = await getSession();
  if (!session) return null;

  try {
    const response = await session.prompt(
      `What does the medical abbreviation "${abbreviation}" stand for? Return only the full form, nothing else.`,
      { signal: AbortSignal.timeout(2000) }
    );
    return response.trim();
  } catch {
    return null;
  }
}

/**
 * Quick clinical flag check — is this lab value abnormal for a paediatric patient?
 */
export async function checkLabValueOnDevice(
  testName: string,
  value: string,
  unit: string,
  patientAge?: string
): Promise<{ flag: "normal" | "high" | "low" | "critical"; message?: string } | null> {
  const session = await getSession();
  if (!session) return null;

  try {
    const response = await session.prompt(
      `Is this lab value normal for a paediatric patient${patientAge ? ` aged ${patientAge}` : ""}?
Test: ${testName}, Value: ${value} ${unit}
Return JSON: {"flag": "normal"|"high"|"low"|"critical", "message": "brief clinical note"}`,
      { signal: AbortSignal.timeout(3000) }
    );

    return JSON.parse(response);
  } catch {
    return null;
  }
}
