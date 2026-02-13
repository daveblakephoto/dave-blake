#!/usr/bin/env bash
set -euo pipefail

if [[ "${SKIP_IMAGE_OPTIM:-0}" == "1" ]]; then
  echo "Skipping staged image optimization (SKIP_IMAGE_OPTIM=1)."
  exit 0
fi

find_jpegmini_app() {
  if [[ -d "/Applications/JPEGmini Pro.app" ]]; then
    echo "JPEGmini Pro"
    return 0
  fi
  if [[ -d "/Applications/JPEGmini.app" ]]; then
    echo "JPEGmini"
    return 0
  fi
  if [[ -d "$HOME/Applications/JPEGmini Pro.app" ]]; then
    echo "JPEGmini Pro"
    return 0
  fi
  if [[ -d "$HOME/Applications/JPEGmini.app" ]]; then
    echo "JPEGmini"
    return 0
  fi
  return 1
}

sum_file_sizes() {
  local total=0
  local file=0
  for file in "$@"; do
    total=$((total + $(stat -f%z "$file")))
  done
  echo "$total"
}

wait_for_app_idle() {
  local app_name="$1"
  local timeout_secs="$2"
  local idle_target=3
  local idle_count=0
  local elapsed=0
  local interval=2

  while (( elapsed < timeout_secs )); do
    pids="$(pgrep -x "$app_name" || true)"
    if [[ -z "$pids" ]]; then
      return 0
    fi

    cpu_sum="$(ps -p "$pids" -o %cpu= | awk '{sum+=$1} END {printf "%.1f", sum+0}')"
    cpu_int="${cpu_sum%.*}"
    if (( cpu_int < 1 )); then
      idle_count=$((idle_count + 1))
      if (( idle_count >= idle_target )); then
        return 0
      fi
    else
      idle_count=0
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  return 1
}

declare -a files=()
declare -a jpeg_files=()
while IFS= read -r -d '' file; do
  case "$file" in
    assets/images/pages/*)
      case "$file" in
        *.jpg|*.jpeg|*.JPG|*.JPEG)
          files+=("$file")
          jpeg_files+=("$file")
          ;;
        *.png|*.PNG)
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

if (( ${#jpeg_files[@]} > 0 )); then
  jpegmini_app="$(find_jpegmini_app || true)"
  if [[ -n "${jpegmini_app:-}" ]]; then
    before_bytes="$(sum_file_sizes "${jpeg_files[@]}")"
    echo "Optimizing ${#jpeg_files[@]} staged JPEG(s) with ${jpegmini_app}..."
    open -a "$jpegmini_app" -- "${jpeg_files[@]}"
    timeout_secs=$((20 + (${#jpeg_files[@]} * 4)))
    if ! wait_for_app_idle "$jpegmini_app" "$timeout_secs"; then
      if [[ "${IMAGE_OPTIM_STRICT:-0}" == "1" ]]; then
        echo "JPEGmini did not reach idle state before timeout (IMAGE_OPTIM_STRICT=1)."
        exit 1
      fi
      echo "Warning: JPEGmini did not reach idle state before timeout; continuing."
    fi
    after_bytes="$(sum_file_sizes "${jpeg_files[@]}")"
    saved_bytes=$((before_bytes - after_bytes))
    saved_mb="$(awk -v b="$saved_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')"
    echo "JPEGmini complete. Savings: ${saved_mb} MB."
  else
    echo "JPEGmini app not found; skipping JPEG optimization."
  fi
fi

if (( ${#files[@]} > ${#jpeg_files[@]} )); then
  echo "PNG optimization is currently skipped in pre-commit."
fi

git add -- "${files[@]}"
echo "Optimization step complete; re-staged ${#files[@]} image(s)."
