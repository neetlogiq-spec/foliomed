"use client";

import { useState, useRef, useCallback } from "react";

interface ImageViewerProps {
  images: string[];          // data-URLs
  className?: string;
}

export function ImageViewer({ images, className }: ImageViewerProps) {
  const [activeIdx, setActiveIdx] = useState(0);
  const [scale, setScale] = useState(1);
  const [translate, setTranslate] = useState({ x: 0, y: 0 });
  const dragStart = useRef<{ x: number; y: number; tx: number; ty: number } | null>(null);
  const lastTouchDist = useRef<number | null>(null);

  const activeImage = images[activeIdx];

  const resetView = useCallback(() => {
    setScale(1);
    setTranslate({ x: 0, y: 0 });
  }, []);

  // ── Mouse wheel zoom ─────────────────────────────────────────────────────
  const handleWheel = useCallback((e: React.WheelEvent) => {
    e.preventDefault();
    setScale((s) => Math.min(5, Math.max(0.5, s - e.deltaY * 0.001)));
  }, []);

  // ── Mouse drag pan ───────────────────────────────────────────────────────
  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    dragStart.current = { x: e.clientX, y: e.clientY, tx: translate.x, ty: translate.y };
  }, [translate]);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (!dragStart.current) return;
    setTranslate({
      x: dragStart.current.tx + (e.clientX - dragStart.current.x),
      y: dragStart.current.ty + (e.clientY - dragStart.current.y),
    });
  }, []);

  const handleMouseUp = useCallback(() => { dragStart.current = null; }, []);

  // ── Touch pan + pinch zoom ───────────────────────────────────────────────
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (e.touches.length === 1) {
      dragStart.current = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY,
        tx: translate.x,
        ty: translate.y,
      };
    } else if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      lastTouchDist.current = Math.hypot(dx, dy);
    }
  }, [translate]);

  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    e.preventDefault();
    if (e.touches.length === 1 && dragStart.current) {
      setTranslate({
        x: dragStart.current.tx + (e.touches[0].clientX - dragStart.current.x),
        y: dragStart.current.ty + (e.touches[0].clientY - dragStart.current.y),
      });
    } else if (e.touches.length === 2 && lastTouchDist.current !== null) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.hypot(dx, dy);
      const delta = dist - lastTouchDist.current;
      lastTouchDist.current = dist;
      setScale((s) => Math.min(5, Math.max(0.5, s + delta * 0.005)));
    }
  }, []);

  const handleTouchEnd = useCallback(() => {
    dragStart.current = null;
    lastTouchDist.current = null;
  }, []);

  if (!activeImage) {
    return (
      <div className={`flex items-center justify-center bg-white/5 rounded-lg text-slate-500 text-sm ${className ?? ""}`}>
        No image
      </div>
    );
  }

  return (
    <div className={`flex flex-col gap-2 ${className ?? ""}`}>
      {/* Main image pane */}
      <div
        className="relative flex-1 overflow-hidden rounded-lg bg-black/40 border border-white/10 cursor-grab active:cursor-grabbing select-none min-h-[240px]"
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        {/* Reset button */}
        {(scale !== 1 || translate.x !== 0 || translate.y !== 0) && (
          <button
            onClick={resetView}
            className="absolute top-2 right-2 z-10 bg-black/60 text-white text-[10px] px-2 py-1 rounded hover:bg-black/80"
          >
            Reset
          </button>
        )}

        {/* Zoom indicator */}
        <span className="absolute bottom-2 left-2 z-10 bg-black/60 text-slate-300 text-[10px] px-1.5 py-0.5 rounded">
          {Math.round(scale * 100)}%
        </span>

        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={activeImage}
          alt={`Scanned document ${activeIdx + 1}`}
          draggable={false}
          style={{
            transform: `translate(${translate.x}px, ${translate.y}px) scale(${scale})`,
            transformOrigin: "center center",
            transition: dragStart.current ? "none" : "transform 0.1s ease-out",
            maxWidth: "100%",
            maxHeight: "100%",
            width: "100%",
            height: "100%",
            objectFit: "contain",
          }}
        />
      </div>

      {/* Thumbnail strip — only shown when >1 image */}
      {images.length > 1 && (
        <div className="flex gap-1.5 overflow-x-auto pb-1">
          {images.map((img, i) => (
            <button
              key={i}
              onClick={() => { setActiveIdx(i); resetView(); }}
              className={`flex-shrink-0 w-12 h-12 rounded border-2 overflow-hidden transition-colors ${
                i === activeIdx ? "border-blue-500" : "border-white/10 hover:border-white/30"
              }`}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={img} alt={`Page ${i + 1}`} className="w-full h-full object-cover" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
