import {
  fetchTotals,
  fetchActivity,
  pingAuth,
  isConfigured,
} from '../supabase-public.js';

// One-shot REST calls, re-run on demand or every 5 minutes while visible.
const REFRESH_MS = 5 * 60 * 1000;
const FEED_LIMIT = 15;

const LABELS = { ok: 'Operational', down: 'Unavailable', checking: 'Checking', pending: 'Not configured' };

function setService(id, state, detail) {
  const row = document.getElementById(id);
  if (!row) return;
  row.dataset.state = state;
  const label = row.querySelector('[data-slot="label"]');
  if (label) label.textContent = LABELS[state] ?? state;
  const d = row.querySelector('[data-slot="detail"]');
  if (d && detail) d.textContent = detail;
}

async function checkAuth() {
  try {
    const ms = await pingAuth();
    setService('svc-auth', 'ok', `Google and Apple sign-in · responded in ${ms} ms`);
  } catch (e) {
    setService('svc-auth', 'down', `Sign-in service not responding (${e.message})`);
  }
}

async function checkDatabase() {
  if (!isConfigured()) return setService('svc-database', 'pending');
  const start = performance.now();
  try {
    await fetchTotals();
    const ms = Math.round(performance.now() - start);
    setService('svc-database', 'ok', `Wards, patients and notes · responded in ${ms} ms`);
  } catch (e) {
    setService('svc-database', 'down', `Database not responding (${e.message})`);
  }
}

function summarise() {
  const live = ['svc-auth', 'svc-database'].map((id) => document.getElementById(id)?.dataset.state);
  const el = document.getElementById('overall');
  const down = live.filter((s) => s === 'down').length;
  const [color, text] = down
    ? ['var(--red-dot)', `${down} service${down > 1 ? 's are' : ' is'} unavailable`]
    : ['var(--green-dot)', 'All systems operational'];
  el.innerHTML = '';
  const dot = document.createElement('span');
  dot.className = 'dot';
  dot.style.background = color;
  const label = document.createElement('span');
  label.textContent = text;
  el.append(dot, label);
  document.getElementById('last-check').textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

const fmt = new Intl.NumberFormat();
function setCounter(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = typeof value === 'number' ? fmt.format(value) : (value ?? '—');
}

async function loadCounters() {
  try {
    const d = await fetchTotals();
    setCounter('ct-users', d.users);
    setCounter('ct-wards', d.wards);
    setCounter('ct-patients', d.patients);
    setCounter('ct-notes', d.notes);
    setCounter('ct-acks', d.acks);
    setCounter('ct-comments', d.comments);
    setCounter('last-activity', d.lastActivityAt ? timeAgo(d.lastActivityAt) : 'none yet');
  } catch (e) {
    console.warn('Totals unavailable:', e);
  }
}

const EVENT = {
  note: 'Note posted', ack: 'Note acknowledged', comment: 'Reply posted',
  patient: 'Patient admitted', ward: 'Ward created', user: 'Clinician joined',
};

async function loadFeed() {
  const feed = document.getElementById('activity-feed');
  try {
    const events = await fetchActivity(FEED_LIMIT);
    feed.replaceChildren();
    if (!events.length) {
      const li = document.createElement('li');
      li.className = 'empty';
      li.textContent = 'No activity yet.';
      feed.append(li);
      return;
    }
    for (const { type, at } of events) {
      const li = document.createElement('li');
      const name = document.createElement('span');
      name.textContent = EVENT[type] ?? type;
      const time = document.createElement('time');
      time.dateTime = at.toISOString();
      time.textContent = timeAgo(at);
      li.append(name, time);
      feed.append(li);
    }
  } catch (e) {
    feed.innerHTML = '<li class="empty">Activity is unavailable right now.</li>';
  }
}

function timeAgo(d) {
  const s = Math.max(0, Math.floor((Date.now() - d.getTime()) / 1000));
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} d ago`;
}

async function runAll() {
  await Promise.all([checkAuth(), checkDatabase(), loadCounters(), loadFeed()]);
  summarise();
}

document.getElementById('recheck')?.addEventListener('click', runAll);
runAll();

let timer = setInterval(runAll, REFRESH_MS);
document.addEventListener('visibilitychange', () => {
  clearInterval(timer);
  if (!document.hidden) {
    runAll();
    timer = setInterval(runAll, REFRESH_MS);
  }
});
