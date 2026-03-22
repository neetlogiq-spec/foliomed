"use client";

import { useRealtime } from "@/hooks/useRealtime";

/**
 * Drop this component into any page to get live updates when the specified
 * tables change. It auto-refreshes the page's server-fetched data.
 */
export function RealtimeProvider({
  tables,
  filter,
}: {
  tables: string[];
  filter?: string;
}) {
  return (
    <>
      {tables.map((table) => (
        <RealtimeListener key={table} table={table} filter={filter} />
      ))}
    </>
  );
}

function RealtimeListener({ table, filter }: { table: string; filter?: string }) {
  useRealtime({ table, filter });
  return null;
}
