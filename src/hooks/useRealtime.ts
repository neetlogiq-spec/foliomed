"use client";

import { useEffect, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

type RealtimeEvent = "INSERT" | "UPDATE" | "DELETE";

interface UseRealtimeOptions {
  table: string;
  schema?: string;
  filter?: string;
  event?: RealtimeEvent | "*";
  onPayload?: (payload: unknown) => void;
}

/**
 * Subscribe to Supabase Realtime changes on a table.
 * By default, it auto-refreshes the Next.js page (router.refresh()) on any change.
 * Pass `onPayload` to handle the event yourself instead.
 */
export function useRealtime({
  table,
  schema = "public",
  filter,
  event = "*",
  onPayload,
}: UseRealtimeOptions) {
  const router = useRouter();

  const handleChange = useCallback(
    (payload: unknown) => {
      if (onPayload) {
        onPayload(payload);
      } else {
        // Default: refresh the server component data
        router.refresh();
      }
    },
    [onPayload, router]
  );

  useEffect(() => {
    const supabase = createClient();

    const channelName = `realtime-${table}${filter ? `-${filter}` : ""}`;

    // Build the channel config
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const channelConfig: any = {
      event,
      schema,
      table,
    };
    if (filter) channelConfig.filter = filter;

    const channel = supabase
      .channel(channelName)
      .on("postgres_changes", channelConfig, handleChange)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [table, schema, filter, event, handleChange]);
}
