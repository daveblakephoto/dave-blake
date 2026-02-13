#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SOURCE_DIR:-/Users/daveblake/site-backups/dave-blake-sspro/dave-blake.com}"
OUT_ROOT="${OUT_ROOT:-data/migration/page-assets}"
PAGE_REF="${1:-}"

if [[ -z "$PAGE_REF" ]]; then
  cat >&2 <<'EOF'
Usage:
  bash scripts/page_asset_manifest.sh <page-path-or-url>

Examples:
  bash scripts/page_asset_manifest.sh /
  bash scripts/page_asset_manifest.sh /story/barungas-next-top-model-2025
  bash scripts/page_asset_manifest.sh https://dave-blake.com/blog
EOF
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

BACKUP_ROOT="$(cd "$SOURCE_DIR/.." && pwd)"

normalize_page_path() {
  local ref="$1"
  local path="$ref"
  path="${path#http://}"
  path="${path#https://}"
  if [[ "$path" != "$ref" ]]; then
    path="/${path#*/}"
  fi
  path="${path%%#*}"
  path="${path%%\?*}"
  if [[ -z "$path" ]]; then
    path="/"
  fi
  if [[ "$path" != /* ]]; then
    path="/$path"
  fi
  echo "$path"
}

resolve_html_file() {
  local page_path="$1"
  local rel="${page_path#/}"

  if [[ "$page_path" == "/" ]]; then
    echo "$SOURCE_DIR/index.html"
    return 0
  fi

  local c1="$SOURCE_DIR/$rel"
  local c2="$SOURCE_DIR/$rel.html"
  local c3="$SOURCE_DIR/$rel/index.html"

  if [[ -f "$c1" ]]; then
    echo "$c1"
    return 0
  fi
  if [[ -f "$c2" ]]; then
    echo "$c2"
    return 0
  fi
  if [[ -f "$c3" ]]; then
    echo "$c3"
    return 0
  fi

  return 1
}

PAGE_PATH="$(normalize_page_path "$PAGE_REF")"
HTML_FILE="$(resolve_html_file "$PAGE_PATH" || true)"

if [[ -z "$HTML_FILE" || ! -f "$HTML_FILE" ]]; then
  echo "ERROR: could not resolve HTML file for page: $PAGE_REF" >&2
  exit 1
fi

PAGE_SLUG="$(echo "$PAGE_PATH" | sed -E 's#^/##; s#/$##; s#[^A-Za-z0-9]+#-#g; s#^-+##; s#-+$##')"
if [[ -z "$PAGE_SLUG" ]]; then
  PAGE_SLUG="home"
fi

OUT_DIR="$OUT_ROOT/$PAGE_SLUG"
mkdir -p "$OUT_DIR"

RAW_REFS="$OUT_DIR/asset_refs_raw.txt"
ASSET_MANIFEST_TSV="$OUT_DIR/asset_manifest.tsv"
ASSET_EXISTS_TSV="$OUT_DIR/asset_manifest_existing.tsv"
ASSET_MISSING_TSV="$OUT_DIR/asset_manifest_missing.tsv"
SUMMARY_TXT="$OUT_DIR/summary.txt"

perl -0777 -ne '
while (/(?:src|href|data-src|data-image|poster)\s*=\s*["\x27]([^"\x27]+)["\x27]/g) {
  print "$1\n";
}
while (/srcset\s*=\s*["\x27]([^"\x27]+)["\x27]/g) {
  my $srcset = $1;
  my @parts = split /,/, $srcset;
  for my $p (@parts) {
    $p =~ s/^\s+|\s+$//g;
    $p =~ s/\s+\d+(?:w|x)$//;
    print "$p\n" if length($p);
  }
}
' "$HTML_FILE" \
  | sed 's/&amp;/\&/g' \
  | sed '/^[[:space:]]*$/d' \
  | sed '/^#/d' \
  | sed '/^javascript:/d' \
  | sed '/^mailto:/d' \
  | sed '/^data:/d' \
  | sort -u > "$RAW_REFS"

{
  echo -e "asset_ref\tkind\thost\tlocal_candidate\texists"
  while IFS= read -r ref; do
    kind=""
    host=""
    local_candidate=""

    if [[ "$ref" =~ ^https?:// ]]; then
      kind="absolute"
      host_path="${ref#http://}"
      host_path="${host_path#https://}"
      host="${host_path%%/*}"
      path_part="/${host_path#*/}"
      if [[ "$host_path" == "$host" ]]; then
        path_part="/"
      fi
      local_candidate="$BACKUP_ROOT/$host$path_part"
    elif [[ "$ref" =~ ^// ]]; then
      kind="protocol-relative"
      host_path="${ref#//}"
      host="${host_path%%/*}"
      path_part="/${host_path#*/}"
      if [[ "$host_path" == "$host" ]]; then
        path_part="/"
      fi
      local_candidate="$BACKUP_ROOT/$host$path_part"
    elif [[ "$ref" =~ ^/ ]]; then
      kind="root-relative"
      host="dave-blake.com"
      local_candidate="$SOURCE_DIR$ref"
    else
      kind="relative"
      host="dave-blake.com"
      local_candidate="$(dirname "$HTML_FILE")/$ref"
    fi

    exists="0"
    if [[ -f "$local_candidate" ]]; then
      exists="1"
    fi

    echo -e "${ref}\t${kind}\t${host}\t${local_candidate}\t${exists}"
  done < "$RAW_REFS"
} > "$ASSET_MANIFEST_TSV"

awk -F'\t' 'NR == 1 || $5 == "1"' "$ASSET_MANIFEST_TSV" > "$ASSET_EXISTS_TSV"
awk -F'\t' 'NR == 1 || $5 == "0"' "$ASSET_MANIFEST_TSV" > "$ASSET_MISSING_TSV"

total_refs="$(($(wc -l < "$ASSET_MANIFEST_TSV") - 1))"
existing_refs="$(($(wc -l < "$ASSET_EXISTS_TSV") - 1))"
missing_refs="$(($(wc -l < "$ASSET_MISSING_TSV") - 1))"

{
  echo "page_ref=$PAGE_REF"
  echo "page_path=$PAGE_PATH"
  echo "source_html=$HTML_FILE"
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "total_refs=$total_refs"
  echo "existing_refs=$existing_refs"
  echo "missing_refs=$missing_refs"
} > "$SUMMARY_TXT"

echo "Asset manifest created:"
echo "  $ASSET_MANIFEST_TSV"
echo "  $ASSET_EXISTS_TSV"
echo "  $ASSET_MISSING_TSV"

