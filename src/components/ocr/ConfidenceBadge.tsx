interface ConfidenceBadgeProps {
  level: string | undefined;
  className?: string;
}

const COLORS: Record<string, string> = {
  high: "bg-emerald-500",
  medium: "bg-amber-400",
  low: "bg-red-500",
};

const LABELS: Record<string, string> = {
  high: "High confidence",
  medium: "Medium confidence",
  low: "Low confidence — verify manually",
};

export function ConfidenceBadge({ level, className }: ConfidenceBadgeProps) {
  if (!level) return null;
  const color = COLORS[level] ?? "bg-slate-500";
  const label = LABELS[level] ?? level;

  return (
    <span
      title={label}
      aria-label={label}
      className={`inline-block w-2 h-2 rounded-full flex-shrink-0 ${color} ${className ?? ""}`}
    />
  );
}
