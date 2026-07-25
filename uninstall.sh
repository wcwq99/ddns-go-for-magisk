#!/system/bin/sh
# Magisk module uninstall: keep config by default
# Data at /data/adb/ddns-go is intentionally kept so reinstall restores configs.
# To wipe fully after uninstall:
#   rm -rf /data/adb/ddns-go

if [ -f /data/adb/ddns-go/stop.sh ]; then
  /system/bin/sh /data/adb/ddns-go/stop.sh >/dev/null 2>&1
elif [ -f /data/adb/ddns-go/dg.sh ]; then
  /system/bin/sh /data/adb/ddns-go/dg.sh stop >/dev/null 2>&1
fi
