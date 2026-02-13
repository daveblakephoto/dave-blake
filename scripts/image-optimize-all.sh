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
declare -a optim_flags=()
if [[ -d "/Applications/JPEGmini.app" || -d "/Applications/JPEGmini Pro.app" || -d "$HOME/Applications/JPEGmini.app" || -d "$HOME/Applications/JPEGmini Pro.app" ]]; then
  optim_flags+=(--jpegmini)
else
  echo "JPEGmini app not found; skipping --jpegmini optimizer."
fi

if [[ -d "/Applications/ImageAlpha.app" || -d "$HOME/Applications/ImageAlpha.app" ]]; then
  optim_flags+=(--imagealpha)
else
  echo "ImageAlpha app not found; skipping --imagealpha optimizer."
fi

if ! npx imageoptim "${optim_flags[@]}" -- "${files[@]}"; then
  if [[ "${IMAGE_OPTIM_STRICT:-0}" == "1" ]]; then
    echo "Image optimization failed (IMAGE_OPTIM_STRICT=1)."
    exit 1
  fi
  echo "Warning: image optimization failed; continuing with existing files."
fi

echo "Optimization complete."
