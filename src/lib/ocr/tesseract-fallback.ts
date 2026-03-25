/**
 * Client-side OCR fallback using Tesseract.js.
 * Returns raw extracted text grouped into a simple structure
 * that ScanButton can display and apply.
 */
export async function ocrWithTesseract(imageBase64: string): Promise<{
  success: boolean;
  data?: Record<string, unknown>;
  error?: string;
}> {
  try {
    // Dynamic import — keeps the bundle lean (Tesseract is ~4 MB)
    const { createWorker } = await import("tesseract.js");
    const worker = await createWorker("eng", 1, {
      logger: () => null, // suppress progress logs
    });
    const { data } = await worker.recognize(imageBase64);
    await worker.terminate();

    const text = data.text.trim();
    if (!text) return { success: false, error: "No text found in image." };

    // Split into labelled lines / paragraphs so the result
    // matches the same shape ScanButton already knows how to render.
    const lines = text
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean);

    return {
      success: true,
      data: {
        raw_text: lines.join("\n"),
        // surface top lines as quick-preview fields
        ...Object.fromEntries(
          lines
            .slice(0, 6)
            .map((line, i) => [`line_${i + 1}`, line])
        ),
        _source: "tesseract_fallback",
      },
    };
  } catch (err) {
    return { success: false, error: `Local OCR failed: ${err instanceof Error ? err.message : String(err)}` };
  }
}
