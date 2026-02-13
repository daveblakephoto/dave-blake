#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${1:-${HOME}/.config/dave-blake/gsc_bearer_token.txt}"
TOKEN_DIR="$(dirname "$TOKEN_FILE")"

mkdir -p "$TOKEN_DIR"
chmod 700 "$TOKEN_DIR" || true

echo "Search Console token setup"
echo "Token file: $TOKEN_FILE"
echo
echo "Paste your GSC bearer token, then press Enter."
read -rsp "Token: " TOKEN
echo

TOKEN="$(printf '%s' "$TOKEN" | tr -d '\r\n')"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: token is empty." >&2
  exit 1
fi

printf '%s' "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE" || true

cat <<EOF
Saved token to:
  $TOKEN_FILE

Next command (from repo root):
  GSC_BEARER_TOKEN_FILE="$TOKEN_FILE" bash scripts/phase0_gsc_and_redirect_seed.sh data/migration/phase0

Optional for this terminal session:
  export GSC_BEARER_TOKEN_FILE="$TOKEN_FILE"
EOF

