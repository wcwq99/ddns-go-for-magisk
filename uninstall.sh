#!/system/bin/sh
# Magisk module uninstall: stop process and remove runtime data fully

DG_HOME=/data/adb/ddns-go

# stop process first
if [ -f "$DG_HOME/stop.sh" ]; then
  /system/bin/sh "$DG_HOME/stop.sh" >/dev/null 2>&1
elif [ -f "$DG_HOME/dg.sh" ]; then
  /system/bin/sh "$DG_HOME/dg.sh" stop >/dev/null 2>&1
fi

# kill leftover by binary path
if [ -x "$DG_HOME/bin/ddns-go" ]; then
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    if tr '\0' ' ' <"$d/cmdline" 2>/dev/null | grep -q "$DG_HOME/bin/ddns-go"; then
      kill "${d##*/}" 2>/dev/null
      kill -9 "${d##*/}" 2>/dev/null
    fi
  done
fi

# remove fixed home completely (scripts/binary/config/log)
rm -rf "$DG_HOME"
