#!/usr/bin/env bash
set -euo pipefail

PHASE0_DIR="${1:-data/migration/phase0}"
LIMIT="${2:-10}"
SOURCE_DIR="${SOURCE_DIR:-/Users/daveblake/site-backups/dave-blake-sspro/dave-blake.com}"
OUT_ROOT="${OUT_ROOT:-data/migration/page-assets}"

QUEUE_TSV="$PHASE0_DIR/page_migration_queue.tsv"
PAGE_MANIFEST_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/page_asset_manifest.sh"
RUN_SUMMARY="$PHASE0_DIR/page_asset_manifest_run.tsv"

if [[ ! -f "$QUEUE_TSV" ]]; then
  echo "ERROR: missing $QUEUE_TSV" >&2
  exit 1
fi
if [[ ! -x "$PAGE_MANIFEST_SCRIPT" ]]; then
  echo "ERROR: missing executable script $PAGE_MANIFEST_SCRIPT" >&2
  exit 1
fi
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: missing SOURCE_DIR $SOURCE_DIR" >&2
  exit 1
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: LIMIT must be a positive integer." >&2
  exit 1
fi

echo -e "rank\tpage_path\tstatus\ttotal_refs\texisting_refs\tmissing_refs\tmanifest_dir" > "$RUN_SUMMARY"

rank=0
tail -n +2 "$QUEUE_TSV" | while IFS=$'\t' read -r _page_url page_path _clicks _impr _inlegacy _cand _legacyex _prio _reason _target _action; do
  rank=$((rank + 1))
  if [[ "$rank" -gt "$LIMIT" ]]; then
    break
  fi

  status="ok"
  total_refs="0"
  existing_refs="0"
  missing_refs="0"

  if SOURCE_DIR="$SOURCE_DIR" OUT_ROOT="$OUT_ROOT" bash "$PAGE_MANIFEST_SCRIPT" "$page_path" >/tmp/page_manifest_run.out 2>/tmp/page_manifest_run.err; then
    slug="$(echo "$page_path" | sed -E 's#^/##; s#/$##; s#[^A-Za-z0-9]+#-#g; s#^-+##; s#-+$##')"
    if [[ -z "$slug" ]]; then
      slug="home"
    fi
    manifest_dir="$OUT_ROOT/$slug"
    summary_file="$manifest_dir/summary.txt"
    if [[ -f "$summary_file" ]]; then
      total_refs="$(awk -F= '/^total_refs=/{print $2}' "$summary_file" | tr -d '\r')"
      existing_refs="$(awk -F= '/^existing_refs=/{print $2}' "$summary_file" | tr -d '\r')"
      missing_refs="$(awk -F= '/^missing_refs=/{print $2}' "$summary_file" | tr -d '\r')"
    fi
  else
    status="failed"
    slug="$(echo "$page_path" | sed -E 's#^/##; s#/$##; s#[^A-Za-z0-9]+#-#g; s#^-+##; s#-+$##')"
    if [[ -z "$slug" ]]; then
      slug="home"
    fi
    manifest_dir="$OUT_ROOT/$slug"
  fi

  echo -e "${rank}\t${page_path}\t${status}\t${total_refs}\t${existing_refs}\t${missing_refs}\t${manifest_dir}" >> "$RUN_SUMMARY"
done

echo "Page asset manifests generated from queue."
echo "Summary: $RUN_SUMMARY"

