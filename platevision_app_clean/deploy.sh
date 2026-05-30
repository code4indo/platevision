#!/bin/bash
# ============================================================
# PlateVisionAI Deploy Script
# Handles: Flutter build → cache-busting → deploy → CF purge
# Usage: ./deploy.sh [--skip-build] [--skip-purge]
# ============================================================
set -euo pipefail

PROJECT_DIR="/media/lambda_one/DFSSD04/project/healtcare/platevision_app_clean"
WEB_ROOT="/var/www/platevision"
ARCHIVE_DIR="/media/lambda_one/DFSSD04/project/healtcare/platevision-web"
SECRETS_FILE="$PROJECT_DIR/.secrets/cloudflare.env"

SKIP_BUILD=false
SKIP_PURGE=false
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    --skip-purge) SKIP_PURGE=true ;;
  esac
done

# Load Cloudflare credentials
if [ -f "$SECRETS_FILE" ]; then
  source "$SECRETS_FILE"
else
  CF_ZONE_ID=""
  CF_AUTH_EMAIL=""
  CF_AUTH_KEY=""
  CF_DOMAIN="platevision.jatnikonm.tech"
fi

echo "============================================"
echo " PlateVisionAI Deploy Script"
echo "============================================"
echo "Skip build: $SKIP_BUILD"
echo "Skip purge: $SKIP_PURGE"
echo "CF Email:   ${CF_AUTH_EMAIL:-not set}"
echo ""

# ── Step 1: Flutter Build ──
if [ "$SKIP_BUILD" = false ]; then
  echo "[1/5] Building Flutter web..."
  cd "$PROJECT_DIR"
  flutter clean 2>&1 | tail -1
  flutter pub get 2>&1 | tail -1
  flutter build web --release --no-wasm-dry-run 2>&1 | tail -3
  echo "  Done: Build complete"
else
  echo "[1/5] Skipping build (--skip-build)"
fi

BUILD_DIR="$PROJECT_DIR/build/web"
TIMESTAMP=$(date +%s)
VERSION="v$(date +%Y%m%d%H%M)"

echo ""
echo "  Deploy version: $VERSION"
echo "  Cache buster:   $TIMESTAMP"
echo ""

# ── Step 2: Inject cache-busting into index.html ──
echo "[2/5] Injecting cache-busting into index.html..."
INDEX_HTML="$BUILD_DIR/index.html"

# Add no-cache meta tags after charset (if not already present)
if ! grep -q 'no-cache, no-store' "$INDEX_HTML"; then
  sed -i '/<meta charset="UTF-8">/a\  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n  <meta http-equiv="Pragma" content="no-cache">\n  <meta http-equiv="Expires" content="0">' "$INDEX_HTML"
fi

# Add cache buster to flutter_bootstrap.js script tag
sed -i "s|flutter_bootstrap.js|flutter_bootstrap.js?v=${TIMESTAMP}|g" "$INDEX_HTML"

echo "  Done: index.html patched"

# ── Step 3: Inject cache-busting into flutter_bootstrap.js ──
echo "[3/5] Injecting cache-busting into flutter_bootstrap.js..."
BOOTSTRAP_JS="$BUILD_DIR/flutter_bootstrap.js"

# Replace mainJsPath in buildConfig
sed -i "s|mainJsPath\":\"main.dart.js|mainJsPath\":\"main.dart.js?v=${TIMESTAMP}|g" "$BOOTSTRAP_JS"

# Replace fallback entrypointUrl
sed -i "s|entrypointUrl:n=c(\"main.dart.js\")|entrypointUrl:n=c(\"main.dart.js?v=${TIMESTAMP}\")|g" "$BOOTSTRAP_JS"

# Replace default mainJsPath fallback  
sed -i 's|e.mainJsPath??"main.dart.js"|e.mainJsPath??"main.dart.js?v='""'"|g' "$BOOTSTRAP_JS"

echo "  Done: flutter_bootstrap.js patched"

# Verify patches
echo "  Verify:"
echo "    bootstrap ref: $(grep -o 'flutter_bootstrap.js?v=[0-9]*' "$INDEX_HTML" | head -1)"
echo "    mainJsPath:    $(grep -o 'mainJsPath":"main.dart.js?v=[0-9]*' "$BOOTSTRAP_JS" | head -1)"

# ── Step 4: Deploy to web root and archive ──
echo "[4/5] Deploying to web root..."
sudo rsync -av --delete "$BUILD_DIR/" "$WEB_ROOT/"
rsync -av --delete "$BUILD_DIR/" "$ARCHIVE_DIR/"
sudo nginx -t 2>&1 | tail -1
sudo systemctl reload nginx
echo "  Done: Deployed and nginx reloaded"

# ── Step 5: Purge Cloudflare cache ──
if [ "$SKIP_PURGE" = false ] && [ -n "$CF_AUTH_EMAIL" ] && [ -n "$CF_AUTH_KEY" ] && [ -n "$CF_ZONE_ID" ]; then
  echo "[5/5] Purging Cloudflare cache..."
  
  RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/purge_cache" \
    -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
    -H "X-Auth-Key: ${CF_AUTH_KEY}" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything":true}' 2>/dev/null || echo '{}')
  
  if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "  Done: Cloudflare cache purged (full zone)"
  else
    echo "  WARN: Cloudflare purge failed"
    echo "  Response: $RESPONSE"
  fi
else
  echo "[5/5] Skipping Cloudflare purge (credentials not set or --skip-purge)"
  echo "  Note: Cache-busting query strings ensure new versions load correctly."
fi

# ── Verify ──
echo ""
echo "============================================"
echo " Deploy Verification"
echo "============================================"

echo ""
echo "Local nginx:"
curl -sI http://localhost:8098/index.html 2>/dev/null | grep -E 'cache-control|etag' | head -2

echo ""
echo "Cloudflare:"
curl -sI "https://${CF_DOMAIN}/main.dart.js?v=${TIMESTAMP}" 2>/dev/null | grep -E 'cache-control|cf-cache-status|etag' | head -3

echo ""
echo "Deploy complete! Version: $VERSION"
echo "URL: https://$CF_DOMAIN/"
echo "============================================"
