"use client";

import { useEffect, useRef, useCallback, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { RealtimeChannel } from "@supabase/supabase-js";
import type { Block } from "@/types/document";

const COLLABORATOR_COLORS = [
  "#8b5cf6", "#3b82f6", "#10b981", "#f59e0b", "#ef4444",
  "#ec4899", "#06b6d4", "#f97316",
];

export interface CollaboratorPresence {
  userId: string;
  fullName: string;
  avatarUrl: string | null;
  activeBlockId: string | null;
  color: string;
}

interface UseCollaborativeEditorOptions {
  docId: string;
  userId: string;
  fullName: string;
  avatarUrl: string | null;
  blocks: Block[];
  onBlockUpdate: (blockId: string, content: string) => void;
  onBlockAdd: (afterIndex: number, block: Block) => void;
  onBlockDelete: (blockId: string) => void;
  onBlockMove: (blockId: string, direction: -1 | 1) => void;
  onExternalSave: (version: number) => void;
}

export function useCollaborativeEditor({
  docId,
  userId,
  fullName,
  avatarUrl,
  blocks,
  onBlockUpdate,
  onBlockAdd,
  onBlockDelete,
  onBlockMove,
  onExternalSave,
}: UseCollaborativeEditorOptions) {
  const [collaborators, setCollaborators] = useState<CollaboratorPresence[]>([]);
  const [lockedBlocks, setLockedBlocks] = useState<Map<string, { userId: string; fullName: string; color: string }>>(new Map());
  const channelRef = useRef<RealtimeChannel | null>(null);
  const colorIndexRef = useRef(0);
  const userColorMap = useRef<Map<string, string>>(new Map());

  // Assign a stable color to a user
  const getColorForUser = useCallback((uid: string) => {
    if (userColorMap.current.has(uid)) return userColorMap.current.get(uid)!;
    const color = COLLABORATOR_COLORS[colorIndexRef.current % COLLABORATOR_COLORS.length];
    colorIndexRef.current++;
    userColorMap.current.set(uid, color);
    return color;
  }, []);

  useEffect(() => {
    const supabase = createClient();

    const channel = supabase.channel(`doc:${docId}`, {
      config: { presence: { key: userId } },
    });

    // ── Presence ──
    channel.on("presence", { event: "sync" }, () => {
      const state = channel.presenceState();
      const users: CollaboratorPresence[] = [];
      for (const [key, presences] of Object.entries(state)) {
        if (key === userId) continue;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const p = (presences as any[])[0];
        if (p) {
          users.push({
            userId: key,
            fullName: p.fullName || "Unknown",
            avatarUrl: p.avatarUrl || null,
            activeBlockId: p.activeBlockId || null,
            color: getColorForUser(key),
          });
        }
      }
      setCollaborators(users);
    });

    // ── Broadcast listeners ──
    channel.on("broadcast", { event: "block:focus" }, ({ payload }) => {
      if (payload.userId === userId) return;
      setLockedBlocks((prev) => {
        const next = new Map(prev);
        next.set(payload.blockId, {
          userId: payload.userId,
          fullName: payload.fullName,
          color: getColorForUser(payload.userId),
        });
        return next;
      });
    });

    channel.on("broadcast", { event: "block:blur" }, ({ payload }) => {
      if (payload.userId === userId) return;
      setLockedBlocks((prev) => {
        const next = new Map(prev);
        next.delete(payload.blockId);
        return next;
      });
    });

    channel.on("broadcast", { event: "block:update" }, ({ payload }) => {
      if (payload.userId === userId) return;
      onBlockUpdate(payload.blockId, payload.content);
    });

    channel.on("broadcast", { event: "block:add" }, ({ payload }) => {
      if (payload.userId === userId) return;
      onBlockAdd(payload.afterIndex, payload.block);
    });

    channel.on("broadcast", { event: "block:delete" }, ({ payload }) => {
      if (payload.userId === userId) return;
      onBlockDelete(payload.blockId);
    });

    channel.on("broadcast", { event: "block:move" }, ({ payload }) => {
      if (payload.userId === userId) return;
      onBlockMove(payload.blockId, payload.direction);
    });

    channel.on("broadcast", { event: "doc:save" }, ({ payload }) => {
      if (payload.userId === userId) return;
      onExternalSave(payload.version);
    });

    channel.subscribe(async (status) => {
      if (status === "SUBSCRIBED") {
        await channel.track({
          fullName,
          avatarUrl,
          activeBlockId: null,
          online_at: new Date().toISOString(),
        });
      }
    });

    channelRef.current = channel;

    return () => {
      channel.unsubscribe();
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [docId, userId]);

  // ── Broadcast helpers ──
  const broadcastBlockFocus = useCallback((blockId: string) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:focus",
      payload: { blockId, userId, fullName },
    });
    // Update presence with active block
    channelRef.current?.track({
      fullName,
      avatarUrl,
      activeBlockId: blockId,
      online_at: new Date().toISOString(),
    });
  }, [userId, fullName, avatarUrl]);

  const broadcastBlockBlur = useCallback((blockId: string) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:blur",
      payload: { blockId, userId },
    });
    channelRef.current?.track({
      fullName,
      avatarUrl,
      activeBlockId: null,
      online_at: new Date().toISOString(),
    });
  }, [userId, fullName, avatarUrl]);

  const broadcastBlockUpdate = useCallback((blockId: string, content: string) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:update",
      payload: { blockId, content, userId },
    });
  }, [userId]);

  const broadcastBlockAdd = useCallback((afterIndex: number, block: Block) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:add",
      payload: { afterIndex, block, userId },
    });
  }, [userId]);

  const broadcastBlockDelete = useCallback((blockId: string) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:delete",
      payload: { blockId, userId },
    });
  }, [userId]);

  const broadcastBlockMove = useCallback((blockId: string, direction: -1 | 1) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "block:move",
      payload: { blockId, direction, userId },
    });
  }, [userId]);

  const broadcastSave = useCallback((version: number) => {
    channelRef.current?.send({
      type: "broadcast",
      event: "doc:save",
      payload: { version, userId },
    });
  }, [userId]);

  const isBlockLocked = useCallback((blockId: string) => {
    return lockedBlocks.get(blockId) || null;
  }, [lockedBlocks]);

  return {
    collaborators,
    lockedBlocks,
    isBlockLocked,
    broadcastBlockFocus,
    broadcastBlockBlur,
    broadcastBlockUpdate,
    broadcastBlockAdd,
    broadcastBlockDelete,
    broadcastBlockMove,
    broadcastSave,
  };
}
