#!/bin/sh
# Pack Magisk zip WITHOUT binary (debug only).
# For release with bundled binary, use: ./build-release.sh
set -e
cd "$(dirname "$0")"
mkdir -p dist
OUT="dist/ddns-go-android-nocore.zip"
rm -f "$OUT"
echo "[WARN] packing script-only zip (no binary). Prefer build-release.sh"
zip -r "$OUT" \
  module.prop customize.sh service.sh uninstall.sh README.md \
  META-INF/com/google/android/update-binary \
  META-INF/com/google/android/updater-script \
  dg/dg.sh dg/start.sh dg/stop.sh dg/restart.sh dg/update.sh dg/menu.sh
echo "OK: $OUT"
