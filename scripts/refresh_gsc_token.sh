#!/usr/bin/env bash
set -euo pipefail

OAUTH_FILE="${1:-${GSC_OAUTH_FILE:-$HOME/.config/dave-blake/gsc_oauth.json}}"
OUT_TOKEN_FILE="${2:-${GSC_BEARER_TOKEN_FILE:-$HOME/.config/dave-blake/gsc_bearer_token.txt}}"

if [[ ! -f "$OAUTH_FILE" ]]; then
  echo "ERROR: OAuth file not found: $OAUTH_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required." >&2
  exit 1
fi

CLIENT_ID="$(jq -r '.client_id // empty' "$OAUTH_FILE")"
CLIENT_SECRET="$(jq -r '.client_secret // empty' "$OAUTH_FILE")"
REFRESH_TOKEN="$(jq -r '.refresh_token // empty' "$OAUTH_FILE")"
TOKEN_URI="$(jq -r '.token_uri // "https://oauth2.googleapis.com/token"' "$OAUTH_FILE")"

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || -z "$REFRESH_TOKEN" ]]; then
  echo "ERROR: OAuth file missing client_id/client_secret/refresh_token." >&2
  exit 1
fi

RESP="$(curl -sS -X POST "$TOKEN_URI" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "grant_type=refresh_token")"

if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: token refresh failed." >&2
  echo "$RESP" | jq -r '.error_description // .error' >&2
  exit 1
fi

ACCESS_TOKEN="$(echo "$RESP" | jq -r '.access_token // empty')"
EXPIRES_IN="$(echo "$RESP" | jq -r '.expires_in // 0')"

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: no access_token received." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_TOKEN_FILE")"
chmod 700 "$(dirname "$OUT_TOKEN_FILE")" || true
printf '%s' "$ACCESS_TOKEN" > "$OUT_TOKEN_FILE"
chmod 600 "$OUT_TOKEN_FILE" || true

echo "Token refreshed."
echo "Token file: $OUT_TOKEN_FILE"
echo "Expires in: ${EXPIRES_IN}s"

