"use client";

import { useEffect } from "react";
import { cachePatientList, cachePatientDetail, cacheProgressNotes, cacheVitals } from "@/lib/offline/db";
import type { Patient, PatientListRow } from "@/types/patient";
import type { ProgressNote, Vital } from "@/types/clinical";

// ─── Cache patient list on render ─────────────────────────────
export function CachePatientList({ patients }: { patients: PatientListRow[] }) {
  useEffect(() => {
    if (patients?.length > 0) {
      cachePatientList(patients);
    }
  }, [patients]);

  return null; // Renders nothing, just caches
}

// ─── Cache patient detail on render ───────────────────────────
export function CachePatientDetail({ id, data }: { id: string; data: Patient }) {
  useEffect(() => {
    if (id && data) {
      cachePatientDetail(id, data);
    }
  }, [id, data]);

  return null;
}

// ─── Cache progress notes on render ───────────────────────────
export function CacheProgressNotes({ patientId, notes }: { patientId: string; notes: ProgressNote[] }) {
  useEffect(() => {
    if (patientId && notes) {
      cacheProgressNotes(patientId, notes);
    }
  }, [patientId, notes]);

  return null;
}

// ─── Cache vitals on render ───────────────────────────────────
export function CacheVitals({ patientId, vitals }: { patientId: string; vitals: Vital[] }) {
  useEffect(() => {
    if (patientId && vitals) {
      cacheVitals(patientId, vitals);
    }
  }, [patientId, vitals]);

  return null;
}
