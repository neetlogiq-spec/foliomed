import { createClient } from "@/lib/supabase/server";
import { PatientListClient } from "./PatientListClient";
import { CachePatientList } from "@/components/shared/OfflineCache";
import Link from "next/link";

export default async function PatientsPage() {
  const supabase = await createClient();

  const { data: patients, error } = await supabase
    .from("patients")
    .select(
      `
      id,
      ip_number,
      first_name,
      last_name,
      sex,
      date_of_birth,
      age_days,
      ward,
      bed_number,
      unit,
      status,
      admission_date,
      primary_pg_id,
      created_at,
      is_stable,
      diagnosis,
      tags,
      profiles:primary_pg_id ( full_name )
    `
    )
    .order("created_at", { ascending: false });

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 text-red-300">
          Failed to load patients: {error.message}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white">Patients</h1>
          <p className="text-sm text-slate-400 mt-1">
            {patients?.length ?? 0} patient{(patients?.length ?? 0) !== 1 ? "s" : ""} in your view
          </p>
        </div>
        <Link
          href="/patients/new"
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          New Admission
        </Link>
      </div>
      <CachePatientList patients={patients ?? []} />
      <PatientListClient patients={patients ?? []} />
    </div>
  );
}

