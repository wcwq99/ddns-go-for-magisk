#!/system/bin/sh
# update ddns-go binary from GitHub (android_arm64)
# usage: sh update.sh [version|latest] [proxy]
#   version: v6.17.2 / 6.17.2 / latest (default latest)
#   proxy:   optional. host or http(s) base, e.g. ghfast.top / https://ghfast.top/
#            if direct GitHub fails, will prompt; Enter = https://ghfast.top/
#
# proxy URL form:
#   https://ghfast.top/https://github.com/jeessy2/ddns-go/releases/download/...

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"

if [ -f "$DG_HOME/dg.sh" ]; then
  exec /system/bin/sh "$DG_HOME/dg.sh" update "$@"
fi
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$HERE/dg.sh" ]; then
  exec /system/bin/sh "$HERE/dg.sh" update "$@"
fi

printf '%s\n' "[ERR] dg.sh not found" >&2
exit 1
