#!/usr/bin/env bash
# Analyse + test, then push. GitHub Actions publishes the website and web
# app from main. Refuses to run with uncommitted changes.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Commit or stash your changes first." >&2
  exit 1
fi
flutter analyze --no-fatal-infos
flutter test
git push origin HEAD
echo "Pushed. The site updates at https://www.foliomed.app in a few minutes."
