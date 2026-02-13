#!/usr/bin/env bash
set -euo pipefail

LEGACY_FILE="${1:-data/migration/phase0/legacy_urls.txt}"
OUT_CSV="${2:-data/migration/phase0/redirect_matrix_seed.csv}"
PRIMARY_HOST="${PRIMARY_HOST:-https://www.dave-blake.com}"
GSC_PAGES_TSV_GLOB="${GSC_PAGES_TSV_GLOB:-data/migration/phase0/gsc_*_pages_last90.tsv}"
BACKLINK_FILE="${BACKLINK_FILE:-data/migration/phase0/backlink_targets.txt}"

OUT_DIR="$(dirname "$OUT_CSV")"
mkdir -p "$OUT_DIR"

if [[ ! -f "$LEGACY_FILE" ]]; then
  echo "ERROR: legacy URL inventory not found: $LEGACY_FILE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CLICKS_RAW="$TMP_DIR/gsc_pages_raw.tsv"
CLICKS_MAP="$TMP_DIR/clicks_by_path.tsv"
BACKLINK_PATHS="$TMP_DIR/backlink_paths.txt"
SEED_TSV="$TMP_DIR/seed_rows.tsv"
MATRIX_TSV="$OUT_DIR/redirect_matrix_seed.tsv"
TOP_TSV="$OUT_DIR/redirect_priority_p0_p1.tsv"
TOP_CSV="$OUT_DIR/redirect_priority_p0_p1.csv"

> "$CLICKS_RAW"
has_gsc=0
for f in $GSC_PAGES_TSV_GLOB; do
  if [[ -f "$f" ]]; then
    has_gsc=1
    tail -n +2 "$f" >> "$CLICKS_RAW"
  fi
done

