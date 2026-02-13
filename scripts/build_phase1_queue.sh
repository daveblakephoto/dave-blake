#!/usr/bin/env bash
set -euo pipefail

PHASE0_DIR="${1:-data/migration/phase0}"
PRIMARY_HOST="${PRIMARY_HOST:-https://www.dave-blake.com}"

LEGACY_FILE="$PHASE0_DIR/legacy_urls.txt"
GSC_PAGES_TSV="$PHASE0_DIR/gsc_dave-blake-com_pages_last90.tsv"
REDIRECT_SEED_TSV="$PHASE0_DIR/redirect_matrix_seed.tsv"

AUDIT_TSV="$PHASE0_DIR/gsc_pages_inventory_audit.tsv"
AUDIT_CSV="$PHASE0_DIR/gsc_pages_inventory_audit.csv"
MISSING_TSV="$PHASE0_DIR/gsc_pages_missing_from_inventory.tsv"
MISSING_CSV="$PHASE0_DIR/gsc_pages_missing_from_inventory.csv"
QUEUE_TSV="$PHASE0_DIR/page_migration_queue.tsv"
QUEUE_CSV="$PHASE0_DIR/page_migration_queue.csv"
SUMMARY_TXT="$PHASE0_DIR/phase1_queue_summary.txt"

if [[ ! -f "$LEGACY_FILE" ]]; then
  echo "ERROR: missing $LEGACY_FILE" >&2
  exit 1
fi
if [[ ! -f "$GSC_PAGES_TSV" ]]; then
  echo "ERROR: missing $GSC_PAGES_TSV" >&2
  exit 1
fi
if [[ ! -f "$REDIRECT_SEED_TSV" ]]; then
  echo "ERROR: missing $REDIRECT_SEED_TSV" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LEGACY_SUMMARY="$TMP_DIR/legacy_summary.tsv"
REDIRECT_SUMMARY="$TMP_DIR/redirect_summary.tsv"
GSC_NORMALIZED="$TMP_DIR/gsc_normalized.tsv"

