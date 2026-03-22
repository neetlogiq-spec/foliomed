import { cn } from "@/lib/utils";
import type { Role } from "@/types/roles";

interface RoleBadgeProps {
  role: Role;
  size?: "sm" | "md";
}

const roleConfig: Record<Role, { label: string; className: string }> = {
  pg: {
    label: "PG",
    className:
      "bg-blue-500/15 text-blue-400 border-blue-500/20",
  },
  intern: {
    label: "Intern",
    className:
      "bg-emerald-500/15 text-emerald-400 border-emerald-500/20",
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
