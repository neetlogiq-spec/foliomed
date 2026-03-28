"use client";

import { useState, useTransition, useRef, useEffect, useCallback } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { uploadPatientImage, getImageUrl, getImageUrls, deletePatientImage } from "./image-actions";
import { cn } from "@/lib/utils";
import Tesseract from "tesseract.js";

const IMAGE_CATEGORIES = [
  { value: "xray", label: "X-Ray" },
  { value: "ct_scan", label: "CT Scan" },
  { value: "mri", label: "MRI" },
  { value: "ultrasound", label: "Ultrasound" },
  { value: "lab_report", label: "Lab Report" },
  { value: "clinical_photo", label: "Clinical Photo" },
  { value: "other", label: "Other" },
];

interface PatientImage {
  id: string;
  file_path: string;
  file_name: string;
  file_size: number | null;
  mime_type: string | null;
  caption: string | null;
  category: string | null;
  created_at: string;
}

interface ImagesPanelProps {
  patientId: string;
  images: PatientImage[];
}

function formatFileSize(bytes: number | null): string {
  if (!bytes) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

// Client-side image compression using Canvas API
const MAX_DIMENSION = 1920;
const QUALITY = 0.8;

async function compressImage(file: File): Promise<File> {
  // Skip non-image files (PDFs etc.)
  if (!file.type.startsWith("image/")) return file;

  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      let { width, height } = img;

      // Scale down if larger than MAX_DIMENSION
      if (width > MAX_DIMENSION || height > MAX_DIMENSION) {
        const ratio = Math.min(MAX_DIMENSION / width, MAX_DIMENSION / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          if (blob && blob.size < file.size) {
            // Use compressed version only if it's actually smaller
            const compressed = new File([blob], file.name, {
              type: "image/jpeg",
              lastModified: Date.now(),
            });
            resolve(compressed);
          } else {
            resolve(file); // Original is smaller, keep it
          }
        },
        "image/jpeg",
        QUALITY
      );
    };
    img.onerror = () => resolve(file); // Fallback to original on error
    img.src = URL.createObjectURL(file);
  });
}