awk '
function normalize(raw,   p) {
  p=raw
  gsub(/\r/, "", p)
  gsub(/^"+|"+$/, "", p)
  gsub(/﹖/, "?", p)
  if (p !~ /^\//) p="/" p
  sub(/[?#].*$/, "", p)
  sub(/\/index\.html$/, "/", p)
  sub(/\.html$/, "", p)
  gsub(/\/+/, "/", p)
  if (p == "") p="/"
  if (p != "/" && p ~ /\/$/) sub(/\/+$/, "", p)
  return p
}
{
  raw=$0
  key=normalize(raw)
  cnt[key]++
  if (!(key in example)) example[key]=raw
}
END {
  for (k in cnt) {
    print k "\t" cnt[k] "\t" example[k]
  }
}
' "$LEGACY_FILE" | sort > "$LEGACY_SUMMARY"

awk -F'\t' '
function normalize(raw,   p) {
  p=raw
  gsub(/\r/, "", p)
  gsub(/^"+|"+$/, "", p)
  gsub(/﹖/, "?", p)
  if (p !~ /^\//) p="/" p
  sub(/[?#].*$/, "", p)
  sub(/\/index\.html$/, "/", p)
  sub(/\.html$/, "", p)
  gsub(/\/+/, "/", p)
  if (p == "") p="/"
  if (p != "/" && p ~ /\/$/) sub(/\/+$/, "", p)
  return p
}
NR == 1 { next }
{
  legacy_url=$1
  target_url=$2
  seed_priority=$4
  reason=$5

  if (legacy_url !~ /^https?:\/\/dave-blake\.com\//) next
  p=legacy_url
  sub(/^https?:\/\/[^\/]+/, "", p)
  key=normalize(p)

  if (!(key in target)) {
    target[key]=target_url
    prio[key]=seed_priority
    why[key]=reason
  }
}
END {
  for (k in target) {
    print k "\t" target[k] "\t" prio[k] "\t" why[k]
  }
}
' "$REDIRECT_SEED_TSV" | sort > "$REDIRECT_SUMMARY"

awk -F'\t' '
function normalize(raw,   p) {
  p=raw
  gsub(/\r/, "", p)
  gsub(/^"+|"+$/, "", p)
  gsub(/﹖/, "?", p)
  if (p !~ /^\//) p="/" p
  sub(/[?#].*$/, "", p)
  sub(/\/index\.html$/, "/", p)
  sub(/\.html$/, "", p)
  gsub(/\/+/, "/", p)
  if (p == "") p="/"
  if (p != "/" && p ~ /\/$/) sub(/\/+$/, "", p)
  return p
}
NR == 1 { next }
{
  page_url=$1
  clicks=$2 + 0
  impressions=$3 + 0
  p=page_url
  sub(/^https?:\/\/[^\/]+/, "", p)
  key=normalize(p)
  print key "\t" page_url "\t" clicks "\t" impressions
}
' "$GSC_PAGES_TSV" > "$GSC_NORMALIZED"

awk -F'\t' -v OFS='\t' -v primary_host="$PRIMARY_HOST" '
FILENAME == ARGV[1] {
  legacy_count[$1]=$2
  legacy_example[$1]=$3
  next
}
FILENAME == ARGV[2] {
  redirect_target[$1]=$2
  seed_priority[$1]=$3
  seed_reason[$1]=$4
  next
}
{
  key=$1
  page_url=$2
  clicks=$3 + 0
  impressions=$4 + 0

  in_legacy=((key in legacy_count) ? 1 : 0)
  legacy_cnt=((key in legacy_count) ? legacy_count[key] : 0)
  legacy_ex=((key in legacy_example) ? legacy_example[key] : "")

  computed_priority="P3"
  if (clicks >= 50) computed_priority="P0"
  else if (clicks >= 10) computed_priority="P1"
  else if (clicks > 0) computed_priority="P2"

  final_priority=((key in seed_priority) ? seed_priority[key] : computed_priority)
  reason=((key in seed_reason) ? seed_reason[key] : (in_legacy ? "exact_path_preservation" : "not_in_inventory"))
  target=((key in redirect_target) ? redirect_target[key] : primary_host key)

  action="migrate_page_content"
  if (in_legacy == 0) action="recover_or_map_redirect"
  else if (reason ~ /^consolidate_/) action="redirect_consolidation"

  print page_url, key, clicks, impressions, in_legacy, legacy_cnt, legacy_ex, final_priority, reason, target, action
}
' "$LEGACY_SUMMARY" "$REDIRECT_SUMMARY" "$GSC_NORMALIZED" \
  | sort -t$'\t' -k3,3nr \
  | {
      echo -e "page_url\tpage_path\tclicks\timpressions\tin_legacy_inventory\tlegacy_candidate_count\tlegacy_example\tpriority\treason\ttarget_url\trecommended_action"
      cat
    } > "$AUDIT_TSV"

awk -F'\t' 'NR == 1 || $5 == "0"' "$AUDIT_TSV" > "$MISSING_TSV"
awk -F'\t' 'NR == 1 || ($11 == "migrate_page_content" && $3 + 0 > 0)' "$AUDIT_TSV" > "$QUEUE_TSV"

to_csv() {
  local in_tsv="$1"
  local out_csv="$2"
  awk -F'\t' '
  function q(s) { gsub(/"/, "\"\"", s); return "\"" s "\"" }
  {
    out=""
    for (i=1; i<=NF; i++) {
      out = out (i==1 ? "" : ",") q($i)
    }
    print out
  }' "$in_tsv" > "$out_csv"
}

to_csv "$AUDIT_TSV" "$AUDIT_CSV"
to_csv "$MISSING_TSV" "$MISSING_CSV"
to_csv "$QUEUE_TSV" "$QUEUE_CSV"

total_gsc_rows=$(( $(wc -l < "$AUDIT_TSV") - 1 ))
missing_rows=$(( $(wc -l < "$MISSING_TSV") - 1 ))
queue_rows=$(( $(wc -l < "$QUEUE_TSV") - 1 ))
missing_clicks="$(awk -F'\t' 'NR>1 {s+=$3} END {printf "%.0f", s+0}' "$MISSING_TSV")"
queue_clicks="$(awk -F'\t' 'NR>1 {s+=$3} END {printf "%.0f", s+0}' "$QUEUE_TSV")"
total_clicks="$(awk -F'\t' 'NR>1 {s+=$3} END {printf "%.0f", s+0}' "$AUDIT_TSV")"

{
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "total_gsc_rows=$total_gsc_rows"
  echo "total_clicks=$total_clicks"
  echo "missing_rows=$missing_rows"
  echo "missing_clicks=$missing_clicks"
  echo "queue_rows=$queue_rows"
  echo "queue_clicks=$queue_clicks"
  echo "audit_tsv=$AUDIT_TSV"
  echo "missing_tsv=$MISSING_TSV"
  echo "queue_tsv=$QUEUE_TSV"
} > "$SUMMARY_TXT"

echo "Phase 1 queue artifacts created:"
echo "  $AUDIT_CSV"
echo "  $MISSING_CSV"
echo "  $QUEUE_CSV"
echo "  $SUMMARY_TXT"
