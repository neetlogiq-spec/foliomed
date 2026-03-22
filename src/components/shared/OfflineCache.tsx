"use client";

import { useEffect } from "react";
import { cachePatientList, cachePatientDetail, cacheProgressNotes, cacheVitals } from "@/lib/offline/db";

// ─── Cache patient list on render ─────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function CachePatientList({ patients }: { patients: any[] }) {
  useEffect(() => {
    if (patients?.length > 0) {
      cachePatientList(patients);
    }
  }, [patients]);

  return null; // Renders nothing, just caches
}

// ─── Cache patient detail on render ───────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function CachePatientDetail({ id, data }: { id: string; data: any }) {
  useEffect(() => {
    if (id && data) {
      cachePatientDetail(id, data);
    }
  }, [id, data]);

  return null;
}

// ─── Cache progress notes on render ───────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function CacheProgressNotes({ patientId, notes }: { patientId: string; notes: any[] }) {
  useEffect(() => {
    if (patientId && notes) {
      cacheProgressNotes(patientId, notes);
    }
  }, [patientId, notes]);

  return null;
}

// ─── Cache vitals on render ───────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function CacheVitals({ patientId, vitals }: { patientId: string; vitals: any[] }) {
  useEffect(() => {
    if (patientId && vitals) {
      cacheVitals(patientId, vitals);
    }
  }, [patientId, vitals]);

  return null;
}
