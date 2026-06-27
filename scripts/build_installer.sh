#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WWW_DIR="/opt/swag/config/www"

echo "▸ Building Plezy installer APK..."
cd "$REPO_ROOT/installer"
./gradlew assembleDebug --no-daemon

APK="$REPO_ROOT/installer/app/build/outputs/apk/debug/app-debug.apk"
echo "▸ Publishing to $WWW_DIR/plezy.apk"
cp "$APK" "$WWW_DIR/plezy.apk"

echo "✓ Done — $(du -h "$WWW_DIR/plezy.apk" | cut -f1) at $WWW_DIR/plezy.apk"
