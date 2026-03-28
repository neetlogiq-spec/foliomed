/**
 * Client-side OCR fallback using Tesseract.js.
 *
 * NOTE: Tesseract does basic text extraction only — it has no understanding
 * of document structure. Results are raw text, not structured fields.
 * This is a last-resort fallback when Gemini is unavailable.
 */
export async function ocrWithTesseract(imageBase64: string): Promise<{
  success: boolean;
  data?: Record<string, unknown>;
  error?: string;
}> {
  try {
    const { createWorker } = await import("tesseract.js");
    const worker = await createWorker("eng", 1, {
      logger: () => null,
    });
    const { data } = await worker.recognize(imageBase64);
    await worker.terminate();

    const text = data.text.trim();
    if (!text) return { success: false, error: "No text found in image." };

    return {
      success: true,
      data: {
        raw_text: text,
        _source: "tesseract_fallback",
        _fallback: true,
      },
    };
  } catch (err) {
    return {
      success: false,
      error: `Local OCR failed: ${err instanceof Error ? err.message : String(err)}`,
    };
  }
}
