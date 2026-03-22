"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  patientFormSchema,
  type PatientFormValues,
} from "@/lib/validations/patient";
import { createPatient } from "../actions";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useState } from "react";

export function PatientForm() {
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<PatientFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(patientFormSchema) as any,
    defaultValues: {
      consent_for_teaching: false,
      visibility: "department",
      admission_date: new Date().toISOString().split("T")[0],
    },
  });

  const onSubmit = async (data: PatientFormValues) => {
    setServerError(null);
    const result = await createPatient(data);
    if (result?.error) {
      setServerError(result.error);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      {serverError && (
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3 text-red-300 text-sm">
          {serverError}
        </div>
      )}

      {/* Demographics */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-4">
          <CardTitle className="text-base text-white flex items-center gap-2">
            <svg className="w-5 h-5 text-blue-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
            </svg>
            Patient Demographics
          </CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="mrd_number" className="text-slate-300">
              MRD Number <span className="text-red-400">*</span>
            </Label>
            <Input
              id="mrd_number"
              placeholder="e.g. MRD-2026-001"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("mrd_number")}
            />
            {errors.mrd_number && (
              <p className="text-xs text-red-400">{errors.mrd_number.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="ip_number" className="text-slate-300">IP Number</Label>
            <Input
              id="ip_number"
              placeholder="IP number"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("ip_number")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="first_name" className="text-slate-300">
              First Name <span className="text-red-400">*</span>
            </Label>
            <Input
              id="first_name"
              placeholder="First name"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("first_name")}
            />
            {errors.first_name && (
              <p className="text-xs text-red-400">{errors.first_name.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="last_name" className="text-slate-300">Last Name</Label>
            <Input
              id="last_name"
              placeholder="Last name"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("last_name")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="date_of_birth" className="text-slate-300">Date of Birth</Label>
            <Input
              id="date_of_birth"
              type="date"
              className="bg-white/5 border-white/10 text-white"
              {...register("date_of_birth")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="sex" className="text-slate-300">Sex</Label>
            <select
              id="sex"
              className="w-full rounded-md border border-white/10 bg-white/5 px-3 py-2 text-sm text-white"
              {...register("sex")}
            >
              <option value="" className="bg-slate-900">Select sex</option>
              <option value="male" className="bg-slate-900">Male</option>
              <option value="female" className="bg-slate-900">Female</option>
              <option value="other" className="bg-slate-900">Other</option>
            </select>
          </div>
        </CardContent>
      </Card>

      {/* Anthropometry */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-4">
          <CardTitle className="text-base text-white flex items-center gap-2">
            <svg className="w-5 h-5 text-teal-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />
            </svg>
            Anthropometry & Vitals
          </CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="weight_kg" className="text-slate-300">Weight (kg)</Label>
            <Input
              id="weight_kg"
              type="number"
              step="0.01"
              placeholder="e.g. 3.5"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("weight_kg")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="height_cm" className="text-slate-300">Height (cm)</Label>
            <Input
              id="height_cm"
              type="number"
              step="0.1"
              placeholder="e.g. 50"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("height_cm")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="head_circumference" className="text-slate-300">Head Circumference (cm)</Label>
            <Input
              id="head_circumference"
              type="number"
              step="0.1"
              placeholder="e.g. 34"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("head_circumference")}
            />
          </div>
        </CardContent>
      </Card>

      {/* Neonatal */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-4">
          <CardTitle className="text-base text-white flex items-center gap-2">
            <svg className="w-5 h-5 text-purple-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
            </svg>
            Neonatal Information
          </CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="space-y-2">
            <Label htmlFor="gestational_age_weeks" className="text-slate-300">Gestational Age (weeks)</Label>
            <Input
              id="gestational_age_weeks"
              type="number"
              placeholder="e.g. 38"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("gestational_age_weeks")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="birth_weight_kg" className="text-slate-300">Birth Weight (kg)</Label>
            <Input
              id="birth_weight_kg"
              type="number"
              step="0.01"
              placeholder="e.g. 2.8"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("birth_weight_kg")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="apgar_1min" className="text-slate-300">APGAR 1 min</Label>
            <Input
              id="apgar_1min"
              type="number"
              min={0}
              max={10}
              placeholder="0-10"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("apgar_1min")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="apgar_5min" className="text-slate-300">APGAR 5 min</Label>
            <Input
              id="apgar_5min"
              type="number"
              min={0}
              max={10}
              placeholder="0-10"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("apgar_5min")}
            />
          </div>
        </CardContent>
      </Card>

      {/* Guardian & Contact */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-4">
          <CardTitle className="text-base text-white flex items-center gap-2">
            <svg className="w-5 h-5 text-amber-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 0 0 2.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 0 1-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 0 0-1.091-.852H4.5A2.25 2.25 0 0 0 2.25 4.5v2.25Z" />
            </svg>
            Guardian & Contact
          </CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="mother_name" className="text-slate-300">Mother&apos;s Name</Label>
            <Input
              id="mother_name"
              placeholder="Mother's name"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("mother_name")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="father_name" className="text-slate-300">Father&apos;s Name</Label>
            <Input
              id="father_name"
              placeholder="Father's name"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("father_name")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="guardian_contact" className="text-slate-300">Contact Number</Label>
            <Input
              id="guardian_contact"
              placeholder="Phone number"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("guardian_contact")}
            />
          </div>

          <div className="space-y-2 md:col-span-2 lg:col-span-3">
            <Label htmlFor="address" className="text-slate-300">Address</Label>
            <Textarea
              id="address"
              placeholder="Full address"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500 min-h-[60px]"
              {...register("address")}
            />
          </div>
        </CardContent>
      </Card>

      {/* Admission */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-4">
          <CardTitle className="text-base text-white flex items-center gap-2">
            <svg className="w-5 h-5 text-emerald-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 21v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21m0 0h4.5V3.545M12.75 21h7.5V10.75M2.25 21h1.5m18 0h-18M2.25 9l4.5-1.636M18.75 3l-1.5.545m0 6.205 3 1m1.5.5-1.5-.5M6.75 7.364V3h-3v18m3-13.636 10.5-3.819" />
            </svg>
            Admission Details
          </CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="space-y-2">
            <Label htmlFor="ward" className="text-slate-300">Ward</Label>
            <Input
              id="ward"
              placeholder="e.g. NICU, Pediatric Ward"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("ward")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="bed_number" className="text-slate-300">Bed Number</Label>
            <Input
              id="bed_number"
              placeholder="e.g. B-12"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("bed_number")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="unit" className="text-slate-300">Unit</Label>
            <Input
              id="unit"
              placeholder="e.g. Unit 1"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("unit")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="admission_date" className="text-slate-300">Admission Date</Label>
            <Input
              id="admission_date"
              type="date"
              className="bg-white/5 border-white/10 text-white"
              {...register("admission_date")}
            />
          </div>

          <div className="space-y-2 md:col-span-2">
            <Label htmlFor="diagnosis" className="text-slate-300">Diagnosis</Label>
            <Input
              id="diagnosis"
              placeholder="e.g. Pneumonia, Sepsis, Febrile seizures"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("diagnosis")}
            />
          </div>

          <div className="flex items-center gap-2 pt-6">
            <input
              type="checkbox"
              id="is_stable"
              defaultChecked
              className="rounded border-white/20 bg-white/5 text-emerald-500"
              {...register("is_stable")}
            />
            <Label htmlFor="is_stable" className="text-slate-300 text-sm cursor-pointer">
              Patient is stable
            </Label>
          </div>

          <div className="space-y-2">
            <Label htmlFor="immunization_status" className="text-slate-300">Immunization Status</Label>
            <Input
              id="immunization_status"
              placeholder="e.g. Up to date"
              className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
              {...register("immunization_status")}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="visibility" className="text-slate-300">Visibility</Label>
            <select
              id="visibility"
              className="w-full rounded-md border border-white/10 bg-white/5 px-3 py-2 text-sm text-white"
              {...register("visibility")}
            >
              <option value="department" className="bg-slate-900">Department (shared)</option>
              <option value="private" className="bg-slate-900">Private</option>
            </select>
          </div>

          <div className="flex items-center gap-2 pt-6">
            <input
              type="checkbox"
              id="consent_for_teaching"
              className="rounded border-white/20 bg-white/5 text-blue-500"
              {...register("consent_for_teaching")}
            />
            <Label htmlFor="consent_for_teaching" className="text-slate-300 text-sm cursor-pointer">
              Teaching consent obtained
            </Label>
          </div>
        </CardContent>
      </Card>

      {/* Submit */}
      <div className="flex justify-end gap-3">
        <Button
          type="button"
          variant="outline"
          className="border-white/10 text-slate-300 hover:bg-white/5"
          onClick={() => window.history.back()}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          disabled={isSubmitting}
          className="bg-blue-600 hover:bg-blue-700 text-white"
        >
          {isSubmitting ? (
            <>
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2" />
              Saving...
            </>
          ) : (
            "Admit Patient"
          )}
        </Button>
      </div>
    </form>
  );
}
