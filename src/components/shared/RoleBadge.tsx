import { cn } from "@/lib/utils";
import type { Role } from "@/types/roles";

interface RoleBadgeProps {
  role: Role;
  size?: "sm" | "md";
}

const roleConfig: Record<Role, { label: string; className: string }> = {
  pg: {
    label: "PG",
    className: "bg-blue-500/15 text-blue-400 border-blue-500/20",
  },
  intern: {
    label: "Intern",
    className: "bg-emerald-500/15 text-emerald-400 border-emerald-500/20",
  },
  admin: {
    label: "Admin",
    className: "bg-red-500/15 text-red-400 border-red-500/20",
  },
  hod: {
    label: "HOD",
    className: "bg-purple-500/15 text-purple-400 border-purple-500/20",
  },
  senior_consultant: {
    label: "Sr. Consultant",
    className: "bg-amber-500/15 text-amber-400 border-amber-500/20",
  },
  consultant: {
    label: "Consultant",
    className: "bg-orange-500/15 text-orange-400 border-orange-500/20",
  },
  senior_pg: {
    label: "Senior PG",
    className: "bg-cyan-500/15 text-cyan-400 border-cyan-500/20",
  },
  nurse: {
    label: "Nurse",
    className: "bg-pink-500/15 text-pink-400 border-pink-500/20",
  },
};

export function RoleBadge({ role, size = "md" }: RoleBadgeProps) {
  const config = roleConfig[role] ?? roleConfig.pg;

  return (
    <span
      className={cn(
        "inline-flex items-center font-medium border rounded-full",
        config.className,
        size === "sm" ? "px-1.5 py-0.5 text-[10px]" : "px-2 py-0.5 text-xs"
      )}
    >
      {config.label}
    </span>
  );
}
