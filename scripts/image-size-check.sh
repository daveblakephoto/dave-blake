#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-assets/images/pages}"
MAX_BYTES="${MAX_IMAGE_BYTES:-2097152}"

if [[ ! "$MAX_BYTES" =~ ^[0-9]+$ ]]; then
  echo "MAX_IMAGE_BYTES must be an integer (bytes)."
  exit 1
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "No directory found at $ROOT_DIR; skipping size check."
  exit 0
fi

get_file_size_bytes() {
  local file="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c%s "$file"
  else
    stat -f%z "$file"
  fi
}

declare -a offenders=()
while IFS= read -r -d '' file; do
  size_bytes="$(get_file_size_bytes "$file")"
  if (( size_bytes > MAX_BYTES )); then
    size_mb="$(awk -v b="$size_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')"
    offenders+=("${size_mb} MB  ${file}")
  fi
done < <(find "$ROOT_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0)

if (( ${#offenders[@]} > 0 )); then
  limit_mb="$(awk -v b="$MAX_BYTES" 'BEGIN { printf "%.2f", b/1024/1024 }')"
  echo "Image size check failed. Files larger than ${limit_mb} MB:"
  printf ' - %s\n' "${offenders[@]}"
  echo "Override threshold for one run: MAX_IMAGE_BYTES=3145728 npm run image:check"
  exit 1
fi

limit_mb="$(awk -v b="$MAX_BYTES" 'BEGIN { printf "%.2f", b/1024/1024 }')"
echo "Image size check passed (<= ${limit_mb} MB)."
