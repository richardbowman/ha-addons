#!/usr/bin/env bash
set -euo pipefail

OPTIONS="/data/options.json"

# Read add-on options
TOKEN=$(jq -r '.token // ""' "$OPTIONS")
CONCURRENT=$(jq -r '.concurrent // 5' "$OPTIONS")
TIMEOUT=$(jq -r '.timeout // 30000' "$OPTIONS")

[ -n "$TOKEN" ] && export TOKEN
export CONCURRENT
export TIMEOUT
export PORT=3000
export HOST=0.0.0.0

echo "[browserless] Starting with CONCURRENT=$CONCURRENT TIMEOUT=$TIMEOUT PORT=$PORT TOKEN=${TOKEN:+(set)}"

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
        cd "$(dirname "$entry_path")"
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
