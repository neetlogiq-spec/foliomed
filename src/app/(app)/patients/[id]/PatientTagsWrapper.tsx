"use client";

import { CaseTags } from "@/components/patients/CaseTags";
import { updatePatientTags } from "../actions";

export function PatientTagsWrapper({
  patientId,
  tags,
}: {
  patientId: string;
  tags: string[];
}) {
  return (
    <CaseTags
      patientId={patientId}
      currentTags={tags}
      onUpdate={updatePatientTags}
    />
  );
}
