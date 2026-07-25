#!/system/bin/sh
# interactive menu for ddns-go Magisk module
# usage: sh /data/adb/ddns-go/menu.sh

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"
DG_SH="$DG_HOME/dg.sh"
SCRIPT_VER="v1.0.0-android"

if [ ! -f "$DG_SH" ]; then
  HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
  [ -f "$HERE/dg.sh" ] && DG_SH="$HERE/dg.sh" && DG_HOME="$HERE"
fi

_echo() { printf '%s\n' "$*"; }
_err() { _echo "[ERR] $*" >&2; }
_green() { printf '\033[92m%s\033[0m\n' "$*"; }
_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

_run() {
  if [ -f "$DG_SH" ]; then
    /system/bin/sh "$DG_SH" "$@"
  else
    _err "找不到 dg.sh: $DG_SH"
    return 1
  fi
}

_pause() {
  _echo
  printf '按 Enter 返回菜单, 或 Ctrl+C 退出...'
  # shellcheck disable=SC2034
  read _line
  _echo
}

_status_line() {
  if [ -x "$DG_HOME/bin/ddns-go" ]; then
    bin_st="installed"
    if [ -f "$DG_HOME/core.version" ]; then
      cv=$(grep '^core_version=' "$DG_HOME/core.version" 2>/dev/null | cut -d= -f2)
      [ -n "$cv" ] && bin_st="$cv"
    fi
  else
    bin_st="missing (run update)"
  fi
  pid=""
  [ -f "$DG_HOME/tmp/ddns-go.pid" ] && pid=$(cat "$DG_HOME/tmp/ddns-go.pid" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    st="running (pid=$pid)"
  else
    st="stopped"
  fi
  cfg="no"
  [ -f "$DG_HOME/config/ddns_go_config.yaml" ] && cfg="yes"
  _echo "binary: $bin_st"
  _echo "状态:   $st"
  _echo "配置:   $cfg  ($DG_HOME/config)"
  _echo "目录:   $DG_HOME"
  _echo "Web:    http://127.0.0.1:9876"
}

_menu_manage() {
  _echo
  _echo "运行管理:"
  _echo "  1) 启动"
  _echo "  2) 停止 / 暂停"
  _echo "  3) 重启"
  _echo "  4) 状态"
  _echo "  0) 返回"
  printf '请选择 [0-4]: '
  read m
  case "$m" in
    1) [ -f "$DG_HOME/start.sh" ] && /system/bin/sh "$DG_HOME/start.sh" || _run start ;;
    2) [ -f "$DG_HOME/stop.sh" ] && /system/bin/sh "$DG_HOME/stop.sh" || _run stop ;;
    3) [ -f "$DG_HOME/restart.sh" ] && /system/bin/sh "$DG_HOME/restart.sh" || _run restart ;;
    4) _run status ;;
    0|"") return ;;
    *) _err "无效选择" ;;
  esac
}

_menu_update() {
  _echo
  _echo "更新 ddns-go binary (android_arm64)"
  _echo "  优先 GitHub 直连; 失败会提示输入代理"
  _echo "  代理默认: https://ghfast.top/"
  _echo "  可填 host 或完整 http(s) 链接"
  printf '版本 (回车=latest, 例 v6.17.2): '
  read ver
  [ -z "$ver" ] && ver=latest
  printf '代理 (回车=先直连, 失败再问): '
  read proxy
  if [ -n "$proxy" ]; then
    _run update "$ver" "$proxy"
  else
    _run update "$ver"
  fi
}

_menu_help() {
  cat <<EOF

------------- 帮助 -------------
固定目录: $DG_HOME
管理脚本: $DG_SH
菜单脚本: $DG_HOME/menu.sh

常用直接命令:
  sh $DG_HOME/menu.sh
  sh $DG_HOME/start.sh
  sh $DG_HOME/stop.sh
  sh $DG_HOME/restart.sh
  sh $DG_HOME/update.sh
  sh $DG_SH status
  sh $DG_SH log
  sh $DG_SH config

配置文件:
  $DG_HOME/config/ddns_go_config.yaml
  首次启动后浏览器打开 http://设备IP:9876 初始化

更新说明:
  arm64: GitHub 官方 android_arm64, 直连失败可填代理 (默认 https://ghfast.top/)
  armv7a: 上游无官方 android_arm, 需重刷 build-release 产物
  示例最终 URL (arm64):
    https://ghfast.top/https://github.com/jeessy2/ddns-go/releases/download/vX.Y.Z/ddns-go_X.Y.Z_android_arm64.tar.gz

注意:
  - arm64 / armv7a 二选一 (module id 均为 ddns-go)
  - 不提供系统 PATH 命令
  - 卸载模块默认保留 /data/adb/ddns-go 配置

EOF
}

while :; do
  _echo
  _echo "------------- ddns-go Android $SCRIPT_VER -------------"
  _status_line
  _echo "-----------------------------------------------"
  _echo "  1) 运行管理 (启动/停止/重启/状态)"
  _echo "  2) 更新 binary"
  _echo "  3) 查看日志"
  _echo "  4) 配置路径"
  _echo "  5) 帮助"
  _echo "  0) 退出"
  _echo "-----------------------------------------------"
  printf '请选择 [0-5]: '
  read choice
  case "$choice" in
    1) _menu_manage; _pause ;;
    2) _menu_update; _pause ;;
    3) _run log; _pause ;;
    4) _run config; _pause ;;
    5) _menu_help; _pause ;;
    0|q|Q|"") _echo "bye"; exit 0 ;;
    *) _err "无效选择: $choice"; _pause ;;
  esac
done
