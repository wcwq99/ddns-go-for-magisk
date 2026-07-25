#!/system/bin/sh
# stop ddns-go
# usage: sh stop.sh

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"

if [ -f "$DG_HOME/dg.sh" ]; then
  exec /system/bin/sh "$DG_HOME/dg.sh" stop
fi
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$HERE/dg.sh" ]; then
  exec /system/bin/sh "$HERE/dg.sh" stop
fi

printf '%s\n' "[ERR] dg.sh not found" >&2
exit 1
