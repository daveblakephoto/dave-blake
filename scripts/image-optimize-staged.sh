#!/usr/bin/env bash
set -euo pipefail

if [[ "${SKIP_IMAGE_OPTIM:-0}" == "1" ]]; then
  echo "Skipping staged image optimization (SKIP_IMAGE_OPTIM=1)."
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
  case "$file" in
    assets/images/pages/*)
      case "$file" in
        *.jpg|*.jpeg|*.JPG|*.JPEG|*.png|*.PNG)
          files+=("$file")
          ;;
      esac
      ;;
  esac
done < <(git diff --cached --name-only -z --diff-filter=ACMR)

if (( ${#files[@]} == 0 )); then
  echo "No staged page images to optimize."
  exit 0
fi

echo "Optimizing ${#files[@]} staged image(s) with imageoptim-cli..."
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

git add -- "${files[@]}"
echo "Optimization step complete; re-staged ${#files[@]} image(s)."
