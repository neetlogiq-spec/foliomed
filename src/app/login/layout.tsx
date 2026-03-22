import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Sign In — PG PMS",
  description: "Sign in to PG PMS with your Google account",
};

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
