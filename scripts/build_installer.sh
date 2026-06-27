#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WWW_DIR="${WWW_DIR:-/opt/swag/config/www}"

[[ -d "$WWW_DIR" ]] || { echo "ERROR: publish target '$WWW_DIR' not found — is the swag container running?"; exit 1; }

echo "▸ Building Plezy installer APK..."
cd "$REPO_ROOT/installer"
./gradlew assembleDebug --no-daemon

APK="$REPO_ROOT/installer/app/build/outputs/apk/debug/app-debug.apk"
[[ -f "$APK" ]] || { echo "ERROR: expected APK not found at $APK"; exit 1; }

echo "▸ Publishing to $WWW_DIR/plezy.apk"
cp "$APK" "$WWW_DIR/plezy.apk"

echo "✓ Done — $(du -h "$WWW_DIR/plezy.apk" 2>/dev/null | cut -f1 || echo "?") at $WWW_DIR/plezy.apk"
