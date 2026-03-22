"use client";

import { useState, useTransition } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { updateProfile } from "./actions";
import { BRANCHES } from "@/types/roles";
import type { Profile } from "@/types/roles";

interface SettingsClientProps {
  profile: Profile;
}

export function SettingsClient({ profile }: SettingsClientProps) {
  const [isPending, startTransition] = useTransition();
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    setSuccess(false);
    const fd = new FormData(e.currentTarget);

    startTransition(async () => {
      const result = await updateProfile({
        full_name: (fd.get("full_name") as string) || undefined,
        branch: (fd.get("branch") as string) || undefined,
        year_of_pg: fd.get("year_of_pg") ? Number(fd.get("year_of_pg")) : undefined,
      });
      if (result?.error) setError(result.error);
      else setSuccess(true);
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Profile Info (read-only) */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm text-white">Profile</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-1">
            <Label className="text-xs text-slate-400">Display Name *</Label>
            <Input
              name="full_name"
              defaultValue={profile.full_name}
              placeholder="Your full name"
              className="bg-white/5 border-white/10 text-white text-sm max-w-sm"
            />
          </div>
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-xs text-slate-500">Email</dt>
              <dd className="text-white">{profile.email}</dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Role</dt>
              <dd className="text-white capitalize">{profile.role}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      {/* Editable fields */}
      <Card className="bg-white/5 border-white/10">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm text-white">Branch & Year</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {error && <p className="text-xs text-red-400">{error}</p>}
          {success && <p className="text-xs text-emerald-400">✓ Profile updated</p>}

          <div className="space-y-1">
            <Label className="text-xs text-slate-400">Branch / Specialty *</Label>
            <select
              name="branch"
              defaultValue={profile.branch || ""}
              className="w-full rounded-md border border-white/10 bg-white/5 px-3 py-2 text-sm text-white"
            >
              <option value="" className="bg-slate-900">Select your branch</option>
              {BRANCHES.map((b) => (
                <option key={b} value={b} className="bg-slate-900">{b}</option>
              ))}
            </select>
          </div>

          <div className="space-y-1">
            <Label className="text-xs text-slate-400">Year of PG</Label>
            <Input
              name="year_of_pg"
              type="number"
              min={1}
              max={5}
              defaultValue={profile.year_of_pg ?? ""}
              placeholder="e.g. 1, 2, 3"
              className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 max-w-[200px]"
            />
          </div>

          <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700 text-white">
            {isPending ? "Saving..." : "Save Changes"}
          </Button>
        </CardContent>
      </Card>
    </form>
  );
}
