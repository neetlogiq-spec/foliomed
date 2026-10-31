// Read-only access to FolioMed's public counters for the landing and
// status pages. Uses Supabase's REST API with the *anon* (public) key —
// row-level security only exposes the `metrics` table and the
// `public_activity()` function to anonymous visitors.
export const SUPABASE_URL = 'https://zfnucugpbpyrymyyrary.supabase.co';
// Anon (public) key — safe to ship; row-level security protects the data.
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmbnVjdWdwYnB5cnlteXlyYXJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzNDI4NzYsImV4cCI6MjEwNzkxODg3Nn0.EfnY502tfuZ_qjsiLA0q0ul07t3zXs2K1YQwVnG80cA';

const headers = () => ({
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
});

export const isConfigured = () => SUPABASE_ANON_KEY.length > 0;

async function getJson(path, init = {}) {
  if (!isConfigured()) throw new Error('Supabase anon key not set');
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { ...headers(), ...(init.headers || {}) },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

/** Returns { users, wards, patients, notes, acks, comments, lastActivityAt }. */
export async function fetchTotals() {
  const rows = await getJson('/rest/v1/metrics?select=type,count,last_at');
  const byType = Object.fromEntries(rows.map((r) => [r.type, r]));
  const count = (t) => Number(byType[t]?.count ?? 0);
  const last = rows
    .map((r) => (r.last_at ? new Date(r.last_at) : null))
    .filter(Boolean)
    .sort((a, b) => b - a)[0] || null;
  return {
    users: count('user'), wards: count('ward'), patients: count('patient'),
    notes: count('note'), acks: count('ack'), comments: count('comment'),
    lastActivityAt: last,
  };
}

/** Latest events as [{ type, at: Date }]. */
export async function fetchActivity(limit = 20) {
  const rows = await getJson('/rest/v1/rpc/public_activity', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_limit: limit }),
  });
  return rows.map((r) => ({ type: r.type, at: new Date(r.at) }));
}

/** Health probe of the Auth service; resolves to latency in ms. */
export async function pingAuth() {
  const start = performance.now();
  const res = await fetch(`${SUPABASE_URL}/auth/v1/health`, { headers: headers() });
  if (res.status >= 500) throw new Error(`HTTP ${res.status}`);
  return Math.round(performance.now() - start);
}
