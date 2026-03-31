"use client";

import { useState, useEffect, useCallback } from "react";
import { getQueue, dequeue, getPendingCount, type QueuedMutation } from "./db";

// ─── Online/Offline Status ────────────────────────────────────
export function useOfflineStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    // Set initial state
    setIsOnline(navigator.onLine);

    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  return { isOnline, isOffline: !isOnline };
}

// ─── Pending Mutation Count ───────────────────────────────────
export function usePendingSync() {
  const [count, setCount] = useState(0);
  const [syncing, setSyncing] = useState(false);

  const refresh = useCallback(async () => {
    const c = await getPendingCount();
    setCount(c);
  }, []);

  useEffect(() => {
    refresh();
    // Refresh count every 5 seconds
    const interval = setInterval(refresh, 5000);
    return () => clearInterval(interval);
  }, [refresh]);

  return { pendingCount: count, syncing, setSyncing, refresh };
}

// ─── Sync Engine ──────────────────────────────────────────────
// Maps action names to the actual server action functions
type ActionMap = Record<string, (payload: Record<string, unknown>) => Promise<{ error?: string; success?: boolean }>>;

export function useSyncEngine(actionMap: ActionMap) {
  const { isOnline } = useOfflineStatus();
  const { pendingCount, syncing, setSyncing, refresh } = usePendingSync();

  const sync = useCallback(async () => {
    if (syncing) return;
    setSyncing(true);

    try {
      const queue = await getQueue();
      const pending = queue.filter((m) => m.status === "pending");

      for (const mutation of pending) {
        const actionFn = actionMap[mutation.action];
        if (!actionFn) {
          // Unknown action — drop it so it doesn't block the queue forever
          await dequeue(mutation.id);
          continue;
        }

        try {
          await actionFn(mutation.payload);
          // Dequeue regardless of success/failure — don't retry indefinitely
          await dequeue(mutation.id);
        } catch {
          // Network error — leave in queue for next retry
        }
      }
    } finally {
      setSyncing(false);
      await refresh();
    }
  }, [actionMap, syncing, setSyncing, refresh]);

  // Auto-sync when coming back online
  useEffect(() => {
    if (isOnline && pendingCount > 0) {
      sync();
    }
  }, [isOnline, pendingCount, sync]);

  return { pendingCount, syncing, sync };
}
