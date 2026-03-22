"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import type { PatientStatus } from "@/types/patient";
import { STATUS_TRANSITIONS, PATIENT_STATUS_CONFIG } from "@/types/patient";
import { updatePatientStatus } from "../actions";

interface StatusTransitionProps {
  patientId: string;
  currentStatus: PatientStatus;
  patientName: string;
}

export function StatusTransition({
  patientId,
  currentStatus,
  patientName,
}: StatusTransitionProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<PatientStatus | null>(
    null
  );
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const transitions = STATUS_TRANSITIONS[currentStatus];
  if (!transitions || transitions.length === 0) return null;

  const handleConfirm = () => {
    if (!selectedStatus) return;
    setError(null);
    startTransition(async () => {
      const result = await updatePatientStatus(patientId, selectedStatus);
      if (result?.error) {
        setError(result.error);
      } else {
        setIsOpen(false);
        setSelectedStatus(null);
      }
    });
  };

  return (
    <>
      <div className="flex gap-2 flex-wrap">
        {transitions.map((status) => {
          const config = PATIENT_STATUS_CONFIG[status];
          const isDangerous = status === "expired" || status === "lama";
          return (
            <Button
              key={status}
              variant="outline"
              size="sm"
              className={
                isDangerous
                  ? "border-red-500/30 text-red-400 hover:bg-red-500/10"
                  : "border-white/10 text-slate-300 hover:bg-white/5"
              }
              onClick={() => {
                setSelectedStatus(status);
                setIsOpen(true);
              }}
            >
              {config.label}
            </Button>
          );
        })}
      </div>

      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="bg-slate-900 border-white/10 text-white">
          <DialogHeader>
            <DialogTitle>Change Patient Status</DialogTitle>
            <DialogDescription className="text-slate-400">
              Are you sure you want to change{" "}
              <span className="text-white font-medium">{patientName}</span>
              &apos;s status to{" "}
              <span className="text-white font-medium">
                {selectedStatus
                  ? PATIENT_STATUS_CONFIG[selectedStatus].label
                  : ""}
              </span>
              ?
              {selectedStatus === "discharged" &&
                " The discharge date will be set to today."}
              {selectedStatus === "expired" &&
                " This action signifies the patient has expired."}
            </DialogDescription>
          </DialogHeader>
          {error && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3 text-red-300 text-sm">
              {error}
            </div>
          )}
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsOpen(false)}
              className="border-white/10 text-slate-300"
            >
              Cancel
            </Button>
            <Button
              onClick={handleConfirm}
              disabled={isPending}
              className={
                selectedStatus === "expired" || selectedStatus === "lama"
                  ? "bg-red-600 hover:bg-red-700"
                  : "bg-blue-600 hover:bg-blue-700"
              }
            >
              {isPending ? "Updating..." : "Confirm"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
