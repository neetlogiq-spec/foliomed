import { PatientForm } from "./PatientForm";
import Link from "next/link";

export default function NewPatientPage() {
  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <Link
          href="/patients"
          className="text-sm text-slate-400 hover:text-slate-200 inline-flex items-center gap-1 mb-2"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
          </svg>
          Back to patients
        </Link>
        <h1 className="text-2xl font-bold text-white">New Patient Admission</h1>
        <p className="text-sm text-slate-400 mt-1">
          Fill in the patient details below. Only MRD number and first name are required.
        </p>
      </div>
      <PatientForm />
    </div>
  );
}
