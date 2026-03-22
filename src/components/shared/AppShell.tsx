"use client";

import { useEffect, useState } from "react";
import { useUserStore } from "@/store/useUserStore";
import { Sidebar } from "@/components/shared/Sidebar";
import { Topbar } from "@/components/shared/Topbar";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const { profile, isLoading, fetchProfile } = useUserStore();
  const [mounted, setMounted] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    setMounted(true);
    fetchProfile();
  }, [fetchProfile]);

  if (!mounted || isLoading || !profile) {
    return (
      <div className="flex items-center justify-center h-screen bg-slate-950">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 border-3 border-blue-500/30 border-t-blue-500 rounded-full animate-spin" />
          <p className="text-sm text-slate-400">Loading workspace...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-slate-950 text-white">
      <Sidebar
        role={profile.role}
        fullName={profile.full_name}
        avatarUrl={profile.avatar_url}
        branch={profile.branch}
        isOpen={isMobileMenuOpen}
        onClose={() => setIsMobileMenuOpen(false)}
      />
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Topbar
          fullName={profile.full_name}
          avatarUrl={profile.avatar_url}
          role={profile.role}
          onMenuClick={() => setIsMobileMenuOpen(true)}
        />
        <main className="flex-1 overflow-y-auto bg-slate-900/50">
          {children}
        </main>
      </div>
    </div>
  );
}
