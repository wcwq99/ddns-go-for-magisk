#!/system/bin/sh
# restart ddns-go
# usage: sh restart.sh

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"

if [ -f "$DG_HOME/dg.sh" ]; then
  exec /system/bin/sh "$DG_HOME/dg.sh" restart
fi
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$HERE/dg.sh" ]; then
  exec /system/bin/sh "$HERE/dg.sh" restart
fi

STOP="$HERE/stop.sh"
START="$HERE/start.sh"
[ -f "$STOP" ] || STOP="$DG_HOME/stop.sh"
[ -f "$START" ] || START="$DG_HOME/start.sh"

if [ -f "$STOP" ]; then
  /system/bin/sh "$STOP"
else
  printf '%s\n' "[WARN] 未找到 stop.sh"
fi
sleep 1
if [ -f "$START" ]; then
  /system/bin/sh "$START"
else
  printf '%s\n' "[ERR] 未找到 start.sh" >&2
  exit 1
fi
