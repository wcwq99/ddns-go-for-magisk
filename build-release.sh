#!/usr/bin/env bash
# Build Magisk zips with ddns-go for Android.
# Output:
#   dist/ddns-go-android-arm64.zip   # official GitHub android_arm64 asset
#   dist/ddns-go-android-armv7a.zip  # self-built GOOS=android GOARCH=arm GOARM=7
#                                   # (upstream does not publish android_arm)
#
# Usage:
#   ./build-release.sh
#   ./build-release.sh v6.17.2
#   PROXY=https://ghfast.top/ ./build-release.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${DIST:-$ROOT/dist}"
WORK="${WORK:-$ROOT/.build}"
CORE_REPO="${CORE_REPO:-jeessy2/ddns-go}"
MODULE_VER="${MODULE_VER:-v1.0.0}"
MODULE_CODE="${MODULE_CODE:-100}"
CORE_VER="${1:-${CORE_VER:-}}"
PROXY="${PROXY:-}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] need command: $1" >&2
    exit 1
  }
}

need curl
need tar
need zip
need sed
need grep
need git
need go
need find

normalize_proxy() {
  raw=$(printf '%s' "${1:-}" | tr -d ' \t\r\n')
  [ -z "$raw" ] && { echo ""; return; }
  case "$raw" in
    http://*|https://*)
      echo "${raw%/}/"
      ;;
    //*)
      p="https://${raw#//}"
      echo "${p%/}/"
      ;;
    *)
      p="https://${raw#/}"
      echo "${p%/}/"
      ;;
  esac
}

build_url() {
  gh_url="$1"
  proxy="$2"
  if [ -z "$proxy" ]; then
    echo "$gh_url"
  else
    echo "${proxy}${gh_url}"
  fi
}

PROXY="$(normalize_proxy "$PROXY")"

api_latest() {
  url=$(build_url "https://api.github.com/repos/${CORE_REPO}/releases/latest" "$1")
  curl -fsSL -H "User-Agent: ddns-go-magisk-build" "$url" \
    | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
    | head -1 \
    | sed 's/.*"\(v[^"]*\)".*/\1/'
}

if [[ -z "${CORE_VER}" || "${CORE_VER}" == "latest" ]]; then
  echo "[*] resolve latest core from GitHub..."
  CORE_VER="$(api_latest "$PROXY" || true)"
  if [[ -z "${CORE_VER}" && -z "${PROXY}" ]]; then
    echo "[WARN] direct failed, try https://ghfast.top/"
    PROXY="https://ghfast.top/"
    CORE_VER="$(api_latest "$PROXY" || true)"
  fi
fi
[[ -n "${CORE_VER}" ]] || {
  echo "[ERR] cannot resolve core version" >&2
  exit 1
}

CORE_VER_NUM="${CORE_VER#v}"
CORE_VER="v${CORE_VER_NUM}"

echo "[*] module=${MODULE_VER}  core=${CORE_VER}  repo=${CORE_REPO}"
echo "[*] dist=${DIST}"

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

download_with_fallback() {
  local gh_url="$1"
  local out="$2"
  local url
  url=$(build_url "$gh_url" "$PROXY")
  echo "[*] download $url"
  if curl -fL --retry 3 --retry-delay 2 -o "$out" "$url"; then
    return 0
  fi
  if [[ -z "${PROXY}" ]]; then
    PROXY="https://ghfast.top/"
    url=$(build_url "$gh_url" "$PROXY")
    echo "[WARN] retry $url"
    curl -fL --retry 3 --retry-delay 2 -o "$out" "$url"
    return $?
  fi
  return 1
}

