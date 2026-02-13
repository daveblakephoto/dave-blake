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
npx imageoptim --jpegmini --imagealpha -- "${files[@]}"
git add -- "${files[@]}"
echo "Optimized and re-staged ${#files[@]} image(s)."
