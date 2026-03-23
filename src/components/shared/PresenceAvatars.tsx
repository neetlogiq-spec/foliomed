"use client";

import type { CollaboratorPresence } from "@/hooks/useCollaborativeEditor";

interface PresenceAvatarsProps {
  collaborators: CollaboratorPresence[];
}

export function PresenceAvatars({ collaborators }: PresenceAvatarsProps) {
  if (collaborators.length === 0) return null;

  return (
    <div className="flex items-center gap-1">
      <span className="text-[10px] text-slate-500 mr-1">
        {collaborators.length} online
      </span>
      <div className="flex -space-x-2">
        {collaborators.map((c) => (
          <div
            key={c.userId}
            className="relative group"
          >
            {c.avatarUrl ? (
              <img
                src={c.avatarUrl}
                alt={c.fullName}
                className="w-6 h-6 rounded-full ring-2 ring-slate-900"
                style={{ boxShadow: `0 0 0 2px ${c.color}` }}
              />
            ) : (
              <div
                className="w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold text-white ring-2 ring-slate-900"
                style={{ backgroundColor: c.color }}
              >
                {c.fullName?.charAt(0)?.toUpperCase() || "?"}
              </div>
            )}
            {/* Tooltip */}
            <div className="absolute -bottom-7 left-1/2 -translate-x-1/2 bg-slate-800 text-white text-[10px] px-1.5 py-0.5 rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-20">
              {c.fullName}
            </div>
            {/* Active indicator */}
            {c.activeBlockId && (
              <span
                className="absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full ring-1 ring-slate-900 animate-pulse"
                style={{ backgroundColor: c.color }}
              />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
