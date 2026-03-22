"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { createDocument } from "../../documents/actions";

export function CreateDocumentButton({ patientId }: { patientId: string }) {
  const [isPending, startTransition] = useTransition();
  const router = useRouter();

  const handleCreate = () => {
    startTransition(async () => {
      const result = await createDocument(patientId, "Case Document");
      if (result?.id) {
        router.push(`/documents/${result.id}`);
      }
    });
  };

  return (
    <Button
      onClick={handleCreate}
      disabled={isPending}
      size="sm"
      variant="outline"
      className="border-white/10 text-slate-300 hover:bg-white/5 text-xs"
    >
      {isPending ? "Creating..." : "📄 New Case Doc"}
    </Button>
  );
}
