#!/system/bin/sh
# ddns-go Android Magisk manager
# fixed home: /data/adb/ddns-go
# binary: $DG_HOME/bin/ddns-go (bundled in Magisk zip by CI)
# config: $DG_HOME/config/ddns_go_config.yaml

DG_HOME="${DG_HOME:-/data/adb/ddns-go}"
DG_BIN="$DG_HOME/bin/ddns-go"
DG_CFG_DIR="$DG_HOME/config"
DG_CFG="$DG_CFG_DIR/ddns_go_config.yaml"
DG_LOG="$DG_HOME/log"
DG_TMP="$DG_HOME/tmp"
PID_FILE="$DG_TMP/ddns-go.pid"
CORE_VER_FILE="$DG_HOME/core.version"
SCRIPT_VER="v1.0.0-android"

DG_LISTEN="${DG_LISTEN:-0.0.0.0:9876}"
DG_FREQ="${DG_FREQ:-300}"
DG_DNS="${DG_DNS:-223.5.5.5}"

_echo() { printf '%s\n' "$*"; }
_err() { _echo "[ERR] $*" >&2; exit 1; }
_warn() { _echo "[WARN] $*"; }
_ok() { _echo "[OK] $*"; }
_info() { _echo "[*] $*"; }

_mkdir() { mkdir -p "$@" 2>/dev/null; }

_ensure_dirs() {
  _mkdir "$DG_HOME" "$DG_CFG_DIR" "$DG_LOG" "$DG_TMP" "$DG_HOME/bin"
}

_check_bin() {
  if [ ! -x "$DG_BIN" ]; then
    _err "未找到可执行文件: $DG_BIN
请重新刷入 Magisk 模块 zip（binary 由 CI 打进包内）"
  fi
}

_pid() {
  if [ -f "$PID_FILE" ]; then
    cat "$PID_FILE" 2>/dev/null
  fi
}

_is_bin_pid() {
  pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [ -r "/proc/$pid/cmdline" ] || return 1
  cmd=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)
  echo "$cmd" | grep -q "$DG_BIN" || return 1
  echo "$cmd" | grep -Eq '(^|/)(pgrep|grep|sh|bash|mksh)( |$)' && return 1
  if [ -L "/proc/$pid/exe" ]; then
    exe=$(readlink "/proc/$pid/exe" 2>/dev/null)
    [ -n "$exe" ] && [ "$exe" != "$DG_BIN" ] && return 1
  fi
  return 0
}

