"use client";

import { useState, useRef, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { extractCaseData } from "@/app/(app)/ocr-actions";
import { cn } from "@/lib/utils";

type ExtractionContext = "patient_admission" | "lab_report" | "progress_note";

interface ScanButtonProps {
  context: ExtractionContext;
  onExtract: (data: Record<string, unknown>) => void;
  className?: string;
  label?: string;
}

export function ScanButton({ context, onExtract, className, label = "📷 Scan Record" }: ScanButtonProps) {
  const [isExtracting, setIsExtracting] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [extractedData, setExtractedData] = useState<Record<string, unknown> | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file
    if (!file.type.startsWith("image/")) {
      setError("Please select an image file.");
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setError("Image must be under 10MB.");
      return;
    }

    setError(null);
    setExtractedData(null);
    setIsExtracting(true);

    // Read and compress image
    const reader = new FileReader();
    reader.onload = async () => {
      const base64 = reader.result as string;
      setPreview(base64);

      try {
        const result = await extractCaseData(base64, context);
        if (result.error) {
          setError(result.error);
        } else if (result.data) {
          setExtractedData(result.data);
        }
      } catch {
        setError("Extraction failed. Please try again.");
      } finally {
        setIsExtracting(false);
      }
    };
    reader.readAsDataURL(file);

    // Reset input so same file can be re-selected
    e.target.value = "";
  }, [context]);

  const handleApply = useCallback(() => {
    if (extractedData) {
      onExtract(extractedData);
      setPreview(null);
      setExtractedData(null);
      setError(null);
    }
  }, [extractedData, onExtract]);

  const handleClose = useCallback(() => {
    setPreview(null);
    setExtractedData(null);
    setError(null);
    setIsExtracting(false);
  }, []);

  const getConfidenceColor = (confidence: string) => {
    switch (confidence) {
      case "high": return "text-emerald-400";
      case "medium": return "text-amber-400";
      case "low": return "text-red-400";
      default: return "text-slate-400";
    }
  };

  const renderFieldValue = (key: string, value: unknown, confidence?: Record<string, string>) => {
    if (value === null || value === undefined || value === "") return null;
    if (key === "confidence" || key === "vitals") return null;
    if (typeof value === "object" && !Array.isArray(value)) return null;

    const conf = confidence?.[key];
    const displayVal = Array.isArray(value)
      ? (value as Array<Record<string, unknown>>).map((v, i) => (
          <div key={i} className="text-xs text-slate-300 bg-white/5 rounded px-2 py-1 mt-1">
            {Object.entries(v).filter(([k]) => k !== "confidence").map(([k, vv]) => (
              <span key={k} className="mr-2">{k}: <strong>{String(vv)}</strong></span>
            ))}
          </div>
        ))
      : String(value);

    return (
      <div key={key} className="flex items-start justify-between gap-2 py-1.5 border-b border-white/5 last:border-0">
        <span className="text-xs text-slate-400 capitalize min-w-0">
          {key.replace(/_/g, " ")}
        </span>
        <div className="text-right">
          {typeof displayVal === "string" ? (
            <span className={cn("text-xs font-medium", conf ? getConfidenceColor(conf) : "text-white")}>
              {displayVal}
            </span>
          ) : displayVal}
          {conf && (
            <span className={cn("text-[10px] ml-1", getConfidenceColor(conf))}>
              ({conf})
            </span>
          )}
        </div>
      </div>
    );
  };

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        onChange={handleFileSelect}
        className="hidden"
      />

      <Button
        type="button"
        onClick={() => fileInputRef.current?.click()}
        disabled={isExtracting}
        className={cn(
          "bg-gradient-to-r from-violet-600 to-blue-600 hover:from-violet-500 hover:to-blue-500 text-white text-xs font-medium shadow-lg shadow-violet-500/20 active:scale-95 transition-all",
          className
        )}
        size="sm"
      >
        {isExtracting ? (
          <>
            <svg className="w-4 h-4 mr-1.5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Extracting...
          </>
        ) : label}
      </Button>

      {/* Review Modal */}
      {(preview || isExtracting) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-white/10 rounded-xl w-full max-w-lg max-h-[85vh] overflow-hidden flex flex-col shadow-2xl">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
              <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                <svg className="w-4 h-4 text-violet-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 3.75H6A2.25 2.25 0 0 0 3.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0 1 20.25 6v1.5M20.25 16.5V18A2.25 2.25 0 0 1 18 20.25h-1.5M3.75 16.5V18A2.25 2.25 0 0 0 6 20.25h1.5" />
                </svg>
                Scan Results
              </h3>
              <button onClick={handleClose} className="p-1 rounded hover:bg-white/10 text-slate-400">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto">
              {/* Preview */}
              {preview && (
                <div className="p-3 bg-black/30">
                  <img
                    src={preview}
                    alt="Scanned document"
                    className="w-full max-h-48 object-contain rounded-lg"
                  />
                </div>
              )}

              {/* Loading */}
              {isExtracting && (
                <div className="flex flex-col items-center justify-center py-12 gap-3">
                  <div className="w-10 h-10 border-2 border-violet-500/30 border-t-violet-500 rounded-full animate-spin" />
                  <p className="text-sm text-slate-400">Extracting data with AI...</p>
                  <p className="text-xs text-slate-500">This takes 2-3 seconds</p>
                </div>
              )}

              {/* Error */}
              {error && (
                <div className="mx-4 mt-3 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
                  <p className="text-xs text-red-400">{error}</p>
                </div>
              )}

              {/* Extracted Data */}
              {extractedData && !isExtracting && (
                <div className="p-4">
                  <p className="text-xs text-emerald-400 font-medium mb-3 flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                    </svg>
                    Data extracted successfully
                  </p>
                  <div className="divide-y divide-white/5">
                    {Object.entries(extractedData).map(([key, value]) => {
                      const confidence = extractedData.confidence as Record<string, string> | undefined;
                      return renderFieldValue(key, value, confidence);
                    })}
                  </div>
                </div>
              )}
            </div>

            {/* Actions */}
            {extractedData && !isExtracting && (
              <div className="px-4 py-3 border-t border-white/10 flex gap-2">
                <Button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  variant="outline"
                  size="sm"
                  className="flex-1 text-xs border-white/10 text-slate-300"
                >
                  Re-scan
                </Button>
                <Button
                  type="button"
                  onClick={handleApply}
                  size="sm"
                  className="flex-1 text-xs bg-emerald-600 hover:bg-emerald-500 text-white"
                >
                  ✓ Apply to Form
                </Button>
              </div>
            )}

            {error && !isExtracting && (
              <div className="px-4 py-3 border-t border-white/10 flex gap-2">
                <Button
                  type="button"
                  onClick={handleClose}
                  variant="outline"
                  size="sm"
                  className="flex-1 text-xs border-white/10 text-slate-300"
                >
                  Cancel
                </Button>
                <Button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  size="sm"
                  className="flex-1 text-xs bg-violet-600 hover:bg-violet-500 text-white"
                >
                  Try Again
                </Button>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
