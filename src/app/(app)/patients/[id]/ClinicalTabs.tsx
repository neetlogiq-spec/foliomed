"use client";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { VitalsPanel } from "./VitalsPanel";
import { InvestigationsPanel } from "./InvestigationsPanel";
import { MedicationsPanel } from "./MedicationsPanel";
import { ProgressNotesPanel } from "./ProgressNotesPanel";
import { ImagesPanel } from "./ImagesPanel";
import { PatientDocumentsTab } from "./PatientDocumentsTab";
import type { Vital, Investigation, Medication, ProgressNote } from "@/types/clinical";

interface PatientImage {
  id: string;
  file_path: string;
  file_name: string;
  file_size: number | null;
  mime_type: string | null;
  caption: string | null;
  category: string | null;
  created_at: string;
}

interface CaseDoc {
  id: string;
  title: string;
  is_draft: boolean;
  version: number;
  updated_at: string;
}

interface ClinicalTabsProps {
  patientId: string;
  vitals: Vital[];
  investigations: Investigation[];
  medications: Medication[];
  progressNotes: ProgressNote[];
  images: PatientImage[];
  documents: CaseDoc[];
}

export function ClinicalTabs({
  patientId,
  vitals,
  investigations,
  medications,
  progressNotes,
  images,
  documents,
}: ClinicalTabsProps) {
  return (
    <Tabs defaultValue="vitals" className="w-full">
      <TabsList className="bg-white/5 border border-white/10 p-1 mb-4 w-full justify-start">
        <TabsTrigger value="vitals" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          Vitals ({vitals.length})
        </TabsTrigger>
        <TabsTrigger value="investigations" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          Investigations ({investigations.length})
        </TabsTrigger>
        <TabsTrigger value="medications" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          Medications ({medications.length})
        </TabsTrigger>
        <TabsTrigger value="notes" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          Notes ({progressNotes.length})
        </TabsTrigger>
        <TabsTrigger value="images" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          📷 Images ({images.length})
        </TabsTrigger>
        <TabsTrigger value="documents" className="data-[state=active]:bg-white/10 data-[state=active]:text-white text-slate-400 text-xs">
          📄 Docs ({documents.length})
        </TabsTrigger>
      </TabsList>

      <TabsContent value="vitals">
        <VitalsPanel patientId={patientId} vitals={vitals} />
      </TabsContent>
      <TabsContent value="investigations">
        <InvestigationsPanel patientId={patientId} investigations={investigations} />
      </TabsContent>
      <TabsContent value="medications">
        <MedicationsPanel patientId={patientId} medications={medications} />
      </TabsContent>
      <TabsContent value="notes">
        <ProgressNotesPanel patientId={patientId} notes={progressNotes} />
      </TabsContent>
      <TabsContent value="images">
        <ImagesPanel patientId={patientId} images={images} />
      </TabsContent>
      <TabsContent value="documents">
        <PatientDocumentsTab patientId={patientId} documents={documents} />
      </TabsContent>
    </Tabs>
  );
}
