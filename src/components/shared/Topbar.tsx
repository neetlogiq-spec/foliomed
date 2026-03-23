"use client";

import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";
import { RoleBadge } from "./RoleBadge";
import type { Role } from "@/types/roles";
import { useOfflineStatus, usePendingSync } from "@/lib/offline/hooks";

interface TopbarProps {
  fullName: string;
  avatarUrl: string | null;
  role: Role;
  onMenuClick?: () => void;
}

export function Topbar({ fullName, avatarUrl, role, onMenuClick }: TopbarProps) {
  const router = useRouter();
  const { isOffline } = useOfflineStatus();
  const { pendingCount } = usePendingSync();

  const handleSignOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  };

  return (
    <>
      <header className="h-14 border-b border-white/5 bg-slate-950/50 backdrop-blur-sm flex items-center justify-between px-4 md:px-6">
        <div className="flex items-center gap-3">
          {onMenuClick && (
            <button
              onClick={onMenuClick}
              className="md:hidden p-2 -ml-2 rounded-lg hover:bg-white/5 text-slate-400 hover:text-white transition-colors"
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
              </svg>
            </button>
          )}
        </div>

        <div className="flex items-center gap-4">
          {/* Notification bell */}
          <button
            onClick={() => alert("Notifications coming soon!")}
            className="relative p-2 rounded-lg hover:bg-white/5 text-slate-400 hover:text-slate-200 transition-colors active:scale-95"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
            </svg>
          </button>

          <div className="h-6 w-px bg-white/10" />

          {/* User info */}
          <div className="flex items-center gap-3">
            {avatarUrl ? (
              <img
                src={avatarUrl}
                alt={fullName}
                className="w-8 h-8 rounded-full ring-2 ring-white/10"
              />
            ) : (
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-600 to-teal-500 flex items-center justify-center text-xs font-bold text-white">
                {fullName?.charAt(0)?.toUpperCase() || "?"}
              </div>
            )}
            <div className="hidden sm:block">
              <p className="text-sm font-medium text-white">{fullName}</p>
              <RoleBadge role={role} size="sm" />
            </div>
          </div>

          {/* Sign out */}
          <button
            onClick={handleSignOut}
            className="p-2 rounded-lg hover:bg-white/5 text-slate-400 hover:text-red-400 transition-colors"
            title="Sign out"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9" />
            </svg>
          </button>
        </div>
      </header>

      {/* Offline indicator */}
      {isOffline && (
        <div className="bg-amber-500/10 border-b border-amber-500/20 px-4 py-1.5 flex items-center justify-center gap-2 text-xs text-amber-300">
          <span>📴</span>
          <span>You&apos;re offline — viewing cached data</span>
          {pendingCount > 0 && (
            <span className="ml-2 bg-amber-500/20 px-2 py-0.5 rounded-full font-medium">
              {pendingCount} pending
            </span>
          )}
        </div>
      )}

      {/* Syncing indicator (online with pending) */}
      {!isOffline && pendingCount > 0 && (
        <div className="bg-emerald-500/10 border-b border-emerald-500/20 px-4 py-1.5 flex items-center justify-center gap-2 text-xs text-emerald-300">
          <div className="w-3 h-3 border-2 border-emerald-400 border-t-transparent rounded-full animate-spin" />
          <span>Syncing {pendingCount} change{pendingCount !== 1 ? "s" : ""}...</span>
        </div>
      )}
    </>
  );
}