_is_running() {
  pid=$(_pid)
  if _is_bin_pid "$pid"; then
    return 0
  fi
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    pid=${d##*/}
    _is_bin_pid "$pid" && return 0
  done
  return 1
}

_find_bin_pid() {
  pid=$(_pid)
  if _is_bin_pid "$pid"; then
    _echo "$pid"
    return 0
  fi
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    pid=${d##*/}
    if _is_bin_pid "$pid"; then
      _echo "$pid"
      return 0
    fi
  done
  return 1
}

cmd_status() {
  _ensure_dirs
  if _is_running; then
    pid=$(_find_bin_pid)
    _ok "ddns-go 运行中 (pid=$pid)"
  else
    _warn "ddns-go 已停止"
  fi
  if [ -x "$DG_BIN" ]; then
    ver=$("$DG_BIN" -v 2>&1 | head -1)
    [ -z "$ver" ] && ver=$("$DG_BIN" --help 2>&1 | head -1)
    _info "程序: $DG_BIN"
    [ -n "$ver" ] && _info "版本: $ver"
  else
    _warn "缺少程序: $DG_BIN（请重刷模块 zip）"
  fi
  if [ -f "$CORE_VER_FILE" ]; then
    _info "core.version: $(head -n 3 "$CORE_VER_FILE" | tr '\n' ' ')"
  fi
  _info "配置: $DG_CFG"
  [ -f "$DG_CFG" ] && _info "配置文件已存在" || _warn "配置尚未生成（请先打开 Web UI 初始化）"
  _info "Web: http://127.0.0.1:${DG_LISTEN##*:}"
  _info "监听: $DG_LISTEN"
  _info "DNS: $DG_DNS"
  _info "目录: $DG_HOME"
}

cmd_start() {
  _check_bin
  _ensure_dirs
  if _is_running; then
    _warn "已在运行 (pid=$(_find_bin_pid))"
    return 0
  fi

  rm -f "$PID_FILE"
  "$DG_BIN" -l "$DG_LISTEN" -c "$DG_CFG" -f "$DG_FREQ" -dns "$DG_DNS" \
    >"$DG_LOG/stdout.log" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 1
  if _is_running; then
    _ok "已启动 (pid=$(cat "$PID_FILE"))"
    _info "Web UI: http://127.0.0.1:${DG_LISTEN##*:}"
    _info "配置: $DG_CFG"
  else
    _err "启动失败，详见 $DG_LOG/stdout.log"
  fi
}

cmd_stop() {
  stopped=0
  pid=$(_pid)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    sleep 1
    kill -9 "$pid" 2>/dev/null
    stopped=1
  fi
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    if tr '\0' ' ' <"$d/cmdline" 2>/dev/null | grep -q "$DG_BIN"; then
      kill "${d##*/}" 2>/dev/null
      sleep 1
      kill -9 "${d##*/}" 2>/dev/null
      stopped=1
    fi
  done
  rm -f "$PID_FILE"
  if [ "$stopped" = "1" ]; then
    _ok "已停止"
  else
    _warn "当前未运行"
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_log() {
  f="$DG_LOG/stdout.log"
  if [ -f "$f" ]; then
    if command -v tail >/dev/null 2>&1; then
      tail -n 80 "$f"
    else
      cat "$f"
    fi
  else
    _warn "暂无日志: $f"
  fi
}

cmd_config() {
  _ensure_dirs
  _echo "配置目录: $DG_CFG_DIR"
  _echo "配置文件: $DG_CFG"
  if [ -f "$DG_CFG" ]; then
    _ok "配置文件已存在"
    if command -v ls >/dev/null 2>&1; then
      ls -l "$DG_CFG" 2>/dev/null
    fi
  else
    _warn "尚未找到配置 — 请启动服务并打开 Web UI 完成初始化"
  fi
  _echo "config/ 目录其他文件:"
  found=0
  for f in "$DG_CFG_DIR"/*; do
    [ -f "$f" ] || continue
    _echo "  $(basename "$f")"
    found=1
  done
  [ "$found" = "0" ] && _echo "  (空)"
}

cmd_help() {
  cat <<EOF
ddns-go Magisk 管理脚本 $SCRIPT_VER
目录:   $DG_HOME
程序:   $DG_BIN  (由 CI 打进模块 zip)
配置:   $DG_CFG
监听:   $DG_LISTEN
DNS:    $DG_DNS  (可覆盖: DG_DNS=8.8.8.8)

用法: sh $DG_HOME/dg.sh <命令>
  start | stop | restart | status | log | config

独立脚本:
  sh $DG_HOME/start.sh
  sh $DG_HOME/stop.sh
  sh $DG_HOME/restart.sh

升级 binary: 重刷 GitHub Releases 新模块 zip

Web UI: http://127.0.0.1:9876
EOF
}

main() {
  _ensure_dirs
  cmd="$1"
  [ -n "$cmd" ] && shift
  case "$cmd" in
    start) cmd_start "$@" ;;
    stop) cmd_stop "$@" ;;
    restart|r) cmd_restart "$@" ;;
    status|s) cmd_status "$@" ;;
    log) cmd_log "$@" ;;
    config|cfg) cmd_config "$@" ;;
    help|h|-h|--help|"") cmd_help ;;
    *)
      _warn "未知命令: $cmd"
      cmd_help
      exit 1
      ;;
  esac
}

main "$@"
