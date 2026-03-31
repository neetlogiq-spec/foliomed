import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import Link from "next/link";
import { StatusBadge } from "@/components/patients/StatusBadge";
import { StatusTransition } from "./StatusTransition";
import { CreateDocumentButton } from "./CreateDocumentButton";
import { PatientTagsWrapper } from "./PatientTagsWrapper";
import { ClinicalTabs } from "./ClinicalTabs";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { RealtimeProvider } from "@/components/shared/RealtimeProvider";
import { ErrorBoundary } from "@/components/shared/ErrorBoundary";
import type { PatientStatus } from "@/types/patient";

function InfoItem({
  label,
  value,
}: {
  label: string;
  value: string | number | null | undefined;
}) {
  if (value === null || value === undefined || value === "") return null;
  return (
    <div>
      <dt className="text-xs text-slate-500 mb-0.5">{label}</dt>
      <dd className="text-sm text-white">{String(value)}</dd>
    </div>
  );
}

export default async function PatientDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  // Fetch patient + clinical data in parallel
  const [patientRes, vitalsRes, investigationsRes, medicationsRes, notesRes, imagesRes, docsRes] =
    await Promise.all([
      supabase
        .from("patients")
        .select(
          `*, profiles:primary_pg_id ( full_name, email ), creator:created_by ( full_name )`
        )
        .eq("id", id)
        .single(),
      supabase
        .from("vitals")
        .select("*")
        .eq("patient_id", id)
        .order("recorded_at", { ascending: false }),
      supabase
        .from("investigations")
        .select("*")
        .eq("patient_id", id)
        .order("created_at", { ascending: false }),
      supabase
        .from("medications")
        .select("*")
        .eq("patient_id", id)
        .order("created_at", { ascending: false }),
      supabase
        .from("progress_notes")
        .select("*")
        .eq("patient_id", id)
        .order("note_date", { ascending: false }),
      supabase
        .from("patient_images")
        .select("*")
        .eq("patient_id", id)
        .order("created_at", { ascending: false }),
      supabase
        .from("case_documents")
        .select("id, title, is_draft, version, updated_at")
        .eq("patient_id", id)
        .order("updated_at", { ascending: false }),
    ]);

  if (patientRes.error || !patientRes.data) {
    notFound();
  }

  const patient = patientRes.data;
  const fullName = `${patient.first_name} ${patient.last_name || ""}`.trim();

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <Link
          href="/patients"
          className="text-sm text-slate-400 hover:text-slate-200 inline-flex items-center gap-1 mb-3"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
          </svg>
          All Patients
        </Link>

        <RealtimeProvider
          tables={["vitals", "progress_notes", "medications", "investigations", "patient_images"]}
          filter={`patient_id=eq.${patient.id}`}
        />

        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <h1 className="text-2xl font-bold text-white">{fullName}</h1>
              <StatusBadge status={patient.status as PatientStatus} />
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-slate-400">
              <span>IP: {patient.ip_number}</span>
              {patient.sex && <span className="capitalize">{patient.sex}</span>}
              {patient.ward && (
                <span>{patient.ward}{patient.bed_number ? ` / Bed ${patient.bed_number}` : ""}</span>
              )}
            </div>
            <PatientTagsWrapper patientId={patient.id} tags={patient.tags || []} />
          </div>
          <div className="flex gap-2 items-start">
            <CreateDocumentButton patientId={patient.id} />
            <StatusTransition
              patientId={patient.id}
              currentStatus={patient.status as PatientStatus}
              patientName={fullName}
            />
          </div>
        </div>
      </div>

      <Separator className="bg-white/10 mb-6" />

      {/* Patient Info Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-8">
        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-xs text-slate-500 uppercase tracking-wider">Demographics</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
              <InfoItem label="Date of Birth" value={patient.date_of_birth} />
              <InfoItem label="Sex" value={patient.sex} />
              <InfoItem label="Weight" value={patient.weight_kg ? `${patient.weight_kg} kg` : null} />
              <InfoItem label="Height" value={patient.height_cm ? `${patient.height_cm} cm` : null} />
              <InfoItem label="Head Circ." value={patient.head_circumference ? `${patient.head_circumference} cm` : null} />
              <InfoItem label="Immunization" value={patient.immunization_status} />
            </dl>
          </CardContent>
        </Card>

        <Card className="bg-white/5 border-white/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-xs text-slate-500 uppercase tracking-wider">Admission & Guardian</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
              <InfoItem label="Ward" value={patient.ward} />
              <InfoItem label="Bed" value={patient.bed_number} />
              <InfoItem label="Admitted" value={patient.admission_date
                ? new Date(patient.admission_date).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : null} />
              <InfoItem label="PG" value={(patient.profiles as { full_name: string } | null)?.full_name ?? null} />
              <InfoItem label="Mother" value={patient.mother_name} />
              <InfoItem label="Father" value={patient.father_name} />
              <InfoItem label="Contact" value={patient.guardian_contact} />
              <InfoItem label="Consent" value={patient.consent_for_teaching ? "Yes" : "No"} />
            </dl>
          </CardContent>
        </Card>
      </div>

      {/* Clinical Tabs */}
      <ErrorBoundary>
        <ClinicalTabs
          patientId={patient.id}
          vitals={vitalsRes.data ?? []}
          investigations={investigationsRes.data ?? []}
          medications={medicationsRes.data ?? []}
          progressNotes={notesRes.data ?? []}
          images={imagesRes.data ?? []}
          documents={docsRes.data ?? []}
        />
      </ErrorBoundary>
    </div>
  );
}
