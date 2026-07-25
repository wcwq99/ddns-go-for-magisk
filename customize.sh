#!/system/bin/sh
# Magisk module install hook
# Binary may be bundled in zip (dg/bin/ddns-go). Install copies to /data/adb/ddns-go.
# Device install does NOT require network.

SKIPUNZIP=0

ui_print "- install ddns-go Magisk module"
ui_print "- module id: ddns-go (arm64/armv7a 共用, 只装一个)"
ui_print "- fixed path: /data/adb/ddns-go"

mkdir -p /data/adb/ddns-go/bin \
  /data/adb/ddns-go/config \
  /data/adb/ddns-go/log \
  /data/adb/ddns-go/tmp

# remove stale / different-id module dirs
for d in \
  /data/adb/modules/ddnsgo \
  /data/adb/modules/ddns-go-arm64 \
  /data/adb/modules/ddns-go-armv7a \
  /data/adb/modules_update/ddnsgo \
  /data/adb/modules_update/ddns-go-arm64 \
  /data/adb/modules_update/ddns-go-armv7a
do
  if [ -d "$d" ]; then
    ui_print "- remove stale module dir: $d"
    rm -rf "$d"
  fi
done

# do not inject PATH binaries; keep fixed home only
rm -rf "$MODPATH/system" 2>/dev/null

# management scripts (ASCII names only)
for f in dg.sh start.sh stop.sh restart.sh update.sh menu.sh; do
  if [ -f "$MODPATH/dg/$f" ]; then
    cp -f "$MODPATH/dg/$f" /data/adb/ddns-go/$f
    chmod 755 /data/adb/ddns-go/$f
  fi
done

# strip Windows CRLF if any
for f in /data/adb/ddns-go/*.sh; do
  [ -f "$f" ] || continue
  if grep -q $'\r' "$f" 2>/dev/null; then
    tr -d '\r' <"$f" >"$f.lf" && mv -f "$f.lf" "$f"
    chmod 755 "$f"
  fi
done

chmod 755 "$MODPATH/service.sh" 2>/dev/null

# bundled binary (optional)
BIN_SRC=""
if [ -f "$MODPATH/dg/bin/ddns-go" ]; then
  BIN_SRC="$MODPATH/dg/bin/ddns-go"
elif [ -f "$MODPATH/bin/ddns-go" ]; then
  BIN_SRC="$MODPATH/bin/ddns-go"
fi

if [ -n "$BIN_SRC" ]; then
  cp -f "$BIN_SRC" /data/adb/ddns-go/bin/ddns-go
  chmod 755 /data/adb/ddns-go/bin/ddns-go
  ui_print "- binary installed: /data/adb/ddns-go/bin/ddns-go"
  if [ -f "$MODPATH/dg/core.version" ]; then
    cp -f "$MODPATH/dg/core.version" /data/adb/ddns-go/core.version
    ui_print "- $(head -n 3 /data/adb/ddns-go/core.version | tr '\n' ' ')"
  fi
else
  ui_print "- WARN: zip has no bundled binary"
  ui_print "- run update after install: sh /data/adb/ddns-go/update.sh"
fi

# preserve existing config; only ensure config dir exists
if [ ! -f /data/adb/ddns-go/config/ddns_go_config.yaml ]; then
  ui_print "- config dir ready: /data/adb/ddns-go/config"
  ui_print "- first open web UI will create config"
fi

ui_print "- done"
ui_print "- menu:   sh /data/adb/ddns-go/menu.sh"
ui_print "- start:  sh /data/adb/ddns-go/start.sh"
ui_print "- update: sh /data/adb/ddns-go/update.sh"
