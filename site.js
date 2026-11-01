// FolioMed website behaviour: scroll reveals and the live totals.
import { fetchTotals, isConfigured } from './supabase-public.js';

const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Reveal sections once as they enter the viewport (skipped under Reduce Motion).
const revealables = document.querySelectorAll('.reveal');
if (!reduceMotion && 'IntersectionObserver' in window) {
  document.documentElement.classList.add('js-reveal');
}
if (reduceMotion || !('IntersectionObserver' in window)) {
  revealables.forEach((el) => el.classList.add('in'));
} else {
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          io.unobserve(entry.target);
        }
      }
    },
    { rootMargin: '0px 0px -10% 0px', threshold: 0.1 },
  );
  revealables.forEach((el) => io.observe(el));
}

// Live totals from Supabase (anon key; counts only).
const fmt = new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 });
async function loadTotals() {
  const slots = document.querySelectorAll('[data-stat]');
  if (!slots.length || !isConfigured()) return;
  try {
    const totals = await fetchTotals();
    slots.forEach((el) => {
      const value = totals[el.dataset.stat];
      if (typeof value === 'number') el.textContent = fmt.format(value);
    });
  } catch (err) {
    console.warn('FolioMed totals unavailable:', err);
  }
}
loadTotals();
