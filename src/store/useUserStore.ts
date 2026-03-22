import { create } from "zustand";
import { createClient } from "@/lib/supabase/client";
import type { Profile, Role } from "@/types/roles";

interface UserState {
  profile: Profile | null;
  isLoading: boolean;
  error: string | null;
  fetchProfile: () => Promise<void>;
  setProfile: (profile: Profile) => void;
  clear: () => void;
  role: () => Role;
}

export const useUserStore = create<UserState>((set, get) => ({
  profile: null,
  isLoading: false,
  error: null,

  fetchProfile: async () => {
    set({ isLoading: true, error: null });
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!user) {
        set({ profile: null, isLoading: false });
        return;
      }

      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .single();

      if (error) throw error;

      set({ profile: data as Profile, isLoading: false });
    } catch (err) {
      set({
        error: err instanceof Error ? err.message : "Failed to fetch profile",
        isLoading: false,
      });
    }
  },

  setProfile: (profile) => set({ profile }),

  clear: () => set({ profile: null, isLoading: false, error: null }),

  role: () => get().profile?.role ?? "pg",
}));
