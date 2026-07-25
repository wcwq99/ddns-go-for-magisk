#!/system/bin/sh
# Magisk module install hook
# Binary is BUNDLED in zip (dg/bin/ddns-go). Install copies to /data/adb/ddns-go.
# Device install does NOT require network.

SKIPUNZIP=0

ui_print "- 正在安装 ddns-go Magisk 模块"
ui_print "- 模块 id: ddns-go (arm64/armv7a 共用, 只装一个)"
ui_print "- 固定目录: /data/adb/ddns-go"

mkdir -p /data/adb/ddns-go/bin \
  /data/adb/ddns-go/config \
  /data/adb/ddns-go/log \
  /data/adb/ddns-go/tmp

for d in \
  /data/adb/modules/ddnsgo \
  /data/adb/modules/ddns-go-arm64 \
  /data/adb/modules/ddns-go-armv7a \
  /data/adb/modules_update/ddnsgo \
  /data/adb/modules_update/ddns-go-arm64 \
  /data/adb/modules_update/ddns-go-armv7a
do
  if [ -d "$d" ]; then
    ui_print "- 清理旧模块目录: $d"
    rm -rf "$d"
  fi
done

rm -rf "$MODPATH/system" 2>/dev/null

# drop legacy scripts
rm -f /data/adb/ddns-go/update.sh /data/adb/ddns-go/menu.sh 2>/dev/null
rm -f "$MODPATH/dg/update.sh" "$MODPATH/dg/menu.sh" 2>/dev/null

for f in dg.sh start.sh stop.sh restart.sh; do
  if [ -f "$MODPATH/dg/$f" ]; then
    cp -f "$MODPATH/dg/$f" /data/adb/ddns-go/$f
    chmod 755 /data/adb/ddns-go/$f
  fi
done

for f in /data/adb/ddns-go/*.sh; do
  [ -f "$f" ] || continue
  if grep -q $'\r' "$f" 2>/dev/null; then
    tr -d '\r' <"$f" >"$f.lf" && mv -f "$f.lf" "$f"
    chmod 755 "$f"
  fi
done

chmod 755 "$MODPATH/service.sh" 2>/dev/null

BIN_SRC=""
if [ -f "$MODPATH/dg/bin/ddns-go" ]; then
  BIN_SRC="$MODPATH/dg/bin/ddns-go"
elif [ -f "$MODPATH/bin/ddns-go" ]; then
  BIN_SRC="$MODPATH/bin/ddns-go"
fi

if [ -n "$BIN_SRC" ]; then
  cp -f "$BIN_SRC" /data/adb/ddns-go/bin/ddns-go
  chmod 755 /data/adb/ddns-go/bin/ddns-go
  ui_print "- 已安装程序: /data/adb/ddns-go/bin/ddns-go"
  if [ -f "$MODPATH/dg/core.version" ]; then
    cp -f "$MODPATH/dg/core.version" /data/adb/ddns-go/core.version
    ui_print "- $(head -n 3 /data/adb/ddns-go/core.version | tr '\n' ' ')"
  fi
else
  ui_print "- [ERR] zip 未内置 binary (dg/bin/ddns-go)"
  ui_print "- 请使用 GitHub Releases 的 ddns-go-android-*.zip"
fi

if [ ! -f /data/adb/ddns-go/config/ddns_go_config.yaml ]; then
  ui_print "- 配置目录已就绪: /data/adb/ddns-go/config"
  ui_print "- 首次打开 Web UI 后会生成配置"
fi

ui_print "- 安装完成"
ui_print "- 启动: sh /data/adb/ddns-go/start.sh"
ui_print "- 停止: sh /data/adb/ddns-go/stop.sh"
ui_print "- 重启: sh /data/adb/ddns-go/restart.sh"
