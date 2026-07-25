# Local packaging is DISABLED.
# Dual-arch Magisk zips (arm64 + armv7a) are built only on GitHub Actions.
#
# Why:
#   - arm64: download official android_arm64 asset
#   - armv7a: needs Android NDK external linking (GOOS=android GOARCH=arm)
#     Local Windows cross-compile is fragile; CI handles NDK + publish.
#
# How to build / get zips:
#   1. git push origin main
#   2. GitHub → Actions → "Android Module" (auto on push, or Run workflow)
#   3. Download from Actions Artifacts or GitHub Releases
#
# Script-only zip (no binary) for debug:
#   .\pack.ps1

$ErrorActionPreference = "Stop"
Write-Host @"
[INFO] Local dual-arch build is disabled.

Use cloud build:
  - push to main  -> workflow "Android Module"
  - or Actions → Android Module → Run workflow

Outputs (from CI):
  dist/ddns-go-android-arm64.zip
  dist/ddns-go-android-armv7a.zip

Optional local script-only pack (no binary):
  .\pack.ps1
"@
exit 0
