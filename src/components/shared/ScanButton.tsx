"use client";

import { useState, useRef, useCallback, useEffect, useMemo } from "react";
import { createPortal } from "react-dom";
import { Button } from "@/components/ui/button";
import {
  type ExtractionContext,
  type ExtractResult,
  extractCaseDataBatch,
  detectAndExtract,
} from "@/app/(app)/ocr-actions";
import { compressImage } from "@/lib/ocr/compress";
import { ocrWithTesseract } from "@/lib/ocr/tesseract-fallback";
import { cn } from "@/lib/utils";
import { ImageViewer } from "@/components/ocr/ImageViewer";
import { EditableLabReport, type LabReportData } from "@/components/ocr/EditableLabReport";
import { EditablePatientAdmission, type PatientAdmissionData } from "@/components/ocr/EditablePatientAdmission";
import { EditableProgressNote, type ProgressNoteData } from "@/components/ocr/EditableProgressNote";
import { EditableCaseDocument, type CaseDocumentData } from "@/components/ocr/EditableCaseDocument";

interface ScanButtonProps {
  /** When omitted, Gemini auto-detects the document type before extracting. */
  context?: ExtractionContext;
  onExtract: (data: Record<string, unknown>) => void;
  /** Called with the detected context when auto-detect is used. */
  onContextDetected?: (context: ExtractionContext) => void;
  className?: string;
  label?: string;
}

type ScanMode = "camera" | "upload";

interface ImageSlot {
  preview: string;
  status: "processing" | "done" | "error";
  result: ExtractResult | null;
}

/* ── Generic fallback preview (raw key-value) ──────────────────── */
function GenericEditablePreview({
  data,
  onChange,
}: {
  data: Record<string, unknown>;
  onChange: (d: Record<string, unknown>) => void;
}) {
  const SKIP = new Set(["confidence", "_source", "_fallback"]);
  const entries = Object.entries(data).filter(
    ([k, v]) => !SKIP.has(k) && v !== null && v !== undefined && typeof v !== "object"
  );

  return (
    <div className="space-y-2">
      {entries.map(([key]) => (
        <div key={key} className="space-y-0.5">
          <label className="text-[10px] text-slate-400 uppercase tracking-wide">
            {key.replace(/_/g, " ")}
          </label>
          <input
            value={data[key] != null ? String(data[key]) : ""}
            onChange={(e) => onChange({ ...data, [key]: e.target.value })}
            className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1 text-xs text-white"
          />
        </div>
      ))}
    </div>
  );
}

/* ── Main component ────────────────────────────────────────────── */

