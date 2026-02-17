#!/usr/bin/env bash
set -euo pipefail

HOST="${LOCAL_HOST:-127.0.0.1}"
PORT="${LOCAL_PORT:-4173}"
DEV_URL="http://${HOST}:${PORT}"
LOG_FILE="${TMPDIR:-/tmp}/dave-blake-local-http.log"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for local QA server."
  exit 1
fi

python3 -m http.server "$PORT" --bind "$HOST" >"$LOG_FILE" 2>&1 &
HTTP_PID=$!
cleanup() {
  kill "$HTTP_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1
node scripts/dev-prod-diff-report.mjs --dev "$DEV_URL" --fail-on-critical "$@"
