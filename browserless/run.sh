#!/usr/bin/env bash
set -euo pipefail

OPTIONS="/data/options.json"

# Read add-on options
TOKEN=$(jq -r '.token // ""' "$OPTIONS")
CONCURRENT=$(jq -r '.concurrent // 5' "$OPTIONS")
TIMEOUT=$(jq -r '.timeout // 30000' "$OPTIONS")

# Only set TOKEN if one was provided — browserless runs open if TOKEN is empty
if [ -n "$TOKEN" ]; then
    export TOKEN
fi

export CONCURRENT
export TIMEOUT
export PORT=3000
export HOST=0.0.0.0

echo "[browserless] Starting with CONCURRENT=$CONCURRENT TIMEOUT=$TIMEOUT PORT=$PORT TOKEN=${TOKEN:+(set)}"

# Locate and launch the browserless entry point
if command -v browserless &>/dev/null; then
    exec browserless
elif [ -f /usr/local/bin/browserless ]; then
    exec /usr/local/bin/browserless
else
    # Resolve via Node module system
    ENTRY=$(node -e "console.log(require.resolve('@browserless.io/browserless/build/index.js'))" 2>/dev/null || true)
    if [ -n "$ENTRY" ]; then
        exec node "$ENTRY"
    else
        echo "[browserless] ERROR: Could not locate browserless entry point" >&2
        exit 1
    fi
fi
