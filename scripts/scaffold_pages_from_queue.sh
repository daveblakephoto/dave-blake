#!/usr/bin/env bash
set -euo pipefail

PHASE0_DIR="${1:-data/migration/phase0}"
LIMIT="${2:-10}"
SITE_ROOT="${3:-.}"
CANONICAL_HOST="${CANONICAL_HOST:-https://www.dave-blake.com}"
OVERWRITE="${OVERWRITE:-0}"

QUEUE_TSV="$PHASE0_DIR/page_migration_queue.tsv"
REPORT_TSV="$PHASE0_DIR/scaffold_top_pages.tsv"

if [[ ! -f "$QUEUE_TSV" ]]; then
  echo "ERROR: missing queue file: $QUEUE_TSV" >&2
  exit 1
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [[ "$LIMIT" -lt 1 ]]; then
  echo "ERROR: limit must be a positive integer. Got: $LIMIT" >&2
  exit 1
fi

mkdir -p "$PHASE0_DIR"

TMP_INPUT="$(mktemp)"
trap 'rm -f "$TMP_INPUT"' EXIT

awk -F'\t' -v limit="$LIMIT" '
NR == 1 { next }
$11 == "migrate_page_content" {
  print $0
  n++
  if (n >= limit) exit
}
' "$QUEUE_TSV" > "$TMP_INPUT"

if [[ ! -s "$TMP_INPUT" ]]; then
  echo "ERROR: no rows found to scaffold in: $QUEUE_TSV" >&2
  exit 1
fi

title_case_slug() {
  local slug="$1"
  slug="${slug//-/ }"
  awk '
  {
    for (i = 1; i <= NF; i++) {
      $i = toupper(substr($i, 1, 1)) substr($i, 2)
    }
    print
  }' <<< "$slug"
}

printf "rank\tpage_path\tcanonical_url\toutput_file\tclicks\timpressions\tpriority\tstatus\n" > "$REPORT_TSV"

rank=0
while IFS=$'\t' read -r page_url page_path clicks impressions _in_legacy _legacy_count _legacy_example priority _reason _target _action; do
  rank=$((rank + 1))

  normalized_path="$page_path"
  if [[ -z "$normalized_path" ]]; then
    normalized_path="/"
  fi
  if [[ "$normalized_path" != "/" ]]; then
    normalized_path="${normalized_path%/}"
  fi

  if [[ "$normalized_path" == "/" ]]; then
    canonical_url="${CANONICAL_HOST}/"
    output_file="$SITE_ROOT/index.html"
    page_title="Home"
  else
    canonical_url="${CANONICAL_HOST}${normalized_path}/"
    output_file="$SITE_ROOT/${normalized_path#/}/index.html"
    last_segment="${normalized_path##*/}"
    page_title="$(title_case_slug "$last_segment")"
  fi

  mkdir -p "$(dirname "$output_file")"

  status="created"
  if [[ -f "$output_file" ]]; then
    if [[ "$OVERWRITE" == "1" ]]; then
      status="overwritten"
    else
      status="exists"
    fi
  fi

  if [[ "$status" != "exists" ]]; then
    cat > "$output_file" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${page_title} | Dave Blake</title>
  <meta name="description" content="TODO: write final meta description for ${normalized_path}">
  <meta name="robots" content="noindex, nofollow">
  <link rel="canonical" href="${canonical_url}">
</head>
<body>
  <main>
    <h1>${page_title}</h1>
    <p>Scaffolded placeholder page for migration. Replace with final content.</p>
    <p>Source URL benchmark: <a href="${page_url}">${page_url}</a></p>
    <p>Priority: ${priority}. Last 90 days clicks: ${clicks}. Impressions: ${impressions}.</p>
  </main>
</body>
</html>
EOF
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$rank" "$normalized_path" "$canonical_url" "$output_file" "$clicks" "$impressions" "$priority" "$status" \
    >> "$REPORT_TSV"
done < "$TMP_INPUT"

echo "Scaffold complete."
echo "  report: $REPORT_TSV"