export function ScanButton({
  context: contextProp,
  onExtract,
  onContextDetected,
  className,
  label = "📷 Scan Record",
}: ScanButtonProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [mode, setMode] = useState<ScanMode>("upload");
  const [slots, setSlots] = useState<ImageSlot[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [editableData, setEditableData] = useState<Record<string, unknown> | null>(null);
  // Resolved context: from prop or auto-detected
  const [resolvedContext, setResolvedContext] = useState<ExtractionContext | null>(contextProp ?? null);

  const [cameraStream, setCameraStream] = useState<MediaStream | null>(null);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [isCapturing, setIsCapturing] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Portal container
  const portalContainerRef = useRef<HTMLDivElement | null>(null);
  const [portalReady, setPortalReady] = useState(false);
  useEffect(() => {
    const el = document.createElement("div");
    el.setAttribute("data-scan-portal", "true");
    document.body.appendChild(el);
    portalContainerRef.current = el;
    setPortalReady(true);
    return () => { document.body.removeChild(el); };
  }, []);

  /* ─── Camera ─────────────────────────────── */
  const startCamera = useCallback(async () => {
    setCameraError(null);
    if (!navigator.mediaDevices?.getUserMedia) {
      setCameraError("Camera not supported on this device.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment", width: { ideal: 1920 }, height: { ideal: 1080 } },
      });
      setCameraStream(stream);
      setTimeout(() => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play().catch(() => null);
        }
      }, 50);
    } catch (err) {
      setCameraError(
        err instanceof DOMException && err.name === "NotAllowedError"
          ? "Camera permission denied."
          : "Camera unavailable on this device."
      );
    }
  }, []);

  const stopCamera = useCallback(() => {
    cameraStream?.getTracks().forEach((t) => t.stop());
    setCameraStream(null);
  }, [cameraStream]);

  /* ─── Process images ─────────────────────── */
  const processBase64List = useCallback(
    async (rawBase64List: string[]) => {
      if (!rawBase64List.length) return;
      setIsProcessing(true);

      const base64List = await Promise.all(
        rawBase64List.map((b) => compressImage(b).catch(() => b))
      );

      const incoming: ImageSlot[] = base64List.map((preview) => ({
        preview,
        status: "processing" as const,
        result: null,
      }));

      let startIndex = 0;
      setSlots((prev) => {
        startIndex = prev.length;
        return [...prev, ...incoming];
      });

      let results: ExtractResult[];
      let activeContext: ExtractionContext;

      if (contextProp) {
        // Context explicitly provided — extract directly
        activeContext = contextProp;
        results = await extractCaseDataBatch(base64List, contextProp);
      } else {
        // Auto-detect using the first image, then extract all with detected context
        const { context: detected, result: firstResult } = await detectAndExtract(base64List[0]);
        activeContext = detected;
        setResolvedContext(detected);
        onContextDetected?.(detected);
        const remainingResults =
          base64List.length > 1
            ? await extractCaseDataBatch(base64List.slice(1), detected)
            : [];
        results = [firstResult, ...remainingResults];
      }

      // Keep activeContext in scope for linter — it's used to set resolvedContext above
      void activeContext;

      // Tesseract fallback for any Gemini failures
      results = await Promise.all(
        results.map(async (r, i) => {
          if (!r.error) return r;
          console.warn(`[OCR] Gemini failed (image ${startIndex + i + 1}), trying Tesseract…`);
          const fallback = await ocrWithTesseract(base64List[i]);
          return fallback.success
            ? { ...fallback, data: { ...fallback.data, _fallback: true } }
            : r;
        })
      );

      setSlots((prev) => {
        const next = [...prev];
        results.forEach((r, i) => {
          const idx = startIndex + i;
          if (next[idx]) next[idx] = { ...next[idx], status: r.error ? "error" : "done", result: r };
        });
        return next;
      });
      setIsProcessing(false);
    },
    [contextProp, onContextDetected]
  );

  /* ─── Camera capture ─────────────────────── */
  const captureFrame = useCallback(async () => {
    if (!videoRef.current || isCapturing) return;
    setIsCapturing(true);
    const video = videoRef.current;
    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    canvas.getContext("2d")!.drawImage(video, 0, 0);
    await processBase64List([canvas.toDataURL("image/jpeg", 0.88)]);
    setIsCapturing(false);
  }, [isCapturing, processBase64List]);

  /* ─── File reading ───────────────────────── */
  const readFiles = useCallback(
    async (files: File[]) => {
      const valid = files.filter(
        (f) => f.type.startsWith("image/") && f.size <= 10 * 1024 * 1024
      );
      if (!valid.length) return;
      const base64List = await Promise.all(
        valid.map(
          (f) =>
            new Promise<string>((res) => {
              const reader = new FileReader();
              reader.onload = () => res(reader.result as string);
              reader.readAsDataURL(f);
            })
        )
      );
      await processBase64List(base64List);
    },
    [processBase64List]
  );

  const handleFileInput = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = Array.from(e.target.files ?? []);
      e.target.value = "";
      readFiles(files);
    },
    [readFiles]
  );

  /* ─── Clipboard paste ────────────────────── */
  useEffect(() => {
    if (!isOpen) return;
    const onPaste = (e: ClipboardEvent) => {
      const files = Array.from(e.clipboardData?.items ?? [])
        .filter((i) => i.type.startsWith("image/"))
        .map((i) => i.getAsFile())
        .filter((f): f is File => f !== null);
      if (files.length) readFiles(files);
    };
    document.addEventListener("paste", onPaste);
    return () => document.removeEventListener("paste", onPaste);
  }, [isOpen, readFiles]);

  /* ─── Open / close ───────────────────────── */
  const handleOpen = () => { setIsOpen(true); };

  const handleClose = useCallback(() => {
    stopCamera();
    setIsOpen(false);
    setSlots([]);
    setIsProcessing(false);
    setCameraError(null);
    setMode("upload");
    setEditableData(null);
    // Reset auto-detected context; keep prop-provided context
    setResolvedContext(contextProp ?? null);
  }, [stopCamera, contextProp]);

  const switchMode = useCallback(
    (next: ScanMode) => {
      setMode(next);
      if (next === "camera") startCamera();
      else stopCamera();
    },
    [startCamera, stopCamera]
  );

  /* ─── Merge extracted results ────────────── */
  const mergedData = useMemo((): Record<string, unknown> | null => {
    const successful = slots
      .filter((s) => s.status === "done" && s.result?.data)
      .map((s) => s.result!.data!);
    if (!successful.length) return null;
    return successful.reduce<Record<string, unknown>>((acc, curr) => {
      for (const [k, v] of Object.entries(curr)) {
        if (!(k in acc) && v !== null && v !== undefined && v !== "") acc[k] = v;
      }
      return acc;
    }, {});
  }, [slots]);

  // Initialise editable state when extraction completes
  useEffect(() => {
    if (mergedData && !isProcessing) {
      setEditableData((prev) => prev ?? mergedData);
    }
  }, [mergedData, isProcessing]);

  /* ─── Apply ──────────────────────────────── */
  const handleApply = useCallback(() => {
    if (editableData) { onExtract(editableData); handleClose(); }
  }, [editableData, onExtract, handleClose]);

  const successCount = slots.filter((s) => s.status === "done").length;
  const errorCount = slots.filter((s) => s.status === "error").length;
  const hasExtractedData = !isProcessing && successCount > 0 && editableData && resolvedContext;
  // The effective context for rendering editable components
  const activeContext = resolvedContext ?? contextProp;

  // All scanned image previews for ImageViewer
  const imageUrls = slots.map((s) => s.preview);

  /* ─── Render ─────────────────────────────── */
  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        onChange={handleFileInput}
        style={{ position: "fixed", top: "-200px", left: "-200px", opacity: 0, pointerEvents: "none" }}
        tabIndex={-1}
        aria-hidden="true"
      />

      <Button
        type="button"
        onClick={handleOpen}
        className={cn(
          "bg-gradient-to-r from-violet-600 to-blue-600 hover:from-violet-500 hover:to-blue-500 text-white text-xs font-medium shadow-lg shadow-violet-500/20 active:scale-95 transition-all",
          className
        )}
        size="sm"
      >
        {label}
      </Button>

      {isOpen && portalReady && portalContainerRef.current && createPortal(
        <div className="fixed inset-0 z-[200] flex items-end sm:items-center justify-center bg-black/90 backdrop-blur-sm">
          {/* Modal — widens to 5xl when data is extracted for side-by-side */}
          <div className={cn(
            "bg-slate-900 border border-white/10 rounded-t-2xl sm:rounded-2xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden transition-all duration-300",
            hasExtractedData ? "sm:max-w-5xl" : "sm:max-w-lg"
          )}>

            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-white/10 shrink-0">
              <div className="flex items-center gap-3">
                <span className="text-sm font-semibold text-white">AI Scanner</span>
                {!hasExtractedData && (
                  <div className="flex bg-white/5 rounded-lg p-0.5">
                    {(["upload", "camera"] as ScanMode[]).map((m) => (
                      <button
                        key={m}
                        type="button"
                        onClick={() => switchMode(m)}
                        className={cn(
                          "px-2.5 py-1 rounded-md text-xs font-medium transition-colors",
                          mode === m ? "bg-violet-600 text-white" : "text-slate-400"
                        )}
                      >
                        {m === "upload" ? "🖼 Upload" : "📷 Camera"}
                      </button>
                    ))}
                  </div>
                )}
                {hasExtractedData && (
                  <span className="text-xs text-emerald-400 flex items-center gap-1 flex-wrap">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                    </svg>
                    {successCount > 1 ? `Merged from ${successCount} captures` : "Extracted — edit before applying"}
                    {!contextProp && resolvedContext && (
                      <span className="text-violet-400 font-normal ml-1">
                        · detected: {resolvedContext.replace(/_/g, " ")}
                      </span>
                    )}
                    {!!editableData._fallback && (
                      <span className="text-amber-400 font-normal ml-1">(local OCR)</span>
                    )}
                  </span>
                )}
              </div>
              <button
                type="button"
                onClick={handleClose}
                className="p-1.5 rounded-lg text-slate-400 hover:bg-white/10"
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto min-h-0">

              {/* ── Side-by-side: image viewer + editable fields ── */}
              {hasExtractedData ? (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-0 h-full">

                  {/* Left pane — scanned image(s) */}
                  <div className="p-4 border-b lg:border-b-0 lg:border-r border-white/10 flex flex-col gap-3">
                    <p className="text-[10px] text-slate-500 uppercase tracking-wider shrink-0">
                      Source image
                    </p>
                    <ImageViewer
                      images={imageUrls}
                      className="flex-1 min-h-[220px] lg:min-h-[420px]"
                    />
                    {/* Re-scan link */}
                    <button
                      type="button"
                      onClick={() => { setSlots([]); setEditableData(null); }}
                      className="text-[10px] text-violet-400 hover:text-violet-300 text-left shrink-0"
                    >
                      ↩ Re-scan
                    </button>
                  </div>

                  {/* Right pane — editable extracted fields */}
                  <div className="p-4 overflow-y-auto">
                    <p className="text-[10px] text-slate-500 uppercase tracking-wider mb-3">
                      Extracted data — correct any errors below
                    </p>

                    {activeContext === "lab_report" && (
                      <EditableLabReport
                        data={editableData as LabReportData}
                        onChange={setEditableData}
                      />
                    )}
                    {activeContext === "patient_admission" && (
                      <EditablePatientAdmission
                        data={editableData as PatientAdmissionData}
                        onChange={setEditableData}
                      />
                    )}
                    {activeContext === "progress_note" && (
                      <EditableProgressNote
                        data={editableData as ProgressNoteData}
                        onChange={setEditableData}
                      />
                    )}
                    {activeContext === "case_document" && (
                      <EditableCaseDocument
                        data={editableData as CaseDocumentData}
                        onChange={setEditableData}
                      />
                    )}
                    {(!activeContext || !["lab_report", "patient_admission", "progress_note", "case_document"].includes(activeContext)) && (
                      <GenericEditablePreview data={editableData} onChange={setEditableData} />
                    )}
                  </div>
                </div>
              ) : (
                <>
                  {/* ── Upload ── */}
                  {mode === "upload" && slots.length === 0 && (
                    <div className="p-4">
                      <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        className="w-full flex flex-col items-center gap-3 rounded-xl border-2 border-dashed border-white/10 p-10 hover:border-white/25 hover:bg-white/[0.02] active:border-violet-400/50 transition-colors cursor-pointer"
                      >
                        <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center">
                          <svg className="w-5 h-5 text-slate-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5" />
                          </svg>
                        </div>
                        <div className="text-center">
                          <p className="text-sm font-medium text-slate-200">Tap to choose images</p>
                          <p className="text-xs text-slate-500 mt-0.5">Multiple images · max 10 MB each</p>
                          <p className="text-[10px] text-slate-600 mt-2">or paste from clipboard (⌘V)</p>
                        </div>
                      </button>
                    </div>
                  )}

                  {/* ── Camera ── */}
                  {mode === "camera" && (
                    <div className="relative bg-black">
                      {cameraError ? (
                        <div className="flex flex-col items-center justify-center h-52 gap-3 px-6 text-center">
                          <svg className="w-8 h-8 text-slate-500" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z" />
                            <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0ZM18.75 10.5h.008v.008h-.008V10.5Z" />
                          </svg>
                          <p className="text-sm text-slate-400">{cameraError}</p>
                          <button type="button" onClick={() => switchMode("upload")}
                            className="px-3 py-1.5 rounded-lg text-xs border border-white/10 text-slate-300 hover:bg-white/5">
                            Use file upload instead
                          </button>
                        </div>
                      ) : !cameraStream ? (
                        <div className="flex flex-col items-center justify-center h-52 gap-3">
                          <div className="w-6 h-6 border-2 border-violet-500/30 border-t-violet-500 rounded-full animate-spin" />
                          <p className="text-xs text-slate-500">Starting camera…</p>
                        </div>
                      ) : (
                        <>
                          <video ref={videoRef} autoPlay playsInline muted className="w-full max-h-64 object-cover" />
                          <div className="absolute inset-0 pointer-events-none">
                            {["top-4 left-4 border-t-2 border-l-2 rounded-tl-lg",
                              "top-4 right-4 border-t-2 border-r-2 rounded-tr-lg",
                              "bottom-14 left-4 border-b-2 border-l-2 rounded-bl-lg",
                              "bottom-14 right-4 border-b-2 border-r-2 rounded-br-lg",
                            ].map((cls, i) => (
                              <div key={i} className={cn("absolute w-6 h-6 border-violet-400/70", cls)} />
                            ))}
                          </div>
                          <div className="absolute bottom-3 inset-x-0 flex justify-center">
                            <button
                              type="button"
                              onClick={captureFrame}
                              disabled={isCapturing || isProcessing}
                              className={cn(
                                "w-14 h-14 rounded-full border-4 border-white flex items-center justify-center transition-all active:scale-90",
                                isCapturing ? "bg-violet-500/60" : "bg-white/20"
                              )}
                            >
                              {isCapturing
                                ? <div className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                                : <div className="w-9 h-9 rounded-full bg-white" />}
                            </button>
                          </div>
                        </>
                      )}
                    </div>
                  )}

                  {/* ── Thumbnails + processing status ── */}
                  {slots.length > 0 && (
                    <div className="px-4 pt-3">
                      <div className="flex items-center justify-between mb-2">
                        <p className="text-[10px] text-slate-500 uppercase tracking-wider">
                          Captured ({slots.length})
                        </p>
                        {mode === "upload" && !isProcessing && (
                          <button
                            type="button"
                            onClick={() => fileInputRef.current?.click()}
                            className="text-[10px] text-violet-400 hover:text-violet-300"
                          >
                            + Add more
                          </button>
                        )}
                      </div>
                      <div className="flex gap-2 overflow-x-auto pb-1">
                        {slots.map((slot, i) => (
                          <div key={i} className="relative flex-shrink-0">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img
                              src={slot.preview}
                              alt={`Image ${i + 1}`}
                              className={cn(
                                "w-16 h-16 object-cover rounded-lg border",
                                slot.status === "processing" && "border-violet-500/40 opacity-60",
                                slot.status === "done" && "border-emerald-500/40",
                                slot.status === "error" && "border-red-500/40"
                              )}
                            />
                            <div className="absolute bottom-0.5 right-0.5">
                              {slot.status === "processing" && (
                                <div className="w-3.5 h-3.5 border border-violet-400/40 border-t-violet-400 rounded-full animate-spin bg-black/70" />
                              )}
                              {slot.status === "done" && (
                                <div className="w-3.5 h-3.5 rounded-full bg-emerald-500 flex items-center justify-center">
                                  <svg className="w-2 h-2 text-white" fill="none" viewBox="0 0 24 24" strokeWidth={3} stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                                  </svg>
                                </div>
                              )}
                              {slot.status === "error" && (
                                <div className="w-3.5 h-3.5 rounded-full bg-red-500 flex items-center justify-center">
                                  <svg className="w-2 h-2 text-white" fill="none" viewBox="0 0 24 24" strokeWidth={3} stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
                                  </svg>
                                </div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* ── Processing spinner ── */}
                  {isProcessing && (
                    <div className="flex items-center gap-2 px-4 py-3">
                      <div className="w-4 h-4 border-2 border-violet-500/30 border-t-violet-500 rounded-full animate-spin shrink-0" />
                      <p className="text-xs text-slate-400">
                        Extracting… {slots.filter((s) => s.status === "processing").length} remaining
                      </p>
                    </div>
                  )}

                  {/* ── Errors ── */}
                  {!isProcessing && errorCount > 0 && (
                    <div className="mx-4 mt-2 p-2.5 rounded-lg bg-red-500/10 border border-red-500/20">
                      {slots.filter((s) => s.status === "error").map((s, i) => (
                        <p key={i} className="text-xs text-red-400">
                          Image {slots.indexOf(s) + 1}: {s.result?.error}
                        </p>
                      ))}
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Footer */}
            <div className="px-4 py-3 border-t border-white/10 flex gap-2 shrink-0">
              {hasExtractedData ? (
                <>
                  <button type="button" onClick={() => { setSlots([]); setEditableData(null); }}
                    className="px-3 py-1.5 rounded-lg text-xs border border-white/10 text-slate-400 hover:bg-white/5">
                    Re-scan
                  </button>
                  <button type="button" onClick={handleApply}
                    className="flex-1 py-1.5 rounded-lg text-xs font-medium bg-emerald-600 hover:bg-emerald-500 text-white">
                    ✓ Apply to form{successCount > 1 ? ` (${successCount} merged)` : ""}
                  </button>
                </>
              ) : slots.length > 0 && !isProcessing ? (
                <>
                  <button type="button" onClick={() => setSlots([])}
                    className="px-3 py-1.5 rounded-lg text-xs border border-white/10 text-slate-400 hover:bg-white/5">
                    Clear
                  </button>
                </>
              ) : (
                <button type="button" onClick={handleClose}
                  className="flex-1 py-1.5 rounded-lg text-xs border border-white/10 text-slate-300 hover:bg-white/5">
                  {isProcessing ? "Processing…" : "Cancel"}
                </button>
              )}
            </div>
          </div>
        </div>,
        portalContainerRef.current
      )}
    </>
  );
}