awk -F'\t' '
function normalize_path(raw, p) {
  p=raw
  gsub(/\r/, "", p)
  gsub(/^"+|"+$/, "", p)
  gsub(/﹖/, "?", p)
  if (p ~ /^https?:\/\//) sub(/^https?:\/\/[^\/]+/, "", p)
  if (p !~ /^\//) p="/" p
  sub(/[?#].*$/, "", p)
  sub(/\/index\.html$/, "/", p)
  sub(/\.html$/, "", p)
  gsub(/\/+/, "/", p)
  if (p == "") p="/"
  if (p != "/" && p ~ /\/$/) sub(/\/+$/, "", p)
  return p
}
NF >= 2 {
  p=normalize_path($1)
  c=$2 + 0
  clicks[p] += c
}
END {
  for (p in clicks) {
    printf "%s\t%.6f\n", p, clicks[p]
  }
}
' "$CLICKS_RAW" > "$CLICKS_MAP"

if [[ -f "$BACKLINK_FILE" ]]; then
  awk '
  function normalize_path(raw, p) {
    p=raw
    gsub(/\r/, "", p)
    gsub(/^"+|"+$/, "", p)
    gsub(/﹖/, "?", p)
    if (p ~ /^https?:\/\//) sub(/^https?:\/\/[^\/]+/, "", p)
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
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) next
    print normalize_path($0)
  }
  ' "$BACKLINK_FILE" | sort -u > "$BACKLINK_PATHS"
else
  : > "$BACKLINK_PATHS"
fi

awk -v primary_host="$PRIMARY_HOST" '
function normalize_input(raw, path) {
  path=raw
  gsub(/\r/, "", path)
  gsub(/﹖/, "?", path)
  if (path !~ /^\//) path="/" path
  return path
}
function normalize_base(path, base) {
  base=path
  sub(/\?.*$/, "", base)
  sub(/\/index\.html$/, "/", base)
  sub(/\.html$/, "", base)
  gsub(/\/+/, "/", base)
  if (base == "") base="/"
  if (base != "/" && base ~ /\/$/) sub(/\/+$/, "", base)
  return base
}
function build_target(path,   base, reason, pos, target) {
  base=normalize_base(path)
  reason="exact_path_preservation"
  if (path ~ /\?/) reason="collapse_query_variant"
  if (path ~ /\/tag\//) reason="consolidate_tag_taxonomy"
  else if (path ~ /\/category\//) reason="consolidate_category_taxonomy"
  else if (path ~ /\.rss$/ || path ~ /format=rss/) reason="consolidate_rss"

  target=base

  if (reason == "consolidate_tag_taxonomy") {
    pos=index(base, "/tag/")
    if (pos > 0) target=substr(base, 1, pos - 1)
  } else if (reason == "consolidate_category_taxonomy") {
    pos=index(base, "/category/")
    if (pos > 0) target=substr(base, 1, pos - 1)
  } else if (reason == "consolidate_rss") {
    if (base ~ /^\/blog/) target="/blog"
    else if (base ~ /^\/story/) target="/story"
    else if (base ~ /^\/photographer/) target="/photographer"
    else target="/"
  }

  if (target == "") target="/"
  if (target !~ /^\//) target="/" target
  gsub(/\/+/, "/", target)
  if (target != "/" && target ~ /\/$/) sub(/\/+$/, "", target)

  return reason "|" target
}
BEGIN { OFS="\t" }
{
  legacy_path=normalize_input($0)
  path_key=normalize_base(legacy_path)
  legacy_path_encoded=legacy_path
  gsub(/ /, "%20", legacy_path_encoded)
  split(build_target(legacy_path), parts, "|")
  reason=parts[1]
  target_path=parts[2]
  confidence=(reason == "exact_path_preservation") ? "high" : "medium"

  print "https://dave-blake.com" legacy_path_encoded, primary_host target_path, "301", reason, confidence, legacy_path, path_key, target_path
  print "https://daveblake.com.au" legacy_path_encoded, primary_host target_path, "301", reason, confidence, legacy_path, path_key, target_path
}
' "$LEGACY_FILE" | sort -u > "$SEED_TSV"

awk -F'\t' '
BEGIN {
  OFS="\t"
}
FILENAME == ARGV[1] {
  clicks[$1] = $2 + 0
  next
}
FILENAME == ARGV[2] {
  backlink[$1] = 1
  next
}
{
  legacy_url=$1
  target_url=$2
  status_code=$3
  reason=$4
  confidence=$5
  legacy_path=$6
  path_key=$7
  target_path=$8

  c=(path_key in clicks) ? clicks[path_key] : 0
  b=((path_key in backlink) || (target_path in backlink)) ? 1 : 0

  priority="P3"
  if (c >= 50) priority="P0"
  else if (c >= 10) priority="P1"
  else if (c > 0) priority="P2"
  if (b == 1 && priority == "P3") priority="P1"

  notes=""
  if (b == 1) notes="backlink-target"
  if (c == 0 && b == 0) notes=(notes == "" ? "needs-validation" : notes ";needs-validation")

  print legacy_url, target_url, status_code, priority, reason, confidence, sprintf("%.0f", c), b, notes
}
' "$CLICKS_MAP" "$BACKLINK_PATHS" "$SEED_TSV" \
  | {
      echo -e "legacy_url\ttarget_url\tstatus_code\tpriority\treason\tconfidence\tlast90_clicks\tbacklink_flag\tnotes"
      cat
    } > "$MATRIX_TSV"

awk -F'\t' 'NR == 1 || $4 == "P0" || $4 == "P1"' "$MATRIX_TSV" > "$TOP_TSV"

{
  head -n 1 "$TOP_TSV"
  tail -n +2 "$TOP_TSV" | sort -t$'\t' -k7,7nr
} > "$TMP_DIR/top_sorted.tsv"
mv "$TMP_DIR/top_sorted.tsv" "$TOP_TSV"

awk -F'\t' '
function q(s) {
  gsub(/"/, "\"\"", s)
  return "\"" s "\""
}
{
  print q($1) "," q($2) "," q($3) "," q($4) "," q($5) "," q($6) "," q($7) "," q($8) "," q($9)
}
' "$MATRIX_TSV" > "$OUT_CSV"

awk -F'\t' '
function q(s) {
  gsub(/"/, "\"\"", s)
  return "\"" s "\""
}
{
  print q($1) "," q($2) "," q($3) "," q($4) "," q($5) "," q($6) "," q($7) "," q($8) "," q($9)
}
' "$TOP_TSV" > "$TOP_CSV"

if [[ "$has_gsc" -eq 1 ]]; then
  gsc_note="included"
else
  gsc_note="not_found"
fi

{
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "legacy_file=$LEGACY_FILE"
  echo "output_csv=$OUT_CSV"
  echo "output_tsv=$MATRIX_TSV"
  echo "top_priority_csv=$TOP_CSV"
  echo "gsc_pages_last90=$gsc_note"
  echo "backlink_file=$BACKLINK_FILE"
} > "$OUT_DIR/redirect_seed_summary.txt"

echo "Redirect seed complete:"
echo "  $OUT_CSV"
echo "  $TOP_CSV"
