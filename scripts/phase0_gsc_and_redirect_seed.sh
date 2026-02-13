#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-data/migration/phase0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$OUT_DIR"

echo "Phase 0: generating redirect seed from legacy URL inventory."

if bash "$SCRIPT_DIR/gsc_export.sh" "$OUT_DIR"; then
  echo "GSC export completed."
else
  status=$?
  if [[ "$status" -eq 2 ]]; then
    echo "GSC export skipped (token not configured). Continuing with heuristic redirect seed."
  else
    echo "GSC export failed with status ${status}. Aborting." >&2
    exit "$status"
  fi
fi

bash "$SCRIPT_DIR/seed_redirect_matrix.sh" \
  "$OUT_DIR/legacy_urls.txt" \
  "$OUT_DIR/redirect_matrix_seed.csv"

echo "Phase 0 seed artifacts updated in: $OUT_DIR"

