"use client";

import { cn } from "@/lib/utils";
import type { PatientStatus } from "@/types/patient";
import { PATIENT_STATUS_CONFIG } from "@/types/patient";

interface StatusBadgeProps {
  status: PatientStatus;
  size?: "sm" | "md";
}

export function StatusBadge({ status, size = "md" }: StatusBadgeProps) {
  const config = PATIENT_STATUS_CONFIG[status];

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 font-medium border rounded-full",
        config.color,
        size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-xs"
      )}
    >
      <span className={cn("w-1.5 h-1.5 rounded-full", config.dotColor)} />
      {config.label}
    </span>
  );
}
