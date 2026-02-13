#!/usr/bin/env bash
set -euo pipefail

PHASE0_DIR="${1:-data/migration/phase0}"
SEED_TSV="$PHASE0_DIR/redirect_matrix_seed.tsv"
DECISIONS_TSV="$PHASE0_DIR/missing_pages_decisions.tsv"

ALL_CSV="$PHASE0_DIR/cloudflare_bulk_redirects_all.csv"
BATCH1_CSV="$PHASE0_DIR/cloudflare_bulk_redirects_batch1.csv"
REVIEW_TSV="$PHASE0_DIR/cloudflare_bulk_redirects_review.tsv"
SUMMARY_TXT="$PHASE0_DIR/cloudflare_bulk_redirects_summary.txt"

mkdir -p "$PHASE0_DIR"

if [[ ! -f "$SEED_TSV" ]]; then
  echo "ERROR: missing seed file: $SEED_TSV" >&2
  exit 1
fi
if [[ ! -f "$DECISIONS_TSV" ]]; then
  echo "ERROR: missing decisions file: $DECISIONS_TSV" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
MERGED_TSV="$TMP_DIR/merged.tsv"

awk -F'\t' -v OFS='\t' '
function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}
function normalize_path(raw,   p) {
  p=trim(raw)
  sub(/^https?:\/\/[^\/]+/, "", p)
  if (p == "") p="/"
  if (p !~ /^\//) p="/" p
  gsub(/\/+/, "/", p)
  if (p != "/" && p ~ /\/$/) sub(/\/+$/, "", p)
  return p
}
function normalize_source_url(url,   s, p) {
  s=trim(url)
  if (s ~ /^https?:\/\//) return s
  p=normalize_path(s)
  return "https://dave-blake.com" p
}
BEGIN {
  primary_domain="dave-blake.com"
  legacy_domain="daveblake.com.au"
  added_from_seed=0
  added_from_decisions=0
  excluded_recover=0
  excluded_410=0
  overridden_targets=0
}
FILENAME == ARGV[1] {
  if (FNR == 1) next
  path=normalize_path($2)
  decision=trim($6)
  suggested_target=trim($5)
  override_target=trim($7)
  clicks[path]=($3 + 0)
  if (decision != "") decisions[path]=decision
  if (override_target != "") {
    decision_target[path]=override_target
  } else {
    decision_target[path]=suggested_target
  }
  next
}
FILENAME == ARGV[2] {
  if (FNR == 1) next

  source_url=normalize_source_url($1)
  target_url=$2
  status_code=$3
  priority=$4

  path=normalize_path(source_url)
  decision=(path in decisions ? decisions[path] : "")

  if (decision == "RECOVER_CONTENT") {
    excluded_recover++
    next
  }
  if (decision == "INTENTIONAL_410") {
    excluded_410++
    next
  }

  if (decision == "REDIRECT_TO_EQUIVALENT" && (path in decision_target) && decision_target[path] != "") {
    if (target_url != decision_target[path]) overridden_targets++
    target_url=decision_target[path]
  }

  batch=(priority == "P0" || priority == "P1") ? 1 : 0
  if (decision == "REDIRECT_TO_EQUIVALENT" && clicks[path] > 0) {
    batch=1
  }

  key=tolower(source_url)
  map_source[key]=source_url
  map_target[key]=target_url
  map_status[key]=status_code
  map_batch[key]=batch
  map_origin[key]="seed"
  map_path[key]=path
  added_from_seed++
  next
}
END {
  for (p in decisions) {
    if (decisions[p] != "REDIRECT_TO_EQUIVALENT") continue

    t=decision_target[p]
    if (t == "") continue

    for (i=1; i<=2; i++) {
      domain=(i == 1 ? primary_domain : legacy_domain)
      src="https://" domain p
      key=tolower(src)
      batch=(clicks[p] > 0) ? 1 : 0

      if (!(key in map_source)) {
        map_source[key]=src
        map_target[key]=t
        map_status[key]="301"
        map_batch[key]=batch
        map_origin[key]="decisions"
        map_path[key]=p
        added_from_decisions++
      } else if (map_target[key] != t) {
        # Decision overrides seed target if mismatch
        map_target[key]=t
        if (batch == 1) map_batch[key]=1
        map_origin[key]="seed+decisions"
      }
    }
  }

  # Review TSV header
  print "source_url", "target_url", "status_code", "batch1", "origin", "path"
  for (k in map_source) {
    print map_source[k], map_target[k], map_status[k], map_batch[k], map_origin[k], map_path[k]
  }

  # Summary to stderr for wrapper capture
  print "added_from_seed=" added_from_seed > "/dev/stderr"
  print "added_from_decisions=" added_from_decisions > "/dev/stderr"
  print "excluded_recover=" excluded_recover > "/dev/stderr"
  print "excluded_410=" excluded_410 > "/dev/stderr"
  print "overridden_targets=" overridden_targets > "/dev/stderr"
}
' "$DECISIONS_TSV" "$SEED_TSV" > "$MERGED_TSV" 2> "$TMP_DIR/merge_stats.txt"

# Sort deterministically for stable diffs
{
  head -n 1 "$MERGED_TSV"
  tail -n +2 "$MERGED_TSV" | sort -t$'\t' -k1,1
} > "$REVIEW_TSV"

# Cloudflare CSV import format: no header row.
# Use 3-column lines (source,target,status) to avoid optional-parameter order issues.
awk -F'\t' '
function q(s){gsub(/"/, "\"\"", s); return "\"" s "\""}
NR > 1 {
  print q($1) "," q($2) "," q($3)
}
' "$REVIEW_TSV" > "$ALL_CSV"

awk -F'\t' '
function q(s){gsub(/"/, "\"\"", s); return "\"" s "\""}
NR > 1 && $4 == "1" {
  print q($1) "," q($2) "," q($3)
}
' "$REVIEW_TSV" > "$BATCH1_CSV"

total_rows="$(wc -l < "$ALL_CSV" | tr -d " ")"
batch_rows="$(wc -l < "$BATCH1_CSV" | tr -d " ")"

{
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "seed_tsv=$SEED_TSV"
  echo "decisions_tsv=$DECISIONS_TSV"
  echo "all_csv=$ALL_CSV"
  echo "batch1_csv=$BATCH1_CSV"
  echo "review_tsv=$REVIEW_TSV"
  cat "$TMP_DIR/merge_stats.txt"
  echo "all_rows=$total_rows"
  echo "batch1_rows=$batch_rows"
  echo "format_note=no-header-3-column-csv(source_url,target_url,status_code)"
} > "$SUMMARY_TXT"

echo "Cloudflare bulk redirect files created:"
echo "  $ALL_CSV"
echo "  $BATCH1_CSV"
echo "  $REVIEW_TSV"
echo "  $SUMMARY_TXT"
