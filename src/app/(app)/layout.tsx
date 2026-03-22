import type { Metadata } from "next";
import AppShell from "@/components/shared/AppShell";

export const metadata: Metadata = {
  title: "PG PMS",
  description: "Patient Management for Pediatric PG Residents",
};

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
