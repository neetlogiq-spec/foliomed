// push-dispatch — sends queued FolioMed alerts (push_outbox) through
// Firebase Cloud Messaging to every device of every member of the ward.
//
// Invoked every minute by pg_cron and instantly by the notes trigger
// (see docs/PUSH_SETUP.md). Authenticated by the shared DISPATCH_SECRET
// header, not a user JWT — deploy with `--no-verify-jwt`.
//
// Secrets (supabase secrets set …):
//   DISPATCH_SECRET        random string, also stored in app_settings
//   FCM_SERVICE_ACCOUNT    the Firebase service-account JSON (one line)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from "jsr:@supabase/supabase-js@2";

type OutboxRow = {
  id: number;
  ward_id: string;
  exclude_user: string | null;
  only_user: string | null; // set → just this ward member (job assignments)
  title: string;
  body: string;
  data: Record<string, unknown>;
  high_priority: boolean;
  channel: string;
  attempts: number;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const MAX_ATTEMPTS = 5;
const BATCH = 100;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

Deno.serve(async (req) => {
  const secret = Deno.env.get("DISPATCH_SECRET");
  if (!secret || req.headers.get("x-dispatch-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const result = await dispatch();
    return Response.json(result);
  } catch (e) {
    console.error("dispatch failed", e);
    return Response.json({ error: String(e) }, { status: 500 });
  }
});

async function dispatch() {
  const { data: rows, error } = await supabase
    .from("push_outbox")
    .select("*")
    .is("sent_at", null)
    .lt("attempts", MAX_ATTEMPTS)
    .order("id", { ascending: true })
    .limit(BATCH);
  if (error) throw error;
  if (!rows?.length) return { sent: 0 };

  const account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}") as ServiceAccount;
  if (!account.private_key) throw new Error("FCM_SERVICE_ACCOUNT is not set");
  const accessToken = await googleAccessToken(account);

  let sent = 0;
  for (const row of rows as OutboxRow[]) {
    try {
      const tokens = await tokensForWard(row.ward_id, row.exclude_user, row.only_user);
      for (const token of tokens) {
        await sendOne(account.project_id, accessToken, token, row);
      }
      await supabase.from("push_outbox")
        .update({ sent_at: new Date().toISOString(), attempts: row.attempts + 1, last_error: null })
        .eq("id", row.id);
      sent++;
    } catch (e) {
      await supabase.from("push_outbox")
        .update({ attempts: row.attempts + 1, last_error: String(e).slice(0, 500) })
        .eq("id", row.id);
    }
  }
  return { sent, batch: rows.length };
}

async function tokensForWard(
  wardId: string, exclude: string | null, only: string | null = null,
): Promise<string[]> {
  const { data: ward, error } = await supabase
    .from("wards").select("member_ids").eq("id", wardId).maybeSingle();
  if (error) throw error;
  const members = ((ward?.member_ids ?? []) as string[])
    .filter((m) => m !== exclude && (only === null || m === only));
  if (!members.length) return [];
  const { data: tokens, error: tErr } = await supabase
    .from("push_tokens").select("token").in("user_id", members);
  if (tErr) throw tErr;
  return (tokens ?? []).map((t) => t.token as string);
}

async function sendOne(project: string, accessToken: string, token: string, row: OutboxRow) {
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(row.data ?? {})) data[k] = String(v);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: row.title, body: row.body },
          data,
          android: {
            priority: row.high_priority ? "HIGH" : "NORMAL",
            notification: { channel_id: row.channel },
          },
          apns: {
            headers: { "apns-priority": row.high_priority ? "10" : "5" },
            payload: { aps: { sound: "default" } },
          },
        },
      }),
    },
  );
  if (res.ok) return;
  const text = await res.text();
  // Uninstalled app / rotated token: forget it, don't fail the row.
  if (res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
    await supabase.from("push_tokens").delete().eq("token", token);
    return;
  }
  throw new Error(`FCM ${res.status}: ${text.slice(0, 300)}`);
}

// ── Google OAuth for the service account (JWT bearer, RS256) ────────────

let cached: { token: string; expires: number } | null = null;

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expires - 60 > now) return cached.token;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const jwt = `${header}.${claims}.${b64url(signature)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`Google OAuth ${res.status}: ${await res.text()}`);
  const json = await res.json();
  cached = { token: json.access_token, expires: now + (json.expires_in ?? 3600) };
  return cached.token;
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