pack_one() {
  local abi="$1"       # arm64 | armv7a
  local core_arch="$2" # android_arm64 | android_armv7
  local source_note="$3"
  local bin_path="$4"
  local stage="$WORK/stage-${abi}"
  local zip_out="$DIST/ddns-go-android-${abi}.zip"

  echo "[*] pack ${abi} (${core_arch})"
  rm -rf "$stage"
  mkdir -p "$stage/META-INF/com/google/android" "$stage/dg/bin"

  cp -f "$ROOT/customize.sh" "$stage/"
  cp -f "$ROOT/service.sh" "$stage/"
  cp -f "$ROOT/uninstall.sh" "$stage/"
  cp -f "$ROOT/README.md" "$stage/"
  cp -f "$ROOT/META-INF/com/google/android/update-binary" "$stage/META-INF/com/google/android/"
  cp -f "$ROOT/META-INF/com/google/android/updater-script" "$stage/META-INF/com/google/android/"
  cp -f "$ROOT/dg/dg.sh" "$stage/dg/"
  cp -f "$ROOT/dg/start.sh" "$stage/dg/"
  cp -f "$ROOT/dg/stop.sh" "$stage/dg/"
  cp -f "$ROOT/dg/restart.sh" "$stage/dg/"
  cp -f "$ROOT/dg/update.sh" "$stage/dg/"
  cp -f "$ROOT/dg/menu.sh" "$stage/dg/"
  cp -f "$bin_path" "$stage/dg/bin/ddns-go"
  chmod 755 "$stage/dg/bin/ddns-go"

  cat >"$stage/module.prop" <<EOF
id=ddns-go
name=ddns-go
version=${MODULE_VER}
versionCode=${MODULE_CODE}
author=wcwq99
description=ddns-go Magisk abi=${abi}. Core: ${CORE_REPO} ${CORE_VER} ${core_arch}. menu: /data/adb/ddns-go/menu.sh
EOF

  cat >"$stage/dg/core.version" <<EOF
core_repo=${CORE_REPO}
core_version=${CORE_VER}
core_arch=${core_arch}
module_abi=${abi}
bundled=1
source=${source_note}
EOF

  rm -f "$zip_out"
  (
    cd "$stage"
    zip -r9 "$zip_out" \
      module.prop customize.sh service.sh uninstall.sh README.md \
      META-INF/com/google/android/update-binary \
      META-INF/com/google/android/updater-script \
      dg/dg.sh dg/start.sh dg/stop.sh dg/restart.sh dg/update.sh dg/menu.sh \
      dg/core.version dg/bin/ddns-go
  )
  echo "[OK] $zip_out ($(wc -c <"$zip_out") bytes)"
}

# ---- arm64: official android_arm64 ----
ASSET="ddns-go_${CORE_VER_NUM}_android_arm64.tar.gz"
GH_URL="https://github.com/${CORE_REPO}/releases/download/${CORE_VER}/${ASSET}"
TGZ="$WORK/$ASSET"
download_with_fallback "$GH_URL" "$TGZ"

EXTRACT="$WORK/extract-arm64"
mkdir -p "$EXTRACT"
tar -xzf "$TGZ" -C "$EXTRACT"
BIN64="$(find "$EXTRACT" -type f -name ddns-go | head -1)"
[[ -n "$BIN64" && -f "$BIN64" ]] || {
  echo "[ERR] ddns-go binary not found in $ASSET" >&2
  exit 1
}
pack_one "arm64" "android_arm64" "github_release_android_arm64" "$BIN64"

# ---- armv7a: self-build (upstream ignores android/arm) ----
SRC="$WORK/src"
echo "[*] clone ${CORE_REPO} @${CORE_VER} for armv7a build..."
git clone --depth 1 --branch "$CORE_VER" "https://github.com/${CORE_REPO}.git" "$SRC"

BIN32="$WORK/ddns-go-armv7a"
echo "[*] go build android/arm GOARM=7 ..."
(
  cd "$SRC"
  CGO_ENABLED=0 GOOS=android GOARCH=arm GOARM=7 \
    go build -trimpath -ldflags "-s -w -X main.version=${CORE_VER}" -o "$BIN32" .
)
[[ -f "$BIN32" ]] || {
  echo "[ERR] go build android/arm failed" >&2
  exit 1
}
if command -v file >/dev/null 2>&1; then
  file "$BIN32" || true
fi
pack_one "armv7a" "android_armv7" "self_build_goos_android_goarch_arm_goarm7" "$BIN32"

cat >"$DIST/build-manifest.txt" <<EOF
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
module_version=${MODULE_VER}
module_version_code=${MODULE_CODE}
core_repo=${CORE_REPO}
core_version=${CORE_VER}
artifacts:
  ddns-go-android-arm64.zip   # official GitHub android_arm64
  ddns-go-android-armv7a.zip  # self-built GOOS=android GOARCH=arm GOARM=7
note: upstream only ships android_arm64. armv7a is cross-compiled from the same tag. Install only ONE abi package (same module id=ddns-go). Device install does not download. Runtime update via update.sh supports proxy.
EOF

echo
echo "======== DONE ========"
ls -lh "$DIST"/ddns-go-android-*.zip
cat "$DIST/build-manifest.txt"
