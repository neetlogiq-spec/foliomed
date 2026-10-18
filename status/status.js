import {
  fetchTotals,
  fetchActivity,
  pingAuth,
  isConfigured,
} from '../supabase-public.js';

// Every read is a one-shot REST call, re-run on click or every 5 minutes
// and paused while the tab is hidden.
const REFRESH_MS = 5 * 60 * 1000; // 5 minutes
const FEED_LIMIT = 20;

// ────────── Health checks ──────────
function setStatus(cardId, state, detailText) {
  const card = document.getElementById(cardId);
  if (!card) return;
  const pill = card.querySelector('[data-slot="pill"]');
  const detail = card.querySelector('[data-slot="detail"]');
  if (pill) {
    pill.className = 'status-pill ' + state;
    pill.textContent =
      state === 'green' ? 'OK' :
      state === 'amber' ? 'DEGRADED' :
      state === 'red' ? 'DOWN' : state.toUpperCase();
  }
  if (detail) detail.textContent = detailText;
}

async function checkAuth() {
  try {
    const ms = await pingAuth();
    setStatus('svc-auth', 'green',
      `Auth API reachable · ${ms}ms · Email/Password, Google, Apple`);
  } catch (e) {
    setStatus('svc-auth', 'red', `Error: ${e.message}`);
  }
}

async function checkDatabase() {
  if (!isConfigured()) {
    setStatus('svc-firestore', 'amber', 'Supabase anon key not configured');
    return;
  }
  const start = performance.now();
  try {
    await fetchTotals();
    const ms = Math.round(performance.now() - start);
    setStatus('svc-firestore', 'green',
      `Connected · ${ms}ms · Public metrics readable`);
  } catch (e) {
    setStatus('svc-firestore', 'red', `Error — ${e.message}`);
  }
}

function updateHeader() {
  document.getElementById('last-check').textContent =
    new Date().toLocaleString();
}

function tally() {
  const pills = document.querySelectorAll('.status-pill');
  let degraded = 0, down = 0;
  pills.forEach(p => {
    if (p.classList.contains('amber')) degraded++;
    else if (p.classList.contains('red')) down++;
  });
  const el = document.getElementById('overall');
  const banner = document.getElementById('alert-banner');
  const bannerIcon = document.getElementById('alert-icon');
  const bannerText = document.getElementById('alert-text');
  if (down > 0) {
    el.textContent = `⚠ ${down} service(s) down.`;
    el.style.color = '#ff6b6b';
    banner.className = 'alert-banner red';
    bannerIcon.textContent = '✕';
    bannerText.textContent = `${down} service${down>1?'s are':' is'} down — investigate now.`;
  } else if (degraded > 0) {
    el.textContent = `All core systems operational · ${degraded} pending setup.`;
    el.style.color = '#f6b93b';
    banner.className = 'alert-banner amber';
    bannerIcon.textContent = '⚠';
    bannerText.textContent = `${degraded} service${degraded>1?'s need':' needs'} attention.`;
  } else {
    el.textContent = '✓ All systems operational.';
    el.style.color = '#00c896';
    banner.className = 'alert-banner hidden';
  }
}

// ────────── Live counters (one-shot) ──────────
function setCounter(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value ?? '—';
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
    if (d.lastActivityAt) {
      setCounter('last-activity', timeAgo(d.lastActivityAt));
      document.getElementById('live-pulse')?.classList.add('pulsing');
    } else {
      setCounter('last-activity', 'no activity yet');
    }
  } catch (e) {
    console.warn('loadCounters failed:', e);
  }
}

// ────────── Activity feed (one-shot) ──────────
async function loadFeed() {
  const feed = document.getElementById('activity-feed');
  if (!feed) return;
  try {
    const events = await fetchActivity(FEED_LIMIT);
    if (events.length === 0) {
      feed.innerHTML = '<div class="feed-empty">No activity yet — once your team starts using FolioMed, events appear here.</div>';
      return;
    }
    // Summaries stay private (they can name patients) — show type + time.
    feed.innerHTML = events.map(({ type, at }) => `
        <div class="feed-item">
          <div class="feed-icon ${typeColor(type)}">${typeEmoji(type)}</div>
          <div class="feed-body">
            <div class="feed-summary">${escape(labelFor(type))}</div>
            <div class="feed-meta">${timeAgo(at)}</div>
          </div>
        </div>`).join('');
  } catch (e) {
    console.warn('loadFeed failed:', e);
    feed.innerHTML =
      '<div class="feed-empty">Could not load activity right now.</div>';
  }
}

function typeEmoji(t) {
  return ({note:'📝', ack:'✅', comment:'💬', patient:'🛏️', ward:'🏥', user:'👤'})[t] || '•';
}
function typeColor(t) {
  return ({note:'blue', ack:'green', comment:'purple', patient:'amber', ward:'teal', user:'pink'})[t] || 'blue';
}
function labelFor(t) {
  return ({note:'Note posted', ack:'Note acknowledged', comment:'Reply', patient:'Patient admitted', ward:'Ward created', user:'User signed up'})[t] || t;
}
function timeAgo(d) {
  const sec = Math.floor((Date.now() - d.getTime()) / 1000);
  if (sec < 60) return `${sec}s ago`;
  if (sec < 3600) return `${Math.floor(sec/60)}m ago`;
  if (sec < 86400) return `${Math.floor(sec/3600)}h ago`;
  return `${Math.floor(sec/86400)}d ago`;
}
function escape(s) {
  return String(s ?? '').replace(/[&<>"']/g, c =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]);
}

// ────────── Orchestration ──────────
async function runAll() {
  await Promise.all([checkAuth(), checkDatabase(), loadCounters(), loadFeed()]);
  updateHeader();
  setTimeout(tally, 200);
}

document.getElementById('recheck')?.addEventListener('click', runAll);
runAll();

// Re-run only every 5 minutes (was 30s). Pause completely when the tab
// is hidden — no point billing reads while the user can't see them.
let timer = null;
function startAutoRefresh() {
  stopAutoRefresh();
  timer = setInterval(runAll, REFRESH_MS);
}
function stopAutoRefresh() {
  if (timer) { clearInterval(timer); timer = null; }
}
document.addEventListener('visibilitychange', () => {
  if (document.hidden) stopAutoRefresh();
  else { startAutoRefresh(); runAll(); }
});
startAutoRefresh();
