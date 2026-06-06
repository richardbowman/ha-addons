#!/usr/bin/env bash
set -euo pipefail

OPTIONS="/data/options.json"

# Read add-on options
TOKEN=$(jq -r '.token // ""' "$OPTIONS")
CONCURRENT=$(jq -r '.concurrent // 5' "$OPTIONS")
TIMEOUT=$(jq -r '.timeout // 90000' "$OPTIONS")
KEEP_ALIVE=$(jq -r '.keep_alive // false' "$OPTIONS")

[ -n "$TOKEN" ] && export TOKEN
export CONCURRENT
export TIMEOUT
export PORT=3000
export HOST=0.0.0.0

# Persistent Chrome profile — lives in the add-on's /data volume so it
# survives restarts. When KEEP_ALIVE=true Browserless reuses one Chrome
# instance, which means cookies/sessions persist for the whole uptime.
# The profile dir is also passed back to callers via /config so that
# per-request userDataDir can point at it for fully persistent cookies.
PROFILE_DIR="/data/chrome-profile"
mkdir -p "$PROFILE_DIR"
export DATA="/data/browserless-data-dirs"
mkdir -p "$DATA"

if [ "$KEEP_ALIVE" = "true" ]; then
  export KEEP_ALIVE=true
  echo "[browserless] KEEP_ALIVE enabled — Chrome stays alive between requests, profile: $PROFILE_DIR"
fi

echo "[browserless] Starting with CONCURRENT=$CONCURRENT TIMEOUT=$TIMEOUT PORT=$PORT KEEP_ALIVE=${KEEP_ALIVE:-false} TOKEN=${TOKEN:+(set)}"

# Try known binary locations first
if command -v browserless &>/dev/null; then
    exec browserless
fi

# Try well-known paths for the browserless v2 image
for entry_path in \
    "/usr/src/app/build/index.js" \
    "/usr/src/app/index.js" \
    "/app/build/index.js" \
    "/app/index.js" \
    "/usr/local/bin/browserless"; do
    if [ -f "$entry_path" ]; then
        echo "[browserless] Found entry point: $entry_path"
        # cd to app root (parent of build/dist), not the build dir itself,
        # so node_modules resolution works correctly
        DIR=$(dirname "$entry_path")
        if [[ "$DIR" == */build ]] || [[ "$DIR" == */dist ]]; then
            cd "$(dirname "$DIR")"
        else
            cd "$DIR"
        fi
        exec node "$entry_path"
    fi
done

# Try resolving the npm package from common install locations
for pkgdir in \
    "/usr/src/app" \
    "/app" \
    "/usr/local/lib/node_modules/@browserless.io/browserless" \
    "/usr/lib/node_modules/@browserless.io/browserless"; do
    if [ -f "$pkgdir/package.json" ]; then
        echo "[browserless] Found package.json at $pkgdir"
        cd "$pkgdir"
        # Run via npm start (inherits our exported env vars)
        exec npm start --prefix "$pkgdir"
    fi
done

# Last resort: search the filesystem
echo "[browserless] Searching for entry point..."
ENTRY=$(find / -maxdepth 10 -name "index.js" 2>/dev/null \
    | grep -i "browserless\|bless" \
    | grep -v "node_modules/mocha\|node_modules/jest\|\.test\." \
    | head -1 || true)

if [ -n "$ENTRY" ] && [ -f "$ENTRY" ]; then
    echo "[browserless] Found via search: $ENTRY"
    cd "$(dirname "$ENTRY")"
    exec node "$ENTRY"
fi

echo "[browserless] ERROR: Could not locate browserless entry point" >&2
echo "[browserless] Listing /usr/src/app:" >&2
ls /usr/src/app/ 2>&1 >&2 || true
echo "[browserless] Listing /app:" >&2
ls /app/ 2>&1 >&2 || true
exit 1
