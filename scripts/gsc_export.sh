#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-data/migration/phase0}"
SITE_PRIMARY="${GSC_SITE_PRIMARY:-https://dave-blake.com/}"
SITE_LEGACY="${GSC_SITE_LEGACY:-https://daveblake.com.au/}"
SKIP_LEGACY="${GSC_SKIP_LEGACY:-1}"
ROW_LIMIT="${GSC_ROW_LIMIT:-25000}"

TOKEN="${GSC_BEARER_TOKEN:-}"
TOKEN_FILE="${GSC_BEARER_TOKEN_FILE:-}"
OAUTH_FILE="${GSC_OAUTH_FILE:-$HOME/.config/dave-blake/gsc_oauth.json}"
SMLE_TOKEN_FILE="${GSC_TOKEN_JSON:-$HOME/.config/smle-gsc/token.json}"
SMLE_CLIENT_FILE="${GSC_CLIENT_JSON:-$HOME/.config/smle-gsc/oauth-client.json}"

if [[ -z "$TOKEN" && -n "$TOKEN_FILE" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(tr -d '\n' < "$TOKEN_FILE")"
fi

if [[ -z "$TOKEN" && -f "$OAUTH_FILE" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to use GSC_OAUTH_FILE." >&2
    exit 2
  fi

  CLIENT_ID="$(jq -r '.client_id // empty' "$OAUTH_FILE")"
  CLIENT_SECRET="$(jq -r '.client_secret // empty' "$OAUTH_FILE")"
  REFRESH_TOKEN="$(jq -r '.refresh_token // empty' "$OAUTH_FILE")"
  TOKEN_URI="$(jq -r '.token_uri // "https://oauth2.googleapis.com/token"' "$OAUTH_FILE")"

  if [[ -n "$CLIENT_ID" && -n "$CLIENT_SECRET" && -n "$REFRESH_TOKEN" ]]; then
    REFRESH_RESP="$(curl -sS -X POST "$TOKEN_URI" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "grant_type=refresh_token")"

    if echo "$REFRESH_RESP" | jq -e '.error' >/dev/null 2>&1; then
      echo "ERROR: token refresh from GSC_OAUTH_FILE failed." >&2
      echo "$REFRESH_RESP" | jq -r '.error_description // .error' >&2
      exit 2
    fi

    TOKEN="$(echo "$REFRESH_RESP" | jq -r '.access_token // empty')"

    if [[ -n "$TOKEN_FILE" && -n "$TOKEN" ]]; then
      mkdir -p "$(dirname "$TOKEN_FILE")"
      chmod 700 "$(dirname "$TOKEN_FILE")" || true
      printf '%s' "$TOKEN" > "$TOKEN_FILE"
      chmod 600 "$TOKEN_FILE" || true
    fi
  fi
fi

if [[ -z "$TOKEN" && -f "$SMLE_TOKEN_FILE" && -f "$SMLE_CLIENT_FILE" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to use token/client JSON files." >&2
    exit 2
  fi

  CLIENT_ID="$(jq -r '.installed.client_id // .web.client_id // empty' "$SMLE_CLIENT_FILE")"
  CLIENT_SECRET="$(jq -r '.installed.client_secret // .web.client_secret // empty' "$SMLE_CLIENT_FILE")"
  TOKEN_URI="$(jq -r '.installed.token_uri // .web.token_uri // "https://oauth2.googleapis.com/token"' "$SMLE_CLIENT_FILE")"
  REFRESH_TOKEN="$(jq -r '.refresh_token // empty' "$SMLE_TOKEN_FILE")"

  if [[ -n "$CLIENT_ID" && -n "$CLIENT_SECRET" && -n "$REFRESH_TOKEN" ]]; then
    REFRESH_RESP="$(curl -sS -X POST "$TOKEN_URI" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "grant_type=refresh_token")"

    if echo "$REFRESH_RESP" | jq -e '.error' >/dev/null 2>&1; then
      echo "WARN: refresh from GSC_TOKEN_JSON/GSC_CLIENT_JSON failed, falling back to existing access_token." >&2
    else
      TOKEN="$(echo "$REFRESH_RESP" | jq -r '.access_token // empty')"
      if [[ -z "$TOKEN" ]]; then
        echo "WARN: refresh returned no access_token, falling back to existing access_token." >&2
      fi
    fi
  fi

  if [[ -z "$TOKEN" ]]; then
    TOKEN="$(jq -r '.access_token // empty' "$SMLE_TOKEN_FILE")"
  fi
fi

if [[ -z "$TOKEN" ]]; then
  cat >&2 <<'EOF'
ERROR: Missing Search Console bearer token.
Set one of:
  - GSC_BEARER_TOKEN
  - GSC_BEARER_TOKEN_FILE (path to file containing token)
  - GSC_OAUTH_FILE (JSON containing client_id/client_secret/refresh_token)
  - GSC_TOKEN_JSON + GSC_CLIENT_JSON (token.json + oauth-client.json pair)
EOF
  exit 2
fi

mkdir -p "$OUT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAILED_EXPORTS="$TMP_DIR/failed_exports.tsv"
touch "$FAILED_EXPORTS"
LAST_GSC_ERROR=""

date_shift_today() {
  local delta="$1"
  if date -v"${delta}"d "+%Y-%m-%d" >/dev/null 2>&1; then
    date -v"${delta}"d "+%Y-%m-%d"
  elif date --date="${delta} day" "+%Y-%m-%d" >/dev/null 2>&1; then
    date --date="${delta} day" "+%Y-%m-%d"
  else
    echo "ERROR: unable to shift current date by ${delta} days on this system." >&2
    exit 1
  fi
}

date_shift_from() {
  local base="$1"
  local delta="$2"
  if date -j -v"${delta}"d -f "%Y-%m-%d" "$base" "+%Y-%m-%d" >/dev/null 2>&1; then
    date -j -v"${delta}"d -f "%Y-%m-%d" "$base" "+%Y-%m-%d"
  elif date --date="$base ${delta} day" "+%Y-%m-%d" >/dev/null 2>&1; then
    date --date="$base ${delta} day" "+%Y-%m-%d"
  else
    echo "ERROR: unable to shift base date ${base} by ${delta} days on this system." >&2
    exit 1
  fi
}

END_DATE="${GSC_END_DATE:-$(date_shift_today -1)}"
START_DATE="${GSC_START_DATE:-$(date_shift_today -90)}"
PREV_END_DATE="${GSC_PREV_END_DATE:-$(date_shift_from "$END_DATE" -365)}"
PREV_START_DATE="${GSC_PREV_START_DATE:-$(date_shift_from "$START_DATE" -365)}"

slugify_site() {
  echo "$1" \
    | sed -E 's#^https?://##; s#/$##; s#[^A-Za-z0-9]+#-#g; s#^-+##; s#-+$##' \
    | tr '[:upper:]' '[:lower:]'
}

url_encode() {
  printf '%s' "$1" | jq -sRr @uri
}

api_query_page() {
  local site="$1"
  local start_date="$2"
  local end_date="$3"
  local dimensions_json="$4"
  local start_row="$5"
  local site_enc payload

  site_enc="$(url_encode "$site")"
  payload="$(
    jq -nc \
      --arg sd "$start_date" \
      --arg ed "$end_date" \
      --argjson dims "$dimensions_json" \
      --argjson sr "$start_row" \
      --argjson rl "$ROW_LIMIT" \
      '{
        startDate: $sd,
        endDate: $ed,
        dimensions: $dims,
        rowLimit: $rl,
        startRow: $sr,
        dataState: "final"
      }'
  )"

  curl -sS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://www.googleapis.com/webmasters/v3/sites/${site_enc}/searchAnalytics/query"
}

fetch_rows_json() {
  local site="$1"
  local start_date="$2"
  local end_date="$3"
  local dimensions_json="$4"
  local out_json="$5"
  local start_row=0

  printf '[]' > "$out_json"

  while true; do
    local resp count merged
    resp="$(api_query_page "$site" "$start_date" "$end_date" "$dimensions_json" "$start_row")"

    if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
      LAST_GSC_ERROR="$(echo "$resp" | jq -r '.error.message // .error')"
      echo "ERROR: GSC API error for site=${site}, dates=${start_date}..${end_date}, dims=${dimensions_json}" >&2
      echo "$LAST_GSC_ERROR" >&2
      return 1
    fi

    count="$(echo "$resp" | jq '(.rows // []) | length')"

    merged="$TMP_DIR/rows_merged.json"
    jq -s '.[0] + (.[1].rows // [])' "$out_json" <(echo "$resp") > "$merged"
    mv "$merged" "$out_json"

    if [[ "$count" -lt "$ROW_LIMIT" ]]; then
      break
    fi

    start_row=$((start_row + count))
  done
}

json_to_pages_csv() {
  local in_json="$1"
  local out_csv="$2"
  jq -r '
    ["page","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @csv
  ' "$in_json" > "$out_csv"
}

json_to_pages_tsv() {
  local in_json="$1"
  local out_tsv="$2"
  jq -r '
    ["page","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @tsv
  ' "$in_json" > "$out_tsv"
}

json_to_queries_csv() {
  local in_json="$1"
  local out_csv="$2"
  jq -r '
    ["query","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @csv
  ' "$in_json" > "$out_csv"
}

json_to_queries_tsv() {
  local in_json="$1"
  local out_tsv="$2"
  jq -r '
    ["query","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @tsv
  ' "$in_json" > "$out_tsv"
}

json_to_page_query_csv() {
  local in_json="$1"
  local out_csv="$2"
  jq -r '
    ["page","query","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.keys[1] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @csv
  ' "$in_json" > "$out_csv"
}

json_to_page_query_tsv() {
  local in_json="$1"
  local out_tsv="$2"
  jq -r '
    ["page","query","clicks","impressions","ctr","position"],
    (.[] | [(.keys[0] // ""), (.keys[1] // ""), (.clicks // 0), (.impressions // 0), (.ctr // 0), (.position // 0)])
    | @tsv
  ' "$in_json" > "$out_tsv"
}

export_window() {
  local site="$1"
  local site_slug="$2"
  local window_slug="$3"
  local start_date="$4"
  local end_date="$5"
  local rows_json

  echo "Exporting ${site} (${window_slug}: ${start_date}..${end_date})"

  rows_json="$TMP_DIR/${site_slug}_${window_slug}_pages.json"
  if ! fetch_rows_json "$site" "$start_date" "$end_date" '["page"]' "$rows_json"; then
    echo -e "${site}\t${window_slug}\tpages\t${LAST_GSC_ERROR}" >> "$FAILED_EXPORTS"
    return 1
  fi
  json_to_pages_csv "$rows_json" "$OUT_DIR/gsc_${site_slug}_pages_${window_slug}.csv"
  json_to_pages_tsv "$rows_json" "$OUT_DIR/gsc_${site_slug}_pages_${window_slug}.tsv"

  rows_json="$TMP_DIR/${site_slug}_${window_slug}_queries.json"
  if ! fetch_rows_json "$site" "$start_date" "$end_date" '["query"]' "$rows_json"; then
    echo -e "${site}\t${window_slug}\tqueries\t${LAST_GSC_ERROR}" >> "$FAILED_EXPORTS"
    return 1
  fi
  json_to_queries_csv "$rows_json" "$OUT_DIR/gsc_${site_slug}_queries_${window_slug}.csv"
  json_to_queries_tsv "$rows_json" "$OUT_DIR/gsc_${site_slug}_queries_${window_slug}.tsv"

  rows_json="$TMP_DIR/${site_slug}_${window_slug}_page_query.json"
  if ! fetch_rows_json "$site" "$start_date" "$end_date" '["page","query"]' "$rows_json"; then
    echo -e "${site}\t${window_slug}\tpage_query\t${LAST_GSC_ERROR}" >> "$FAILED_EXPORTS"
    return 1
  fi
  json_to_page_query_csv "$rows_json" "$OUT_DIR/gsc_${site_slug}_page_query_${window_slug}.csv"
  json_to_page_query_tsv "$rows_json" "$OUT_DIR/gsc_${site_slug}_page_query_${window_slug}.tsv"

  return 0
}

success_exports=0
failed_exports=0

declare -a EXPORT_SITES=()
if [[ -n "$SITE_PRIMARY" ]]; then
  EXPORT_SITES+=("$SITE_PRIMARY")
fi
if [[ "$SKIP_LEGACY" != "1" && -n "$SITE_LEGACY" ]]; then
  EXPORT_SITES+=("$SITE_LEGACY")
fi

if [[ "${#EXPORT_SITES[@]}" -eq 0 ]]; then
  echo "ERROR: no sites configured for export." >&2
  exit 1
fi

if [[ "$SKIP_LEGACY" == "1" ]]; then
  echo "Skipping legacy site export (GSC_SKIP_LEGACY=1)."
fi

for site in "${EXPORT_SITES[@]}"; do
  slug="$(slugify_site "$site")"
  if export_window "$site" "$slug" "last90" "$START_DATE" "$END_DATE"; then
    success_exports=$((success_exports + 1))
  else
    failed_exports=$((failed_exports + 1))
  fi

  if export_window "$site" "$slug" "prevyear90" "$PREV_START_DATE" "$PREV_END_DATE"; then
    success_exports=$((success_exports + 1))
  else
    failed_exports=$((failed_exports + 1))
  fi
done

{
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "site_primary=$SITE_PRIMARY"
  echo "site_legacy=$SITE_LEGACY"
  echo "skip_legacy=$SKIP_LEGACY"
  echo "export_sites=${EXPORT_SITES[*]}"
  echo "window_last90=$START_DATE..$END_DATE"
  echo "window_prevyear90=$PREV_START_DATE..$PREV_END_DATE"
  echo "row_limit=$ROW_LIMIT"
  echo "success_exports=$success_exports"
  echo "failed_exports=$failed_exports"
} > "$OUT_DIR/gsc_export_summary.txt"

if [[ "$failed_exports" -gt 0 ]]; then
  cp "$FAILED_EXPORTS" "$OUT_DIR/gsc_export_failures.tsv"
else
  rm -f "$OUT_DIR/gsc_export_failures.tsv"
fi

if [[ "$success_exports" -eq 0 ]]; then
  echo "ERROR: no successful GSC exports." >&2
  exit 1
fi

echo "GSC export complete: $OUT_DIR"
