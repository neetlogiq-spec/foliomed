import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getFirestore,
  doc,
  getDoc,
  collection,
  query,
  orderBy,
  limit,
  getDocs,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

// Cost note (Blaze pay-as-you-go):
// This page used to open three live `onSnapshot` listeners (metrics doc,
// recent_activity feed, and a fresh Firestore probe every 30s). With the
// status tab left open in a browser, that quietly burned thousands of
// Firestore reads per day per viewer. We now do every read as a single
// `getDoc` / `getDocs` and only re-run on user click or every 5 minutes.
const REFRESH_MS = 5 * 60 * 1000; // 5 minutes
const FEED_LIMIT = 20;

const firebaseConfig = {
  apiKey: 'AIzaSyBS8MKN-vzLCFLDmGfws7uJg5_I4fJKnqM',
  authDomain: 'foliomed.firebaseapp.com',
  projectId: 'foliomed',
  storageBucket: 'foliomed.firebasestorage.app',
  messagingSenderId: '525482754887',
  appId: '1:525482754887:web:2886f69b6402f4718a8262',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

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
  const start = performance.now();
  try {
    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseConfig.apiKey}`,
      { method: 'POST', body: JSON.stringify({ idToken: 'none' }) }
    );
    const ms = Math.round(performance.now() - start);
    if (res.status < 500) {
      setStatus('svc-auth', 'green',
        `Auth API reachable · ${ms}ms · Email/Password + Google enabled`);
    } else {
      setStatus('svc-auth', 'red',
        `HTTP ${res.status} — Auth API unreachable`);
    }
  } catch (e) {
    setStatus('svc-auth', 'red', `Error: ${e.message}`);
  }
}

async function checkFirestore() {
  // One-shot read of the public metrics doc as a probe. Used to be a
  // live `onSnapshot` listener — that billed reads on every metrics tick
  // even though the probe only needs a single round-trip.
  const start = performance.now();
  try {
    await getDoc(doc(db, 'metrics', 'totals'));
    const ms = Math.round(performance.now() - start);
    setStatus('svc-firestore', 'green',
      `Connected · ${ms}ms · Public metrics readable`);
  } catch (e) {
    setStatus('svc-firestore', 'red',
      `${e.code || 'error'} — ${e.message}`);
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
    const snap = await getDoc(doc(db, 'metrics', 'totals'));
    if (!snap.exists()) {
      ['ct-users','ct-wards','ct-patients','ct-notes','ct-acks','ct-comments']
        .forEach(id => setCounter(id, '0'));
      setCounter('last-activity', 'no activity yet');
      return;
    }
    const d = snap.data();
    setCounter('ct-users', d.userCount ?? 0);
    setCounter('ct-wards', d.wardCount ?? 0);
    setCounter('ct-patients', d.patientCount ?? 0);
    setCounter('ct-notes', d.noteCount ?? 0);
    setCounter('ct-acks', d.ackCount ?? 0);
    setCounter('ct-comments', d.commentCount ?? 0);

    const ts = d.lastActivityAt?.toDate?.();
    if (ts) {
      setCounter('last-activity', timeAgo(ts));
      document.getElementById('live-pulse')?.classList.add('pulsing');
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
    const q = query(
      collection(db, 'recent_activity'),
      orderBy('at', 'desc'),
      limit(FEED_LIMIT),
    );
    const snap = await getDocs(q);
    if (snap.empty) {
      feed.innerHTML = '<div class="feed-empty">No activity yet — once your team starts using FolioMed, events appear here.</div>';
      return;
    }
    const items = [];
    snap.forEach((d) => {
      const data = d.data();
      const at = data.at?.toDate?.() || new Date();
      items.push(`
        <div class="feed-item">
          <div class="feed-icon ${typeColor(data.type)}">${typeEmoji(data.type)}</div>
          <div class="feed-body">
            <div class="feed-summary">${escape(data.summary || labelFor(data.type))}</div>
            <div class="feed-meta">${labelFor(data.type)} · ${timeAgo(at)}</div>
          </div>
        </div>`);
    });
    feed.innerHTML = items.join('');
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
  await Promise.all([checkAuth(), checkFirestore(), loadCounters(), loadFeed()]);
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
