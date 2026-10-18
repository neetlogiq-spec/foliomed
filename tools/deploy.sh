#!/bin/bash
# Verifies the app and pushes to GitHub. GitHub Actions
# (.github/workflows/deploy.yml) then builds the web app and publishes
# landing + status + app to GitHub Pages at www.foliomed.app.
#
# Deliberately does NOT `git add` / commit anything — commit yourself first.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

echo ""
echo "══════════════════════════════════"
echo "  FolioMed Deploy"
echo "══════════════════════════════════"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "✗ You have uncommitted changes — commit them first." >&2
  exit 1
fi

echo ""
echo "→ Analyzing + testing..."
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
echo "  ✓ Checks passed"

echo ""
echo "→ Pushing to GitHub..."
git push origin HEAD
echo "  ✓ Pushed — GitHub Actions will publish https://www.foliomed.app"
echo ""
