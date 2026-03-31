"use client";

import { useState, useTransition, useCallback, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { saveDocument, publishDocument, deleteDocument } from "../actions";
import type { Block, BlockType } from "@/types/document";
import { BLOCK_TYPES, emptyBlock } from "@/types/document";
import { cn } from "@/lib/utils";
import { SlashMenu } from "@/components/shared/SlashMenu";
import { useCollaborativeEditor } from "@/hooks/useCollaborativeEditor";
import { PresenceAvatars } from "@/components/shared/PresenceAvatars";
import { ScanButton } from "@/components/shared/ScanButton";

interface DocumentEditorProps {
  docId: string;
  initialTitle: string;
  initialBlocks: Block[];
  initialVersion: number;
  isDraft: boolean;
  currentUser: {
    id: string;
    fullName: string;
    avatarUrl: string | null;
  };
}

/* ── Slash menu state ─────────────────────── */
interface SlashState {
  blockId: string;
  position: { top: number; left: number };
}

export function DocumentEditor({
  docId,
  initialTitle,
  initialBlocks,
  initialVersion,
  isDraft,
  currentUser,
}: DocumentEditorProps) {
  const router = useRouter();
  const [title, setTitle] = useState(initialTitle);
  const [blocks, setBlocks] = useState<Block[]>(initialBlocks);
  const [version, setVersion] = useState(initialVersion);
  const [draft, setDraft] = useState(isDraft);
  const [isPending, startTransition] = useTransition();
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showBlockMenu, setShowBlockMenu] = useState<number | null>(null);
  const [slash, setSlash] = useState<SlashState | null>(null);
  const [activeBlockId, setActiveBlockId] = useState<string | null>(null);
  const printRef = useRef<HTMLDivElement>(null);
  const autoSaveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dirtyRef = useRef(false);
  const debounceTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  /* ── Block CRUD helpers (local state) ──── */
  const updateBlockLocal = useCallback((id: string, content: string) => {
    setBlocks((prev) => prev.map((b) => (b.id === id ? { ...b, content } : b)));
    dirtyRef.current = true;
    setSaved(false);
  }, []);

  const addBlockLocal = useCallback((afterIndex: number, newBlock?: Block) => {
    const block = newBlock || emptyBlock("text");
    setBlocks((prev) => {
      const next = [...prev];
      next.splice(afterIndex + 1, 0, block);
      return next;
    });
    setShowBlockMenu(null);
    dirtyRef.current = true;
    setSaved(false);
    return block;
  }, []);

  const removeBlockLocal = useCallback((id: string) => {
    setBlocks((prev) => (prev.length <= 1 ? prev : prev.filter((b) => b.id !== id)));
    dirtyRef.current = true;
    setSaved(false);
  }, []);

  const moveBlockLocal = useCallback((id: string, dir: -1 | 1) => {
    setBlocks((prev) => {
      const idx = prev.findIndex((b) => b.id === id);
      if (idx < 0) return prev;
      const newIdx = idx + dir;
      if (newIdx < 0 || newIdx >= prev.length) return prev;
      const next = [...prev];
      [next[idx], next[newIdx]] = [next[newIdx], next[idx]];
      return next;
    });
    dirtyRef.current = true;
    setSaved(false);
  }, []);

  const changeBlockType = useCallback((id: string, type: BlockType) => {
    setBlocks((prev) => prev.map((b) => (b.id === id ? { ...b, type, content: b.content } : b)));
    setSaved(false);
  }, []);

  /* ── Collaborative editing ─────────────── */
  const {
    collaborators,
    isBlockLocked,
    broadcastBlockFocus,
    broadcastBlockBlur,
    broadcastBlockUpdate,
    broadcastBlockAdd,
    broadcastBlockDelete,
    broadcastBlockMove,
    broadcastSave,
  } = useCollaborativeEditor({
    docId,
    userId: currentUser.id,
    fullName: currentUser.fullName,
    avatarUrl: currentUser.avatarUrl,
    blocks,
    onBlockUpdate: updateBlockLocal,
    onBlockAdd: (afterIndex, block) => addBlockLocal(afterIndex, block),
    onBlockDelete: removeBlockLocal,
    onBlockMove: moveBlockLocal,
    onExternalSave: (newVersion) => {
      setVersion(newVersion);
      setSaved(true);
    },
  });

  /* ── Wrapped CRUD (local + broadcast) ──── */
  const updateBlock = useCallback((id: string, content: string) => {
    updateBlockLocal(id, content);
    // Debounce broadcast to avoid flooding
    const existing = debounceTimers.current.get(id);
    if (existing) clearTimeout(existing);
    debounceTimers.current.set(id, setTimeout(() => {
      broadcastBlockUpdate(id, content);
      debounceTimers.current.delete(id);
    }, 300));
  }, [updateBlockLocal, broadcastBlockUpdate]);

  const addBlock = useCallback((afterIndex: number, type: BlockType = "text") => {
    const block = emptyBlock(type);
    addBlockLocal(afterIndex, block);
    broadcastBlockAdd(afterIndex, block);
  }, [addBlockLocal, broadcastBlockAdd]);

  const removeBlock = useCallback((id: string) => {
    removeBlockLocal(id);
    broadcastBlockDelete(id);
  }, [removeBlockLocal, broadcastBlockDelete]);

  const moveBlock = useCallback((id: string, dir: -1 | 1) => {
    moveBlockLocal(id, dir);
    broadcastBlockMove(id, dir);
  }, [moveBlockLocal, broadcastBlockMove]);

  /* ── Focus / Blur for block locking ────── */
  const handleBlockFocus = useCallback((blockId: string) => {
    setActiveBlockId(blockId);
    broadcastBlockFocus(blockId);
  }, [broadcastBlockFocus]);

  const handleBlockBlur = useCallback((blockId: string) => {
    setActiveBlockId((prev) => (prev === blockId ? null : prev));
    broadcastBlockBlur(blockId);
  }, [broadcastBlockBlur]);

  /* ── Slash command handling ──────────────── */
  const handleSlashTrigger = useCallback((blockId: string, el: HTMLElement) => {
    const rect = el.getBoundingClientRect();
    setSlash({
      blockId,
      position: { top: rect.bottom + 4, left: rect.left },
    });
  }, []);

  const handleSlashSelect = useCallback(
    (type: BlockType) => {
      if (!slash) return;
      const block = blocks.find((b) => b.id === slash.blockId);
      if (!block) { setSlash(null); return; }

      const trimmed = block.content.trim();
      if (trimmed === "/" || trimmed === "") {
        changeBlockType(slash.blockId, type);
        updateBlock(slash.blockId, "");
      } else {
        const idx = blocks.findIndex((b) => b.id === slash.blockId);
        updateBlock(slash.blockId, block.content.replace(/\/\s*$/, ""));
        addBlock(idx, type);
      }
      setSlash(null);
    },
    [slash, blocks, changeBlockType, updateBlock, addBlock]
  );

  /* ── Delete ──────────────────────────────── */
  const handleDelete = useCallback(() => {
    startTransition(async () => {
      const result = await deleteDocument(docId);
      if (result?.error) setError(result.error);
      else router.push("/documents");
    });
  }, [docId, router]);

  /* ── OCR → blocks ───────────────────────── */
  const handleOCRExtract = useCallback(
    (data: Record<string, unknown>) => {
      const newBlocks: Block[] = [];

      // Prefer structured sections from case_document context
      const sections = data.sections;
      if (Array.isArray(sections)) {
        for (const section of sections as Array<{
          title?: string;
          content?: string;
          type?: string;
        }>) {
          if (section.title) {
            newBlocks.push({ ...emptyBlock("heading"), content: section.title });
          }
          if (section.content) {
            const blockType =
              section.type === "findings"
                ? "findings"
                : section.type === "plan"
                  ? "plan"
                  : "text";
            newBlocks.push({ ...emptyBlock(blockType), content: section.content });
          }
        }
      }

      // Fallback: raw_text or any string fields
      if (!newBlocks.length) {
        const rawText =
          typeof data.raw_text === "string"
            ? data.raw_text
            : typeof data.text === "string"
              ? data.text
              : null;

        if (rawText) {
          const paragraphs = rawText
            .split(/\n{2,}/)
            .map((p) => p.trim())
            .filter(Boolean);
          for (const p of paragraphs) {
            newBlocks.push({ ...emptyBlock("text"), content: p });
          }
        } else {
          // Key-value pairs → one text block per field
          for (const [key, value] of Object.entries(data)) {
            if (
              key === "confidence" ||
              value === null ||
              value === undefined ||
              value === ""
            )
              continue;
            if (typeof value === "object") continue;
            const label = key.replace(/_/g, " ");
            newBlocks.push({
              ...emptyBlock("text"),
              content: `${label}: ${String(value)}`,
            });
          }
        }
      }

      if (!newBlocks.length) return;

      // Append after the last block
      setBlocks((prev) => {
        const next = [...prev, ...newBlocks];
        dirtyRef.current = true;
        setSaved(false);
        return next;
      });
    },
    []
  );

  /* ── Save / Publish ─────────────────────── */
  const handleSave = useCallback(() => {
    setError(null);
    startTransition(async () => {
      const result = await saveDocument(docId, { blocks }, title);
      if (result?.error) setError(result.error);
      else if ('version' in result) {
        const newVersion = result.version ?? version + 1;
        setVersion(newVersion);
        setSaved(true);
        dirtyRef.current = false;
        broadcastSave(newVersion);
      }
    });
  }, [docId, blocks, title, version, broadcastSave]);

  const handlePublish = useCallback(() => {
    startTransition(async () => {
      await saveDocument(docId, { blocks }, title);
      const result = await publishDocument(docId);
      if (result?.error) setError(result.error);
      else setDraft(false);
    });
  }, [docId, blocks, title]);

  /* ── Auto-save every 15s if dirty ──────── */
  useEffect(() => {
    autoSaveTimer.current = setInterval(() => {
      if (dirtyRef.current && !isPending) {
        handleSave();
      }
    }, 15000);
    return () => {
      if (autoSaveTimer.current) clearInterval(autoSaveTimer.current);
    };
  }, [handleSave, isPending]);

  /* ── PDF Export ──────────────────────────── */
  const handleExportPDF = () => {
    const printArea = printRef.current;
    if (!printArea) return;

    const html = blocks
      .map((b) => {
        switch (b.type) {
          case "heading":
            return `<h2 style="font-size:18px;font-weight:700;margin:18px 0 6px;border-bottom:1px solid #e2e8f0;padding-bottom:4px;">${esc(b.content)}</h2>`;
          case "text":
            return `<p style="font-size:13px;margin:4px 0;white-space:pre-wrap;">${esc(b.content)}</p>`;
          case "list":
            return `<ul style="font-size:13px;margin:4px 0 4px 20px;list-style:disc;">${b.content
              .split("\n")
              .map((l) => `<li>${esc(l.replace(/^[•\-]\s*/, ""))}</li>`)
              .join("")}</ul>`;
          case "findings":
            return `<div style="border:1px solid #93c5fd;border-radius:6px;padding:10px 12px;margin:8px 0;background:#eff6ff;"><p style="font-size:11px;font-weight:700;color:#2563eb;margin-bottom:4px;">🔍 Findings</p><p style="font-size:13px;white-space:pre-wrap;">${esc(b.content)}</p></div>`;
          case "plan":
            return `<div style="border:1px solid #6ee7b7;border-radius:6px;padding:10px 12px;margin:8px 0;background:#ecfdf5;"><p style="font-size:11px;font-weight:700;color:#059669;margin-bottom:4px;">📋 Plan</p><p style="font-size:13px;white-space:pre-wrap;">${esc(b.content)}</p></div>`;
          case "callout":
            return `<div style="border:1px solid #fbbf24;border-radius:6px;padding:10px 12px;margin:8px 0;background:#fffbeb;"><p style="font-size:11px;font-weight:700;color:#d97706;margin-bottom:4px;">💡 Callout</p><p style="font-size:13px;white-space:pre-wrap;">${esc(b.content)}</p></div>`;
          case "quote":
            return `<blockquote style="border-left:3px solid #94a3b8;padding:4px 12px;margin:8px 0;font-style:italic;font-size:13px;color:#475569;">${esc(b.content)}</blockquote>`;
          case "divider":
            return `<hr style="border:none;border-top:1px solid #cbd5e1;margin:12px 0;" />`;
          default:
            return `<p style="font-size:13px;">${esc(b.content)}</p>`;
        }
      })
      .join("");

    printArea.innerHTML = `
      <div style="font-family:'Inter',system-ui,sans-serif;max-width:700px;margin:0 auto;padding:32px 24px;color:#1e293b;">
        <h1 style="font-size:22px;font-weight:800;margin-bottom:4px;">${esc(title)}</h1>
        <p style="font-size:11px;color:#94a3b8;margin-bottom:20px;">Version ${version} · Exported ${new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}</p>
        ${html}
      </div>
    `;

    window.print();
  };

  return (
    <div className="space-y-4">
      {/* Toolbar */}
      <div className="flex items-center justify-between gap-3 sticky top-0 z-10 bg-slate-900/95 backdrop-blur py-2 print:hidden">
        <div className="flex items-center gap-2 min-w-0 flex-1">
          <Input
            value={title}
            onChange={(e) => { setTitle(e.target.value); setSaved(false); dirtyRef.current = true; }}
            className="bg-white/5 border-white/10 text-white text-lg font-semibold max-w-md"
          />
          <span className="text-[10px] text-slate-500 shrink-0">v{version}</span>
          {draft && <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400">Draft</span>}
          {saved && <span className="text-[10px] text-emerald-400">✓ Saved</span>}
          {error && <span className="text-[10px] text-red-400">{error}</span>}
        </div>
        <div className="flex items-center gap-3">
          <PresenceAvatars collaborators={collaborators} />
          <div className="flex gap-2">
            <ScanButton
              context="case_document"
              onExtract={handleOCRExtract}
              label="📷 Scan"
              className="text-xs"
            />
            <Button onClick={handleExportPDF} size="sm" variant="outline"
              className="border-white/10 text-slate-300 hover:bg-white/5 text-xs gap-1.5">
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" />
              </svg>
              PDF
            </Button>
            <Button onClick={handleSave} disabled={isPending} size="sm" variant="outline"
              className="border-white/10 text-slate-300 hover:bg-white/5 text-xs">
              {isPending ? "Saving..." : "Save"}
            </Button>
            {draft && (
              <Button onClick={handlePublish} disabled={isPending} size="sm"
                className="bg-emerald-600 hover:bg-emerald-700 text-white text-xs">
                Publish
              </Button>
            )}
            <Button
              onClick={() => setShowDeleteConfirm(true)}
              disabled={isPending}
              size="sm"
              variant="outline"
              className="border-red-500/20 text-red-400 hover:bg-red-500/10 hover:border-red-500/40 text-xs"
              title="Delete document"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
              </svg>
            </Button>
          </div>
        </div>
      </div>

      {/* Delete confirm dialog */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-white/10 rounded-xl p-6 w-full max-w-sm shadow-2xl">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-9 h-9 rounded-full bg-red-500/10 flex items-center justify-center shrink-0">
                <svg className="w-4 h-4 text-red-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                </svg>
              </div>
              <div>
                <p className="text-sm font-semibold text-white">Delete &ldquo;{title}&rdquo;?</p>
                <p className="text-xs text-slate-400 mt-0.5">This cannot be undone.</p>
              </div>
            </div>
            <div className="flex gap-2 mt-4">
              <button onClick={() => setShowDeleteConfirm(false)} disabled={isPending}
                className="flex-1 py-2 rounded-lg text-xs font-medium border border-white/10 text-slate-300 hover:bg-white/5 transition-colors">
                Cancel
              </button>
              <button onClick={handleDelete} disabled={isPending}
                className="flex-1 py-2 rounded-lg text-xs font-medium bg-red-600 hover:bg-red-700 text-white transition-colors disabled:opacity-60">
                {isPending ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Blocks */}
      <div className="space-y-1 print:hidden">
        {blocks.map((block, idx) => {
          const lockInfo = isBlockLocked(block.id);
          const isLocked = !!lockInfo;

          return (
            <div key={block.id} className="group relative">
              {/* Lock indicator */}
              {isLocked && (
                <div
                  className="absolute -left-2 top-0 bottom-0 w-0.5 rounded-full"
                  style={{ backgroundColor: lockInfo.color }}
                />
              )}
              {isLocked && (
                <div
                  className="absolute -top-4 left-0 text-[10px] font-medium px-1.5 py-0.5 rounded-t flex items-center gap-1 z-10"
                  style={{ color: lockInfo.color }}
                >
                  <span className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ backgroundColor: lockInfo.color }} />
                  {lockInfo.fullName} editing
                </div>
              )}

              {/* Block controls */}
              <div className="absolute -left-8 top-1 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col gap-0.5">
                <button onClick={() => moveBlock(block.id, -1)} className="text-slate-600 hover:text-slate-400 text-[10px]" title="Move up">▲</button>
                <button onClick={() => moveBlock(block.id, 1)} className="text-slate-600 hover:text-slate-400 text-[10px]" title="Move down">▼</button>
                <button onClick={() => removeBlock(block.id)} className="text-slate-600 hover:text-red-400 text-[10px]" title="Delete">✕</button>
              </div>

              {/* Block content */}
              <BlockRenderer
                block={block}
                onChange={(content) => updateBlock(block.id, content)}
                onSlash={(el) => handleSlashTrigger(block.id, el)}
                onFocus={() => handleBlockFocus(block.id)}
                onBlur={() => handleBlockBlur(block.id)}
                isLocked={isLocked}
                lockColor={lockInfo?.color}
                isActive={activeBlockId === block.id}
              />

              {/* Add block button */}
              <div className="relative h-0">
                <button
                  onClick={() => setShowBlockMenu(showBlockMenu === idx ? null : idx)}
                  className="absolute left-1/2 -translate-x-1/2 -bottom-2 w-5 h-5 rounded-full bg-white/5 border border-white/10 text-slate-500 hover:text-blue-400 hover:border-blue-500/30 text-[10px] opacity-0 group-hover:opacity-100 transition-all z-10 flex items-center justify-center"
                  title="Add block"
                >
                  +
                </button>
                {showBlockMenu === idx && (
                  <div className="absolute left-1/2 -translate-x-1/2 top-1 z-20 bg-slate-800 border border-white/10 rounded-lg p-1 flex gap-1 shadow-xl">
                    {BLOCK_TYPES.map((bt) => (
                      <button
                        key={bt.type}
                        onClick={() => addBlock(idx, bt.type)}
                        className="px-2 py-1.5 rounded text-[10px] text-slate-400 hover:bg-white/10 hover:text-white transition-colors whitespace-nowrap"
                        title={bt.label}
                      >
                        <span className="mr-1">{bt.icon}</span>{bt.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Slash menu */}
      {slash && (
        <SlashMenu
          position={slash.position}
          onSelect={handleSlashSelect}
          onClose={() => setSlash(null)}
        />
      )}

      {/* Hidden print area */}
      <div ref={printRef} id="print-area" className="hidden print:block" />
    </div>
  );
}

/* ── Helpers ─────────────────────────────── */
function esc(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/* ── Block Renderer ──────────────────────── */
function BlockRenderer({
  block,
  onChange,
  onSlash,
  onFocus,
  onBlur,
  isLocked,
  lockColor,
  isActive,
}: {
  block: Block;
  onChange: (content: string) => void;
  onSlash?: (el: HTMLElement) => void;
  onFocus?: () => void;
  onBlur?: () => void;
  isLocked?: boolean;
  lockColor?: string;
  isActive?: boolean;
}) {
  const handleInput = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const value = e.target.value;
    onChange(value);

    if (value.endsWith("/") && onSlash) {
      const charBefore = value.length >= 2 ? value[value.length - 2] : undefined;
      if (!charBefore || charBefore === " " || charBefore === "\n" || value === "/") {
        onSlash(e.target);
      }
    }
  };

  const commonProps = {
    onFocus,
    onBlur,
    readOnly: isLocked,
    style: isLocked ? { borderColor: lockColor, opacity: 0.7 } : isActive ? { borderColor: "#3b82f6" } : undefined,
  };

  switch (block.type) {
    case "heading":
      return (
        <input
          value={block.content}
          onChange={handleInput}
          placeholder="Heading..."
          className={cn(
            "w-full bg-transparent text-lg font-bold text-white border-none outline-none py-2 px-3 placeholder:text-slate-600",
            isLocked && "cursor-not-allowed"
          )}
          {...commonProps}
        />
      );
    case "divider":
      return <hr className="border-white/10 my-3" />;
    case "findings":
      return (
        <Card className={cn("bg-blue-500/5 border-blue-500/10", isLocked && "opacity-70")}>
          <CardContent className="pt-3 pb-2">
            <p className="text-[10px] text-blue-400 font-semibold uppercase mb-1">🔍 Findings</p>
            <Textarea
              value={block.content}
              onChange={handleInput}
              placeholder="Document examination findings..."
              className="bg-transparent border-none text-sm text-white resize-none min-h-[60px] p-0 placeholder:text-slate-600 focus-visible:ring-0"
              {...commonProps}
            />
          </CardContent>
        </Card>
      );
    case "plan":
      return (
        <Card className={cn("bg-emerald-500/5 border-emerald-500/10", isLocked && "opacity-70")}>
          <CardContent className="pt-3 pb-2">
            <p className="text-[10px] text-emerald-400 font-semibold uppercase mb-1">📋 Plan</p>
            <Textarea
              value={block.content}
              onChange={handleInput}
              placeholder="Treatment plan, follow-up..."
              className="bg-transparent border-none text-sm text-white resize-none min-h-[60px] p-0 placeholder:text-slate-600 focus-visible:ring-0"
              {...commonProps}
            />
          </CardContent>
        </Card>
      );
    case "callout":
      return (
        <Card className={cn("bg-amber-500/5 border-amber-500/10", isLocked && "opacity-70")}>
          <CardContent className="pt-3 pb-2">
            <p className="text-[10px] text-amber-400 font-semibold uppercase mb-1">💡 Callout</p>
            <Textarea
              value={block.content}
              onChange={handleInput}
              placeholder="Important note or highlight..."
              className="bg-transparent border-none text-sm text-white resize-none min-h-[60px] p-0 placeholder:text-slate-600 focus-visible:ring-0"
              {...commonProps}
            />
          </CardContent>
        </Card>
      );
    case "quote":
      return (
        <div className="border-l-3 border-slate-500 pl-4 py-1">
          <Textarea
            value={block.content}
            onChange={handleInput}
            placeholder="Quote text..."
            className={cn(
              "bg-transparent border-none text-sm text-white italic resize-none min-h-[36px] p-0 placeholder:text-slate-600 focus-visible:ring-0",
              isLocked && "cursor-not-allowed"
            )}
            {...commonProps}
          />
        </div>
      );
    case "list":
      return (
        <Textarea
          value={block.content}
          onChange={handleInput}
          placeholder={"• Item 1\n• Item 2\n• Item 3"}
          className={cn(
            "w-full bg-white/[0.02] border border-white/5 rounded-lg text-sm text-white resize-none min-h-[48px] px-3 py-2",
            "placeholder:text-slate-600 focus-visible:ring-1 focus-visible:ring-blue-500/30",
            isLocked && "cursor-not-allowed opacity-70"
          )}
          {...commonProps}
        />
      );
    default: // text
      return (
        <Textarea
          value={block.content}
          onChange={handleInput}
          placeholder="Write here… (type / for commands)"
          className={cn(
            "w-full bg-transparent border-none text-sm text-white resize-none min-h-[36px] px-3 py-2",
            "placeholder:text-slate-600 focus-visible:ring-0",
            isLocked && "cursor-not-allowed opacity-70"
          )}
          {...commonProps}
        />
      );
  }
}
