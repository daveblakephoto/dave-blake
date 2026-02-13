#!/usr/bin/env bash
set -euo pipefail

CLIENT_JSON="${1:-}"
OUT_DIR="${OUT_DIR:-$HOME/.config/dave-blake}"
OUT_OAUTH_FILE="${OUT_OAUTH_FILE:-$OUT_DIR/gsc_oauth.json}"
OUT_TOKEN_FILE="${OUT_TOKEN_FILE:-$OUT_DIR/gsc_bearer_token.txt}"
SCOPE="${GSC_SCOPE:-https://www.googleapis.com/auth/webmasters.readonly}"
REDIRECT_URI="${GSC_REDIRECT_URI:-http://localhost}"

if [[ -z "$CLIENT_JSON" ]]; then
  cat >&2 <<'EOF'
Usage:
  bash scripts/bootstrap_gsc_oauth.sh /absolute/path/to/oauth_client.json

Where oauth_client.json is the Desktop OAuth client secret downloaded from Google Cloud.
EOF
  exit 1
fi

if [[ ! -f "$CLIENT_JSON" ]]; then
  echo "ERROR: file not found: $CLIENT_JSON" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR" || true

CLIENT_ID="$(jq -r '.installed.client_id // .web.client_id // empty' "$CLIENT_JSON")"
CLIENT_SECRET="$(jq -r '.installed.client_secret // .web.client_secret // empty' "$CLIENT_JSON")"

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || "$CLIENT_ID" == "null" || "$CLIENT_SECRET" == "null" ]]; then
  echo "ERROR: Could not read client_id/client_secret from: $CLIENT_JSON" >&2
  echo "Expected Desktop OAuth JSON with .installed.client_id and .installed.client_secret" >&2
  exit 1
fi

urlenc() {
  printf '%s' "$1" | jq -sRr @uri
}

AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?client_id=$(urlenc "$CLIENT_ID")&redirect_uri=$(urlenc "$REDIRECT_URI")&response_type=code&scope=$(urlenc "$SCOPE")&access_type=offline&prompt=consent&include_granted_scopes=true"

cat <<EOF
Step 1: Open this URL in your browser and complete Google consent:

$AUTH_URL

Step 2: After approval you'll be redirected to a localhost URL that may fail to load.
Copy the value of the "code" query parameter and paste it below.
EOF

read -rsp "Paste code: " AUTH_CODE
echo
AUTH_CODE="$(printf '%s' "$AUTH_CODE" | tr -d '\r\n')"

if [[ -z "$AUTH_CODE" ]]; then
  echo "ERROR: code is empty." >&2
  exit 1
fi

TOKEN_RESP="$(curl -sS -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "grant_type=authorization_code" \
  -d "redirect_uri=$REDIRECT_URI")"

if echo "$TOKEN_RESP" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: token exchange failed." >&2
  echo "$TOKEN_RESP" | jq -r '.error_description // .error' >&2
  exit 1
fi

ACCESS_TOKEN="$(echo "$TOKEN_RESP" | jq -r '.access_token // empty')"
REFRESH_TOKEN="$(echo "$TOKEN_RESP" | jq -r '.refresh_token // empty')"
EXPIRES_IN="$(echo "$TOKEN_RESP" | jq -r '.expires_in // 0')"

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: no access_token received." >&2
  exit 1
fi

if [[ -z "$REFRESH_TOKEN" ]]; then
  echo "WARNING: no refresh_token returned. Re-run consent with prompt=consent if needed." >&2
fi

printf '%s' "$ACCESS_TOKEN" > "$OUT_TOKEN_FILE"
chmod 600 "$OUT_TOKEN_FILE" || true

jq -n \
  --arg client_id "$CLIENT_ID" \
  --arg client_secret "$CLIENT_SECRET" \
  --arg refresh_token "$REFRESH_TOKEN" \
  --arg token_uri "https://oauth2.googleapis.com/token" \
  --arg scope "$SCOPE" \
  --arg redirect_uri "$REDIRECT_URI" \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    client_id: $client_id,
    client_secret: $client_secret,
    refresh_token: $refresh_token,
    token_uri: $token_uri,
    scope: $scope,
    redirect_uri: $redirect_uri,
    created_at: $created_at
  }' > "$OUT_OAUTH_FILE"
chmod 600 "$OUT_OAUTH_FILE" || true

cat <<EOF
Success.
Saved:
  Access token: $OUT_TOKEN_FILE
  OAuth config: $OUT_OAUTH_FILE

Next:
  GSC_BEARER_TOKEN_FILE="$OUT_TOKEN_FILE" bash scripts/phase0_gsc_and_redirect_seed.sh data/migration/phase0

Better (auto-refresh on future runs):
  GSC_OAUTH_FILE="$OUT_OAUTH_FILE" bash scripts/phase0_gsc_and_redirect_seed.sh data/migration/phase0

Access token lifetime:
  ${EXPIRES_IN}s
EOF

