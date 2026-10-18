#!/bin/bash
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

echo ""
echo "══════════════════════════════════"
echo "  FolioMed Deploy"
echo "══════════════════════════════════"

# ── 1. Git push (always runs) ────────
echo ""
echo "→ Pushing to GitHub..."
git add -A
if git diff --cached --quiet; then
  echo "  (nothing new to commit)"
else
  git commit -m "deploy: $(date '+%Y-%m-%d %H:%M')"
fi
git push origin HEAD
echo "  ✓ GitHub up to date"

# ── 2. Build Flutter web ─────────────
echo ""
echo "→ Building Flutter web..."
if ! flutter build web --release 2>&1; then
  echo "  ✗ Flutter build failed — skipping Firebase deploy"
  exit 1
fi
echo "  ✓ Build complete"

# ── 3. Firebase Hosting deploy ───────
echo ""
echo "→ Deploying to Firebase Hosting..."
if ! firebase deploy --only hosting 2>&1; then
  echo "  ✗ Firebase deploy failed (run: firebase login)"
  exit 1
fi
echo "  ✓ Live at https://foliomed.web.app"

echo ""
echo "══════════════════════════════════"
echo "  All done!"
echo "  Web app : https://foliomed.web.app"
echo "══════════════════════════════════"
echo ""
