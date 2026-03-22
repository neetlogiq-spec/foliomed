"use client";

import { get, set, del, keys } from "idb-keyval";

// ─── Cache Keys ───────────────────────────────────────────────
const KEYS = {
  PATIENTS_LIST: "offline:patients",
  PATIENT_DETAIL: (id: string) => `offline:patient:${id}`,
  PROGRESS_NOTES: (id: string) => `offline:notes:${id}`,
  VITALS: (id: string) => `offline:vitals:${id}`,
  MUTATION_QUEUE: "offline:mutation-queue",
  LAST_SYNC: "offline:last-sync",
};

interface CachedData<T> {
  data: T;
  timestamp: number;
}

// ─── Generic Cache Helpers ────────────────────────────────────
export async function cacheSet<T>(key: string, data: T): Promise<void> {
  const entry: CachedData<T> = { data, timestamp: Date.now() };
  await set(key, entry);
}

export async function cacheGet<T>(key: string, maxAgeMs = 30 * 60 * 1000): Promise<T | null> {
  const entry = await get<CachedData<T>>(key);
  if (!entry) return null;
  // If maxAgeMs is 0, skip freshness check (always return cached)
  if (maxAgeMs > 0 && Date.now() - entry.timestamp > maxAgeMs) return null;
  return entry.data;
}

export async function cacheDel(key: string): Promise<void> {
  await del(key);
}

// ─── Patient List ─────────────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cachePatientList(patients: any[]): Promise<void> {
  await cacheSet(KEYS.PATIENTS_LIST, patients);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedPatientList(): Promise<any[] | null> {
  // Allow stale data up to 24 hours when offline
  return cacheGet(KEYS.PATIENTS_LIST, 0);
}

// ─── Patient Detail ───────────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cachePatientDetail(id: string, data: any): Promise<void> {
  await cacheSet(KEYS.PATIENT_DETAIL(id), data);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedPatientDetail(id: string): Promise<any | null> {
  return cacheGet(KEYS.PATIENT_DETAIL(id), 0);
}

// ─── Progress Notes ───────────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cacheProgressNotes(patientId: string, notes: any[]): Promise<void> {
  await cacheSet(KEYS.PROGRESS_NOTES(patientId), notes);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedProgressNotes(patientId: string): Promise<any[] | null> {
  return cacheGet(KEYS.PROGRESS_NOTES(patientId), 0);
}

// ─── Vitals ───────────────────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cacheVitals(patientId: string, vitals: any[]): Promise<void> {
  await cacheSet(KEYS.VITALS(patientId), vitals);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedVitals(patientId: string): Promise<any[] | null> {
  return cacheGet(KEYS.VITALS(patientId), 0);
}

// ─── Mutation Queue ───────────────────────────────────────────
export interface QueuedMutation {
  id: string;
  action: string;        // e.g. "addProgressNote", "addVitals"
  payload: Record<string, unknown>;
  timestamp: number;
  status: "pending" | "syncing" | "failed";
}

export async function getQueue(): Promise<QueuedMutation[]> {
  return (await get<QueuedMutation[]>(KEYS.MUTATION_QUEUE)) || [];
}

export async function enqueue(action: string, payload: Record<string, unknown>): Promise<void> {
  const queue = await getQueue();
  queue.push({
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    action,
    payload,
    timestamp: Date.now(),
    status: "pending",
  });
  await set(KEYS.MUTATION_QUEUE, queue);
}

export async function dequeue(id: string): Promise<void> {
  const queue = await getQueue();
  await set(KEYS.MUTATION_QUEUE, queue.filter((m) => m.id !== id));
}

export async function clearQueue(): Promise<void> {
  await del(KEYS.MUTATION_QUEUE);
}

export async function getPendingCount(): Promise<number> {
  const queue = await getQueue();
  return queue.filter((m) => m.status === "pending").length;
}

// ─── Clear All Cache ──────────────────────────────────────────
export async function clearAllCache(): Promise<void> {
  const allKeys = await keys();
  for (const key of allKeys) {
    if (typeof key === "string" && key.startsWith("offline:")) {
      await del(key);
    }
  }
}
