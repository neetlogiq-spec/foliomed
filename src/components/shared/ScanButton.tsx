"use client";

import { useState, useRef, useCallback, useEffect, useMemo } from "react";
import { createPortal } from "react-dom";
import { Button } from "@/components/ui/button";
import {
  type ExtractionContext,
  type ExtractResult,
  extractCaseDataBatch,
} from "@/app/(app)/ocr-actions";
import { compressImage } from "@/lib/ocr/compress";
import { ocrWithTesseract } from "@/lib/ocr/tesseract-fallback";
import { cn } from "@/lib/utils";

interface ScanButtonProps {
  context: ExtractionContext;
  onExtract: (data: Record<string, unknown>) => void;
  className?: string;
  label?: string;
}

type ScanMode = "camera" | "upload";

interface ImageSlot {
  preview: string;
  status: "processing" | "done" | "error";
  result: ExtractResult | null;
}

/* ── Context-aware preview components ─────────────────────────── */

function LabReportPreview({ data }: { data: Record<string, unknown> }) {
  const tests = Array.isArray(data.tests)
    ? (data.tests as Array<Record<string, unknown>>)
    : [];
  const flagColor = (flag: unknown) => {
    if (flag === "high" || flag === "low") return "text-red-400 font-medium";
    if (flag === "normal") return "text-emerald-400";
    return "text-slate-400";
  };

  return (
    <div className="space-y-3">
      {/* Header meta */}
      <div className="grid grid-cols-2 gap-x-4 gap-y-1">
        {(["patient_name", "report_date", "lab_name"] as const).map((k) =>
          data[k] ? (
            <div key={k}>
              <span className="text-[10px] text-slate-500 capitalize block">{k.replace(/_/g, " ")}</span>
              <span className="text-xs text-white">{String(data[k])}</span>
            </div>
          ) : null
        )}
      </div>

      {/* Tests table */}
      {tests.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-white/10">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-2.5 py-2 text-slate-400 font-medium">Test</th>
                <th className="text-right px-2.5 py-2 text-slate-400 font-medium">Value</th>
                <th className="text-right px-2.5 py-2 text-slate-400 font-medium">Unit</th>
                <th className="text-right px-2.5 py-2 text-slate-400 font-medium">Reference</th>
                <th className="text-right px-2.5 py-2 text-slate-400 font-medium">Flag</th>
              </tr>
            </thead>
            <tbody>
              {tests.map((t, i) => (
                <tr key={i} className="border-b border-white/5 last:border-0">
                  <td className="px-2.5 py-2 text-white">{String(t.name ?? "")}</td>
                  <td className={cn("px-2.5 py-2 text-right", flagColor(t.flag))}>{String(t.value ?? "")}</td>
                  <td className="px-2.5 py-2 text-right text-slate-400">{String(t.unit ?? "")}</td>
                  <td className="px-2.5 py-2 text-right text-slate-500">{String(t.reference ?? "")}</td>
                  <td className={cn("px-2.5 py-2 text-right capitalize", flagColor(t.flag))}>
                    {t.flag ? String(t.flag) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function PatientAdmissionPreview({ data }: { data: Record<string, unknown> }) {
  const FIELDS: [string, string][] = [
    ["ip_number", "IP No."],
    ["first_name", "First Name"],
    ["last_name", "Last Name"],
    ["date_of_birth", "DOB"],
    ["age_years", "Age (yrs)"],
    ["gender", "Gender"],
    ["weight_kg", "Weight (kg)"],
    ["height_cm", "Height (cm)"],
    ["blood_group", "Blood Group"],
    ["guardian_name", "Guardian"],
    ["guardian_relation", "Relation"],
    ["phone", "Phone"],
    ["address", "Address"],
    ["diagnosis", "Diagnosis"],
  ];

  const confidence = data.confidence as Record<string, string> | undefined;
  const confColor = (k: string) => {
    const c = confidence?.[k];
    return c === "high" ? "text-emerald-400" : c === "medium" ? "text-amber-400" : c === "low" ? "text-red-400" : "";
  };

  return (
    <div className="grid grid-cols-2 gap-x-4 gap-y-2.5">
      {FIELDS.map(([key, label]) => {
        const val = data[key];
        if (!val && val !== 0) return null;
        return (
          <div key={key} className={key === "address" || key === "diagnosis" ? "col-span-2" : ""}>
            <span className="text-[10px] text-slate-500 block">{label}</span>
            <span className={cn("text-xs text-white", confColor(key))}>{String(val)}</span>
          </div>
        );
      })}
    </div>
  );
}

function ProgressNotePreview({ data }: { data: Record<string, unknown> }) {
  const sections: [string, string, string][] = [
    ["subjective", "S — Subjective", "text-blue-400"],
    ["objective", "O — Objective", "text-teal-400"],
    ["assessment", "A — Assessment", "text-amber-400"],
    ["plan", "P — Plan", "text-emerald-400"],
  ];

  const vitals = data.vitals as Record<string, unknown> | undefined;

  return (
    <div className="space-y-3">
      {!!data.date && (
        <p className="text-[10px] text-slate-500">Date: <span className="text-white">{String(data.date)}</span></p>
      )}

      {/* Vitals row */}
      {vitals && Object.keys(vitals).length > 0 && (
        <div className="bg-white/5 rounded-lg p-2.5">
          <p className="text-[10px] text-slate-500 mb-1.5 uppercase tracking-wider">Vitals</p>
          <div className="flex flex-wrap gap-x-4 gap-y-1">
            {Object.entries(vitals).map(([k, v]) =>
              v ? (
                <span key={k} className="text-xs">
                  <span className="text-slate-500 capitalize">{k.replace(/_/g, " ")}: </span>
                  <span className="text-white font-medium">{String(v)}</span>
                </span>
              ) : null
            )}
          </div>
        </div>
      )}

      {/* SOAP sections */}
      {sections.map(([key, label, color]) =>
        !!data[key] ? (
          <div key={key}>
            <p className={cn("text-[10px] font-semibold uppercase tracking-wider mb-1", color)}>{label}</p>
            <p className="text-xs text-slate-200 whitespace-pre-wrap leading-relaxed">{String(data[key])}</p>
          </div>
        ) : null
      )}

      {/* Fluid balance */}
      {(!!data.fluid_input_ml || !!data.fluid_output_ml) && (
        <div className="flex gap-4">
          {!!data.fluid_input_ml && (
            <span className="text-xs"><span className="text-slate-500">Input: </span><span className="text-white">{String(data.fluid_input_ml)} mL</span></span>
          )}
          {!!data.fluid_output_ml && (
            <span className="text-xs"><span className="text-slate-500">Output: </span><span className="text-white">{String(data.fluid_output_ml)} mL</span></span>
          )}
        </div>
      )}
    </div>
  );
}

function CaseDocumentPreview({ data }: { data: Record<string, unknown> }) {
  const sections = Array.isArray(data.sections)
    ? (data.sections as Array<{ title?: string; content?: string; type?: string }>)
    : [];

  const sectionColor = (type: string | undefined) => {
    if (type === "findings") return "border-blue-500/30 bg-blue-500/5";
    if (type === "plan") return "border-emerald-500/30 bg-emerald-500/5";
    return "border-white/10 bg-white/[0.02]";
  };

  return (
    <div className="space-y-2.5">
      {!!data.title && (
        <p className="text-sm font-semibold text-white">{String(data.title)}</p>
      )}
      {sections.length > 0 ? (
        sections.map((s, i) => (
          <div key={i} className={cn("rounded-lg border p-2.5", sectionColor(s.type))}>
            {s.title && <p className="text-[10px] font-semibold text-slate-300 uppercase tracking-wider mb-1">{s.title}</p>}
            {s.content && <p className="text-xs text-slate-200 whitespace-pre-wrap leading-relaxed">{s.content}</p>}
          </div>
        ))
      ) : data.raw_text ? (
        <p className="text-xs text-slate-200 whitespace-pre-wrap leading-relaxed">{String(data.raw_text)}</p>
      ) : null}
    </div>
  );
}

function GenericPreview({ data }: { data: Record<string, unknown> }) {
  const SKIP = new Set(["confidence", "_source", "_fallback"]);
  const entries = Object.entries(data).filter(
    ([k, v]) => !SKIP.has(k) && v !== null && v !== undefined && v !== "" && typeof v !== "object"
  );

  return (
    <div className="divide-y divide-white/5">
      {entries.map(([key, value]) => (
        <div key={key} className="flex items-start justify-between gap-2 py-1.5">
          <span className="text-xs text-slate-400 capitalize">{key.replace(/_/g, " ")}</span>
          <span className="text-xs text-white text-right max-w-[60%] break-words">{String(value)}</span>
        </div>
      ))}
    </div>
  );
}

function ExtractedDataPreview({
  data,
  context,
  successCount,
}: {
  data: Record<string, unknown>;
  context: ExtractionContext;
  successCount: number;
}) {
  return (
    <div className="px-4 pb-4 mt-3">
      <p className="text-xs text-emerald-400 font-medium mb-3 flex items-center gap-1.5">
        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
        </svg>
        {successCount > 1 ? `Merged from ${successCount} captures` : "Data extracted"}
        {!!data._fallback && (
          <span className="text-[10px] text-amber-400 font-normal ml-1">(local OCR)</span>
        )}
      </p>

      {context === "lab_report" && <LabReportPreview data={data} />}
      {context === "patient_admission" && <PatientAdmissionPreview data={data} />}
      {context === "progress_note" && <ProgressNotePreview data={data} />}
      {context === "case_document" && <CaseDocumentPreview data={data} />}
      {!["lab_report", "patient_admission", "progress_note", "case_document"].includes(context) && (
        <GenericPreview data={data} />
      )}
    </div>
  );
}

/* ── Main component ────────────────────────────────────────────── */

export function ScanButton({
  context,
  onExtract,
  className,
  label = "📷 Scan Record",
}: ScanButtonProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [mode, setMode] = useState<ScanMode>("upload");
  const [slots, setSlots] = useState<ImageSlot[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);

  const [cameraStream, setCameraStream] = useState<MediaStream | null>(null);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [isCapturing, setIsCapturing] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Explicit portal container — append to body once on mount.
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

      let results: ExtractResult[] = await extractCaseDataBatch(base64List, context);

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
    [context]
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
  }, [stopCamera]);

  const switchMode = useCallback(
    (next: ScanMode) => {
      setMode(next);
      if (next === "camera") startCamera();
      else stopCamera();
    },
    [startCamera, stopCamera]
  );

  /* ─── Apply ──────────────────────────────── */
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

  const handleApply = useCallback(() => {
    if (mergedData) { onExtract(mergedData); handleClose(); }
  }, [mergedData, onExtract, handleClose]);

  const successCount = slots.filter((s) => s.status === "done").length;
  const errorCount = slots.filter((s) => s.status === "error").length;

  /* ─── Render ─────────────────────────────── */
  return (
    <>
      {/*
        Off-screen file input. NOT display:none — some WebViews block .click()
        on display:none inputs. position:fixed outside viewport works everywhere.
      */}
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
          <div className="bg-slate-900 border border-white/10 rounded-t-2xl sm:rounded-2xl w-full sm:max-w-lg max-h-[92vh] flex flex-col shadow-2xl overflow-hidden">

            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-white/10 shrink-0">
              <div className="flex items-center gap-3">
                <span className="text-sm font-semibold text-white">AI Scanner</span>
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

              {/* ── Thumbnails ── */}
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

              {/* ── Processing ── */}
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

              {/* ── Extracted data — context-aware structured preview ── */}
              {!isProcessing && successCount > 0 && mergedData && (
                <ExtractedDataPreview
                  data={mergedData}
                  context={context}
                  successCount={successCount}
                />
              )}
            </div>

            {/* Footer */}
            <div className="px-4 py-3 border-t border-white/10 flex gap-2 shrink-0">
              {slots.length > 0 && !isProcessing ? (
                <>
                  <button type="button" onClick={() => setSlots([])}
                    className="px-3 py-1.5 rounded-lg text-xs border border-white/10 text-slate-400 hover:bg-white/5">
                    Clear
                  </button>
                  {successCount > 0 && (
                    <button type="button" onClick={handleApply}
                      className="flex-1 py-1.5 rounded-lg text-xs font-medium bg-emerald-600 hover:bg-emerald-500 text-white">
                      ✓ Apply to form{successCount > 1 ? ` (${successCount} merged)` : ""}
                    </button>
                  )}
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
