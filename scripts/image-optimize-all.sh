#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-assets/images/pages}"

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "No directory found at $ROOT_DIR; skipping optimization."
  exit 0
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required. Install Node.js/npm first."
  exit 1
fi

if ! npx --no-install imageoptim --version >/dev/null 2>&1; then
  echo "imageoptim-cli is not installed locally. Run: npm install"
  exit 1
fi

declare -a files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$ROOT_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0)

if (( ${#files[@]} == 0 )); then
  echo "No JPG/PNG images found under $ROOT_DIR."
  exit 0
fi

echo "Optimizing ${#files[@]} image(s) with imageoptim-cli..."
npx imageoptim --jpegmini --imagealpha -- "${files[@]}"
echo "Optimization complete."
