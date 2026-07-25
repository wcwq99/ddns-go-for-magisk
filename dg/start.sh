#!/system/bin/sh
# start ddns-go
# usage: sh start.sh

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"

if [ -f "$DG_HOME/dg.sh" ]; then
  exec /system/bin/sh "$DG_HOME/dg.sh" start
fi
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$HERE/dg.sh" ]; then
  exec /system/bin/sh "$HERE/dg.sh" start
fi

printf '%s\n' "[ERR] dg.sh not found" >&2
exit 1
