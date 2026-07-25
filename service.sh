#!/system/bin/sh
# Magisk late_start service: auto start ddns-go if binary exists

MODDIR=${0%/*}
DG_HOME=/data/adb/ddns-go
DG_BIN=$DG_HOME/bin/ddns-go
PID_FILE=$DG_HOME/tmp/ddns-go.pid

# wait boot complete
i=0
while [ $i -lt 60 ]; do
  boot=$(getprop sys.boot_completed 2>/dev/null)
  [ "$boot" = "1" ] && break
  i=$((i + 1))
  sleep 2
done

# wait network a bit
sleep 15

[ -x "$DG_BIN" ] || exit 0

# already running
if [ -f "$PID_FILE" ]; then
  old=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    exit 0
  fi
fi

if [ -f "$DG_HOME/start.sh" ]; then
  /system/bin/sh "$DG_HOME/start.sh" >/dev/null 2>&1
  exit 0
fi
if [ -f "$DG_HOME/dg.sh" ]; then
  /system/bin/sh "$DG_HOME/dg.sh" start >/dev/null 2>&1
  exit 0
fi

mkdir -p "$DG_HOME/log" "$DG_HOME/tmp" "$DG_HOME/config"
CFG="$DG_HOME/config/ddns_go_config.yaml"
"$DG_BIN" -l 0.0.0.0:9876 -c "$CFG" \
  >"$DG_HOME/log/stdout.log" 2>&1 &
echo $! >"$PID_FILE"
