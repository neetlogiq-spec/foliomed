#!/usr/bin/env bash
# Start the FolioMed vitals VLM for FolioMed Edge.
#
# FolioMed Edge probes http://127.0.0.1:8080/health and switches its camera
# readers from regex-OCR to the AI model automatically while this runs.
#
# Requires llama.cpp (brew install llama.cpp) and the exported model from
# the foliomed-vitals-ai playbook (scripts/3_convert_on_mac.md).
#
# Usage:
#   tools/start_vlm_server.sh                # defaults below
#   MODEL_DIR=~/foliomed-model-v3 PORT=8080 tools/start_vlm_server.sh

set -euo pipefail

MODEL_DIR="${MODEL_DIR:-$HOME/foliomed-model-v3}"
PORT="${PORT:-8080}"

MODEL="$(ls "$MODEL_DIR"/*q4_k_m.gguf 2>/dev/null | head -1)"
MMPROJ="$(ls "$MODEL_DIR"/mmproj-*.gguf 2>/dev/null | head -1)"

if [[ -z "$MODEL" || -z "$MMPROJ" ]]; then
  echo "Model files not found in $MODEL_DIR" >&2
  echo "Expected a *q4_k_m.gguf and an mmproj-*.gguf" >&2
  exit 1
fi

if curl -s --max-time 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "A server is already running on port $PORT — nothing to do."
  exit 0
fi

echo "Serving $(basename "$MODEL") on http://127.0.0.1:$PORT"
echo "Note: CPU-only Macs take minutes per frame; GPU boxes take seconds."
exec llama-server -m "$MODEL" --mmproj "$MMPROJ" --host 127.0.0.1 --port "$PORT"
