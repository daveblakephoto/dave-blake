#!/usr/bin/env bash
set -euo pipefail

PORT="${LOCAL_PORT:-4173}"
ROUTE="${1:-/}"
PROFILE_DIR="${HOME}/.cache/dave-blake-chrome-clean"
CHROME_APP="/Applications/Google Chrome.app"

if [[ ! "$ROUTE" =~ ^/ ]]; then
  ROUTE="/$ROUTE"
fi

URL="http://127.0.0.1:${PORT}${ROUTE}"

if [[ ! -d "$CHROME_APP" ]]; then
  echo "Google Chrome.app not found at $CHROME_APP"
  exit 1
fi

mkdir -p "$PROFILE_DIR"

open -na "$CHROME_APP" --args \
  --user-data-dir="$PROFILE_DIR" \
  --disable-extensions \
  --disable-component-extensions-with-background-pages \
  --no-first-run \
  --no-default-browser-check \
  "$URL"

echo "Opened clean Chrome at: $URL"
