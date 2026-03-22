"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { BLOCK_TYPES } from "@/types/document";
import type { BlockType } from "@/types/document";
import { cn } from "@/lib/utils";

interface SlashMenuProps {
  /** Pixel coordinates relative to viewport */
  position: { top: number; left: number };
  onSelect: (type: BlockType) => void;
  onClose: () => void;
}

export function SlashMenu({ position, onSelect, onClose }: SlashMenuProps) {
  const [filter, setFilter] = useState("");
  const [activeIndex, setActiveIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  const filtered = BLOCK_TYPES.filter(
    (bt) =>
      bt.label.toLowerCase().includes(filter.toLowerCase()) ||
      (bt.description ?? "").toLowerCase().includes(filter.toLowerCase())
  );

  // Focus the search input on mount
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  // Reset active index when filter changes
  useEffect(() => {
    setActiveIndex(0);
  }, [filter]);

  // Close on outside click
  useEffect(() => {
    const handle = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    document.addEventListener("mousedown", handle);
    return () => document.removeEventListener("mousedown", handle);
  }, [onClose]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setActiveIndex((i) => Math.min(i + 1, filtered.length - 1));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setActiveIndex((i) => Math.max(i - 1, 0));
      } else if (e.key === "Enter") {
        e.preventDefault();
        if (filtered[activeIndex]) onSelect(filtered[activeIndex].type);
      } else if (e.key === "Escape") {
        e.preventDefault();
        onClose();
      }
    },
    [filtered, activeIndex, onSelect, onClose]
  );

  return (
    <div
      ref={menuRef}
      style={{ top: position.top, left: position.left }}
      className="fixed z-50 w-56 bg-slate-800 border border-white/10 rounded-xl shadow-2xl overflow-hidden animate-in fade-in slide-in-from-top-1 duration-150"
    >
      {/* Search bar */}
      <div className="p-1.5 border-b border-white/5">
        <input
          ref={inputRef}
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Filter…"
          className="w-full bg-white/5 border-none rounded-md text-xs text-white px-2 py-1.5 placeholder:text-slate-500 outline-none focus:ring-1 focus:ring-blue-500/40"
        />
      </div>

      {/* Options */}
      <div className="max-h-52 overflow-y-auto py-1">
        {filtered.length === 0 ? (
          <p className="text-[10px] text-slate-500 text-center py-3">No blocks found</p>
        ) : (
          filtered.map((bt, i) => (
            <button
              key={bt.type}
              onMouseEnter={() => setActiveIndex(i)}
              onClick={() => onSelect(bt.type)}
              className={cn(
                "flex items-center gap-2.5 w-full px-3 py-2 text-left transition-colors",
                i === activeIndex ? "bg-blue-600/20 text-white" : "text-slate-300 hover:bg-white/5"
              )}
            >
              <span className="w-7 h-7 rounded-md bg-white/5 border border-white/10 flex items-center justify-center text-sm shrink-0">
                {bt.icon}
              </span>
              <div className="min-w-0">
                <p className="text-xs font-medium truncate">{bt.label}</p>
                {bt.description && (
                  <p className="text-[10px] text-slate-500 truncate">{bt.description}</p>
                )}
              </div>
            </button>
          ))
        )}
      </div>
    </div>
  );
}
