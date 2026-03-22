"use client";

import { useState, useTransition } from "react";
import { CASE_TAGS } from "@/types/patient";
import { cn } from "@/lib/utils";

interface CaseTagsProps {
  patientId: string;
  currentTags: string[];
  onUpdate: (patientId: string, tags: string[]) => Promise<{ error?: string }>;
}

export function CaseTags({ patientId, currentTags, onUpdate }: CaseTagsProps) {
  const [tags, setTags] = useState<string[]>(currentTags);
  const [showPicker, setShowPicker] = useState(false);
  const [isPending, startTransition] = useTransition();

  const toggleTag = (tagValue: string) => {
    const newTags = tags.includes(tagValue)
      ? tags.filter((t) => t !== tagValue)
      : [...tags, tagValue];

    setTags(newTags);
    startTransition(async () => {
      await onUpdate(patientId, newTags);
    });
  };

  return (
    <div className="relative">
      {/* Current tags */}
      <div className="flex flex-wrap gap-1 items-center">
        {tags.map((tag) => {
          const config = CASE_TAGS.find((t) => t.value === tag);
          if (!config) return null;
          return (
            <button
              key={tag}
              onClick={() => toggleTag(tag)}
              disabled={isPending}
              className={cn(
                "text-[10px] px-1.5 py-0.5 rounded-full inline-flex items-center gap-0.5 transition-opacity hover:opacity-70",
                config.color
              )}
              title={`Remove ${config.label}`}
            >
              <span>{config.icon}</span>
              <span>{config.label}</span>
            </button>
          );
        })}
        <button
          onClick={() => setShowPicker(!showPicker)}
          className="w-5 h-5 rounded-full bg-white/5 border border-white/10 text-slate-500 hover:text-blue-400 hover:border-blue-500/30 text-[10px] flex items-center justify-center transition-colors"
          title="Add tag"
        >
          +
        </button>
      </div>

      {/* Tag picker */}
      {showPicker && (
        <div className="absolute top-full left-0 mt-1 z-30 bg-slate-800 border border-white/10 rounded-lg p-2 shadow-xl min-w-[240px]">
          <p className="text-[10px] text-slate-500 mb-1.5">Toggle tags:</p>
          <div className="flex flex-wrap gap-1">
            {CASE_TAGS.map((tag) => (
              <button
                key={tag.value}
                onClick={() => toggleTag(tag.value)}
                disabled={isPending}
                className={cn(
                  "text-[10px] px-2 py-1 rounded-full inline-flex items-center gap-1 border transition-all",
                  tags.includes(tag.value)
                    ? `${tag.color} border-current`
                    : "text-slate-400 bg-white/5 border-transparent hover:bg-white/10"
                )}
              >
                <span>{tag.icon}</span>
                <span>{tag.label}</span>
              </button>
            ))}
          </div>
          <button
            onClick={() => setShowPicker(false)}
            className="text-[10px] text-slate-500 hover:text-slate-300 mt-2 block"
          >
            Done
          </button>
        </div>
      )}
    </div>
  );
}

// Compact inline tag display (read-only) for patient list
export function TagBadges({ tags }: { tags: string[] }) {
  if (!tags || tags.length === 0) return null;
  return (
    <div className="flex flex-wrap gap-0.5">
      {tags.slice(0, 3).map((tag) => {
        const config = CASE_TAGS.find((t) => t.value === tag);
        if (!config) return null;
        return (
          <span
            key={tag}
            className={cn("text-[9px] px-1 py-0.5 rounded", config.color)}
            title={config.label}
          >
            {config.icon}
          </span>
        );
      })}
      {tags.length > 3 && (
        <span className="text-[9px] text-slate-500">+{tags.length - 3}</span>
      )}
    </div>
  );
}