export function ImagesPanel({ patientId, images }: ImagesPanelProps) {
  const [showForm, setShowForm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [compressionInfo, setCompressionInfo] = useState<string | null>(null);
  const [viewingImage, setViewingImage] = useState<string | null>(null);
  const [signedUrl, setSignedUrl] = useState<string | null>(null);
  const [thumbnails, setThumbnails] = useState<Record<string, string>>({});
  const fileRef = useRef<HTMLInputElement>(null);

  // OCR state
  const [ocrProgress, setOcrProgress] = useState<number | null>(null);
  const [ocrText, setOcrText] = useState<string | null>(null);
  const [ocrCopied, setOcrCopied] = useState(false);

  const handleOcr = useCallback(async (imageUrl: string) => {
    setOcrProgress(0);
    setOcrText(null);
    try {
      const result = await Tesseract.recognize(imageUrl, "eng", {
        logger: (m) => {
          if (m.status === "recognizing text" && typeof m.progress === "number") {
            setOcrProgress(Math.round(m.progress * 100));
          }
        },
      });
      setOcrText(result.data.text);
    } catch {
      setOcrText("[OCR failed — image may be unsupported]");
    } finally {
      setOcrProgress(null);
    }
  }, []);

  const copyOcrText = useCallback(() => {
    if (!ocrText) return;
    navigator.clipboard.writeText(ocrText);
    setOcrCopied(true);
    setTimeout(() => setOcrCopied(false), 2000);
  }, [ocrText]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    setCompressionInfo(null);
    if (file && file.type.startsWith("image/")) {
      const url = URL.createObjectURL(file);
      setPreview(url);
    } else {
      setPreview(null);
    }
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const form = e.currentTarget;
    const originalFile = (form.elements.namedItem("file") as HTMLInputElement)?.files?.[0];
    if (!originalFile) return;

    startTransition(async () => {
      // Compress on client before uploading
      const compressed = await compressImage(originalFile);
      const originalSize = formatFileSize(originalFile.size);
      const compressedSize = formatFileSize(compressed.size);

      if (compressed !== originalFile) {
        const savings = Math.round((1 - compressed.size / originalFile.size) * 100);
        setCompressionInfo(`Compressed: ${originalSize} → ${compressedSize} (${savings}% saved)`);
      }

      const fd = new FormData();
      fd.set("file", compressed);
      fd.set("caption", (form.elements.namedItem("caption") as HTMLInputElement)?.value || "");
      fd.set("category", (form.elements.namedItem("category") as HTMLSelectElement)?.value || "other");

      const result = await uploadPatientImage(patientId, fd);
      if (result?.error) setError(result.error);
      else {
        setShowForm(false);
        setPreview(null);
        setCompressionInfo(null);
        if (fileRef.current) fileRef.current.value = "";
      }
    });
  };

  const handleView = (filePath: string) => {
    setViewingImage(filePath);
    setSignedUrl(null);
    startTransition(async () => {
      const url = await getImageUrl(filePath);
      setSignedUrl(url);
    });
  };

  // Batch-load thumbnails for all images on mount / when images change
  useEffect(() => {
    const imagePaths = images
      .filter((img) => img.mime_type?.startsWith("image/"))
      .map((img) => img.file_path);
    if (!imagePaths.length) return;

    getImageUrls(imagePaths).then(setThumbnails);
  }, [images]);

  // Clean up object URLs
  useEffect(() => {
    return () => {
      if (preview) URL.revokeObjectURL(preview);
    };
  }, [preview]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">
          Images ({images.length})
        </h3>
        <Button
          size="sm"
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs"
        >
          {showForm ? "Cancel" : "+ Upload Image"}
        </Button>
      </div>

      {/* Upload form */}
      {showForm && (
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-white">Upload Image</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}

              <div className="space-y-1">
                <Label className="text-xs text-slate-400">File *</Label>
                <Input
                  ref={fileRef}
                  name="file"
                  type="file"
                  required
                  accept="image/*,application/pdf"
                  onChange={handleFileChange}
                  className="bg-white/5 border-white/10 text-white text-sm file:bg-blue-600 file:text-white file:border-0 file:rounded file:text-xs file:mr-2 file:px-2 file:py-1"
                />
              </div>

              {preview && (
                <div className="relative w-full max-w-[200px] rounded-lg overflow-hidden border border-white/10">
                  <img src={preview} alt="Preview" className="w-full h-auto" />
                </div>
              )}

              {compressionInfo && (
                <p className="text-[10px] text-emerald-400">✓ {compressionInfo}</p>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Category</Label>
                  <select
                    name="category"
                    className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1.5 text-sm text-white h-8"
                  >
                    {IMAGE_CATEGORIES.map((c) => (
                      <option key={c.value} value={c.value} className="bg-slate-900">
                        {c.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Caption</Label>
                  <Input
                    name="caption"
                    placeholder="e.g. Chest X-Ray AP view"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600"
                  />
                </div>
              </div>

              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Uploading..." : "Upload"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Image grid */}
      {images.length === 0 ? (
        <p className="text-sm text-slate-500 py-8 text-center">No images uploaded yet</p>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {images.map((img) => (
            <button
              key={img.id}
              onClick={() => handleView(img.file_path)}
              className="bg-white/5 border border-white/5 rounded-lg p-2 hover:border-blue-500/30 transition-colors text-left group relative"
            >
              <div className="w-full aspect-square bg-slate-800 rounded overflow-hidden mb-2 flex items-center justify-center">
                {img.mime_type?.startsWith("image/") && thumbnails[img.file_path] ? (
                  <img
                    src={thumbnails[img.file_path]}
                    alt={img.caption || img.file_name}
                    className="w-full h-full object-cover"
                  />
                ) : img.mime_type?.startsWith("image/") ? (
                  <div className="w-full h-full flex items-center justify-center">
                    <div className="w-5 h-5 border-2 border-slate-600 border-t-blue-400 rounded-full animate-spin" />
                  </div>
                ) : (
                  <svg className="w-8 h-8 text-slate-600 group-hover:text-blue-400 transition-colors" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
                  </svg>
                )}
              </div>
              <p className="text-xs text-white truncate">{img.caption || img.file_name}</p>
              <div className="flex items-center justify-between mt-0.5">
                <span className={cn(
                  "text-[10px] px-1 py-0.5 rounded capitalize",
                  img.category === "xray" ? "text-blue-400 bg-blue-500/10" :
                  img.category === "ct_scan" ? "text-purple-400 bg-purple-500/10" :
                  img.category === "mri" ? "text-teal-400 bg-teal-500/10" :
                  "text-slate-400 bg-white/5"
                )}>
                  {IMAGE_CATEGORIES.find((c) => c.value === img.category)?.label || img.category}
                </span>
                <span className="text-[10px] text-slate-500">{formatFileSize(img.file_size)}</span>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  if (!confirm("Delete this image?")) return;
                  startTransition(async () => {
                    await deletePatientImage(img.id, img.file_path, patientId);
                  });
                }}
                className="absolute top-1 right-1 w-5 h-5 rounded-full bg-black/60 text-slate-400 hover:text-red-400 flex items-center justify-center text-[10px] opacity-0 group-hover:opacity-100 transition-opacity"
                title="Delete image"
              >
                ✕
              </button>
            </button>
          ))}
        </div>
      )}

      {/* Image viewer modal */}
      {viewingImage && (
        <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4" onClick={() => { setViewingImage(null); setSignedUrl(null); setOcrText(null); setOcrProgress(null); }}>
          <div className="relative max-w-4xl max-h-[90vh] w-full" onClick={(e) => e.stopPropagation()}>
            <div className="absolute -top-10 right-0 flex items-center gap-3">
              {/* OCR button */}
              {signedUrl && ocrProgress === null && !ocrText && (
                <button
                  onClick={() => handleOcr(signedUrl)}
                  className="text-blue-400 hover:text-blue-300 text-sm flex items-center gap-1.5 transition-colors"
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 3.75H6A2.25 2.25 0 0 0 3.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0 1 20.25 6v1.5m0 9V18A2.25 2.25 0 0 1 18 20.25h-1.5m-9 0H6A2.25 2.25 0 0 1 3.75 18v-1.5M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                  </svg>
                  Extract Text (OCR)
                </button>
              )}
              <button
                onClick={() => { setViewingImage(null); setSignedUrl(null); setOcrText(null); setOcrProgress(null); }}
                className="text-white/60 hover:text-white text-sm"
              >
                ✕ Close
              </button>
            </div>

            {signedUrl ? (
              <img src={signedUrl} alt="Patient image" className="w-full h-auto max-h-[85vh] object-contain rounded-lg" />
            ) : (
              <div className="flex items-center justify-center h-64">
                <div className="w-8 h-8 border-2 border-blue-500/30 border-t-blue-500 rounded-full animate-spin" />
              </div>
            )}

            {/* OCR Progress bar */}
            {ocrProgress !== null && (
              <div className="absolute bottom-4 left-4 right-4 bg-slate-900/90 backdrop-blur rounded-lg p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs text-slate-300">Extracting text…</span>
                  <span className="text-xs text-blue-400 font-mono">{ocrProgress}%</span>
                </div>
                <div className="h-1.5 bg-white/10 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-blue-500 to-teal-400 rounded-full transition-all duration-300"
                    style={{ width: `${ocrProgress}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* OCR Results modal */}
      {ocrText && (
        <div className="fixed inset-0 bg-black/70 z-[60] flex items-center justify-center p-4" onClick={() => setOcrText(null)}>
          <div className="bg-slate-800 border border-white/10 rounded-xl max-w-lg w-full max-h-[80vh] flex flex-col shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
              <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                <svg className="w-4 h-4 text-blue-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 3.75H6A2.25 2.25 0 0 0 3.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0 1 20.25 6v1.5m0 9V18A2.25 2.25 0 0 1 18 20.25h-1.5m-9 0H6A2.25 2.25 0 0 1 3.75 18v-1.5M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                </svg>
                Extracted Text
              </h3>
              <div className="flex items-center gap-2">
                <button
                  onClick={copyOcrText}
                  className="text-xs px-2.5 py-1 rounded-md bg-blue-600 hover:bg-blue-700 text-white transition-colors"
                >
                  {ocrCopied ? "✓ Copied" : "Copy"}
                </button>
                <button onClick={() => setOcrText(null)} className="text-slate-400 hover:text-white text-sm">✕</button>
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-4">
              <pre className="text-sm text-slate-200 whitespace-pre-wrap font-sans leading-relaxed">{ocrText}</pre>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
