#!/system/bin/sh
# ddns-go Android Magisk manager
# target: Android 6+ (Magisk / root shell)
# fixed home: /data/adb/ddns-go
# binary: $DG_HOME/bin/ddns-go  (android_arm64 official / android armv7 self-build)
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

# defaults
DG_LISTEN="${DG_LISTEN:-0.0.0.0:9876}"
DG_FREQ="${DG_FREQ:-300}"
CORE_REPO="${CORE_REPO:-jeessy2/ddns-go}"
DEFAULT_PROXY="https://ghfast.top/"

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
    _err "missing binary: $DG_BIN
run: sh $DG_HOME/update.sh
or put android binary there and chmod 755"
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

_http_get() {
  # $1=url $2=out_file
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 15 --max-time 180 --retry 2 -o "$out" "$url" 2>/dev/null
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" --timeout=30 "$url" 2>/dev/null
    return $?
  fi
  # toybox wget
  if command -v toybox >/dev/null 2>&1; then
    toybox wget -q -O "$out" "$url" 2>/dev/null
    return $?
  fi
  return 127
}

_http_body() {
  # print body to stdout
  url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 30 "$url" 2>/dev/null
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- --timeout=20 "$url" 2>/dev/null
    return $?
  fi
  if command -v toybox >/dev/null 2>&1; then
    toybox wget -qO- "$url" 2>/dev/null
    return $?
  fi
  return 127
}

# normalize proxy input:
#   empty -> empty
#   ghfast.top / //ghfast.top / http://ghfast.top / https://ghfast.top/ -> https://ghfast.top/
#   https://mirror.example/path/ -> keep as https base ending with /
_normalize_proxy() {
  raw=$(printf '%s' "$1" | tr -d ' \t\r\n')
  [ -z "$raw" ] && { _echo ""; return; }

  # full URL already (http/https)
  case "$raw" in
    http://*|https://*)
      # strip trailing slashes then add one
      base=$(printf '%s' "$raw" | sed 's|/*$||')
      _echo "${base}/"
      return
      ;;
    //*)
      base=$(printf '%s' "$raw" | sed 's|^//||; s|/*$||')
      _echo "https://${base}/"
      return
      ;;
  esac

  # bare host or host/path
  base=$(printf '%s' "$raw" | sed 's|^/*||; s|/*$||')
  _echo "https://${base}/"
}

# build download url: proxy_base + original github url (or plain github if no proxy)
_build_url() {
  # $1=github_url $2=proxy_base(optional, already normalized or empty)
  gh_url="$1"
  proxy="$2"
  if [ -z "$proxy" ]; then
    _echo "$gh_url"
    return
  fi
  # if proxy already looks like full mirror of github path, still prefix
  # form: https://ghfast.top/https://github.com/...
  _echo "${proxy}${gh_url}"
}

_extract_tar_gz() {
  # $1=tgz $2=dest_dir  -> find ddns-go binary
  tgz="$1"
  dest="$2"
  _mkdir "$dest"
  if command -v tar >/dev/null 2>&1; then
    tar -xzf "$tgz" -C "$dest" 2>/dev/null && return 0
  fi
  if command -v toybox >/dev/null 2>&1; then
    toybox tar -xzf "$tgz" -C "$dest" 2>/dev/null && return 0
  fi
  # busybox
  if command -v busybox >/dev/null 2>&1; then
    busybox tar -xzf "$tgz" -C "$dest" 2>/dev/null && return 0
  fi
  return 1
}

_find_extracted_bin() {
  dir="$1"
  # prefer exact name
  if [ -f "$dir/ddns-go" ]; then
    _echo "$dir/ddns-go"
    return 0
  fi
  for f in "$dir"/*/ddns-go "$dir"/ddns-go*; do
    [ -f "$f" ] || continue
    # skip archives
    case "$f" in
      *.tar.gz|*.tgz|*.zip|*.txt) continue ;;
    esac
    _echo "$f"
    return 0
  done
  # walk one level
  for d in "$dir"/*; do
    [ -d "$d" ] || continue
    if [ -f "$d/ddns-go" ]; then
      _echo "$d/ddns-go"
      return 0
    fi
  done
  return 1
}

_resolve_latest_tag() {
  # try github api first (may fail in CN)
  proxy="$1"
  api="https://api.github.com/repos/${CORE_REPO}/releases/latest"
  body=""
  if [ -n "$proxy" ]; then
    body=$(_http_body "$(_build_url "$api" "$proxy")")
  fi
  if [ -z "$body" ]; then
    body=$(_http_body "$api")
  fi
  if [ -n "$body" ]; then
    tag=$(printf '%s' "$body" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\(v[^"]*\)".*/\1/')
    if [ -n "$tag" ]; then
      _echo "$tag"
      return 0
    fi
  fi
  # fallback: redirects of /releases/latest
  # curl -I or parse html
  latest_url="https://github.com/${CORE_REPO}/releases/latest"
  if command -v curl >/dev/null 2>&1; then
    loc=$(curl -fsSI --connect-timeout 10 --max-time 20 "$latest_url" 2>/dev/null | grep -i '^location:' | tail -1 | tr -d '\r' | sed 's/[Ll]ocation: *//')
    tag=$(printf '%s' "$loc" | sed -n 's|.*/tag/\(v[^/[:space:]]*\).*|\1|p')
    if [ -n "$tag" ]; then
      _echo "$tag"
      return 0
    fi
  fi
  return 1
}

_write_core_version() {
  ver="$1"
  arch="$2"
  cat >"$CORE_VER_FILE" <<EOF
core_repo=${CORE_REPO}
core_version=${ver}
core_arch=${arch}
bundled=0
source=github_release_update
updated_at=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)
EOF
}

cmd_status() {
  _ensure_dirs
  if _is_running; then
    pid=$(_find_bin_pid)
    _ok "ddns-go running (pid=$pid)"
  else
    _warn "ddns-go stopped"
  fi
  if [ -x "$DG_BIN" ]; then
    ver=$("$DG_BIN" --help 2>&1 | head -1)
    # ddns-go may print version via -v or just help; try common flags
    v2=$("$DG_BIN" -v 2>&1 | head -1)
    [ -n "$v2" ] && ver="$v2"
    _info "binary: $DG_BIN"
    [ -n "$ver" ] && _info "version hint: $ver"
  else
    _warn "binary missing: $DG_BIN"
  fi
  if [ -f "$CORE_VER_FILE" ]; then
    _info "core.version: $(head -n 3 "$CORE_VER_FILE" | tr '\n' ' ')"
  fi
  _info "config: $DG_CFG"
  [ -f "$DG_CFG" ] && _info "config exists" || _warn "config not created yet (open web UI once)"
  _info "web: http://127.0.0.1:${DG_LISTEN##*:}"
  _info "listen: $DG_LISTEN"
  _info "home: $DG_HOME"
}

cmd_start() {
  _check_bin
  _ensure_dirs
  if _is_running; then
    _warn "already running (pid=$(_find_bin_pid))"
    return 0
  fi

  # cleanup stale pid
  rm -f "$PID_FILE"

  # args: listen + config path + frequency
  # first run without config is fine — web UI creates it
  "$DG_BIN" -l "$DG_LISTEN" -c "$DG_CFG" -f "$DG_FREQ" \
    >"$DG_LOG/stdout.log" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 1
  if _is_running; then
    _ok "started (pid=$(cat "$PID_FILE"))"
    _info "web UI: http://127.0.0.1:${DG_LISTEN##*:}"
    _info "config: $DG_CFG"
  else
    _err "start failed, see $DG_LOG/stdout.log"
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
  # kill leftover by binary path
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
    _ok "stopped"
  else
    _warn "not running"
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
    _warn "no log yet: $f"
  fi
}

cmd_config() {
  _ensure_dirs
  _echo "config dir:  $DG_CFG_DIR"
  _echo "config file: $DG_CFG"
  if [ -f "$DG_CFG" ]; then
    _ok "config exists"
    if command -v ls >/dev/null 2>&1; then
      ls -l "$DG_CFG" 2>/dev/null
    fi
  else
    _warn "config not found — start service and open web UI to create"
  fi
  _echo "other files in config/:"
  found=0
  for f in "$DG_CFG_DIR"/*; do
    [ -f "$f" ] || continue
    _echo "  $(basename "$f")"
    found=1
  done
  [ "$found" = "0" ] && _echo "  (empty)"
}

_download_asset() {
  # $1=github_url $2=out $3=proxy(normalized or empty)
  # try: given proxy -> direct -> fail
  gh_url="$1"
  out="$2"
  proxy="$3"

  if [ -n "$proxy" ]; then
    url=$(_build_url "$gh_url" "$proxy")
    _info "download via proxy: $url"
    if _http_get "$url" "$out"; then
      [ -s "$out" ] && return 0
    fi
    _warn "proxy download failed"
  fi

  _info "download direct: $gh_url"
  if _http_get "$gh_url" "$out"; then
    [ -s "$out" ] && return 0
  fi
  return 1
}

cmd_update() {
  _ensure_dirs
  req_ver="$1"
  req_proxy="$2"
  [ -z "$req_ver" ] && req_ver="latest"

  # interactive proxy only if needed (after direct fail) unless pre-supplied
  proxy=""
  if [ -n "$req_proxy" ]; then
    proxy=$(_normalize_proxy "$req_proxy")
  fi

  # resolve version
  ver=""
  case "$req_ver" in
    latest|""|auto)
      _info "resolve latest tag from GitHub..."
      ver=$(_resolve_latest_tag "$proxy")
      if [ -z "$ver" ] && [ -z "$proxy" ]; then
        # try with default proxy for api
        _warn "direct resolve failed, try default proxy $DEFAULT_PROXY"
        ver=$(_resolve_latest_tag "$DEFAULT_PROXY")
        [ -n "$ver" ] && proxy="$DEFAULT_PROXY"
      fi
      [ -n "$ver" ] || {
        # ask proxy then retry
        if [ -z "$proxy" ]; then
          printf 'GitHub 直连失败。输入代理域名或 http(s) 链接 (回车默认 %s): ' "$DEFAULT_PROXY"
          read user_proxy
          if [ -z "$user_proxy" ]; then
            proxy="$DEFAULT_PROXY"
          else
            proxy=$(_normalize_proxy "$user_proxy")
          fi
          ver=$(_resolve_latest_tag "$proxy")
        fi
      }
      [ -n "$ver" ] || _err "cannot resolve latest version"
      ;;
    *)
      ver="$req_ver"
      ;;
  esac

  # normalize version: ensure leading v for tag, strip for asset name
  ver_num="${ver#v}"
  ver="v${ver_num}"

  # detect abi: prefer core.version, then uname
  abi=""
  if [ -f "$CORE_VER_FILE" ]; then
    abi=$(grep '^module_abi=' "$CORE_VER_FILE" 2>/dev/null | cut -d= -f2 | tr -d ' \r')
  fi
  if [ -z "$abi" ]; then
    u=$(uname -m 2>/dev/null)
    case "$u" in
      aarch64|arm64) abi="arm64" ;;
      armv7*|armv8l|arm) abi="armv7a" ;;
      *) abi="arm64" ;;
    esac
  fi
  case "$abi" in
    armv7a|armeabi-v7a|armv7|arm)
      # upstream goreleaser ignores android/arm — no official asset
      rm -rf "$DG_TMP/update-$$" 2>/dev/null
      _err "GitHub 官方无 android_arm (armv7a) 资源。
armv7a 包仅由 GitHub Actions 用 NDK 交叉编译并发布。
请重新刷入 Releases 中的 ddns-go-android-armv7a.zip。"
      ;;
    *)
      arch="android_arm64"
      ;;
  esac
  asset="ddns-go_${ver_num}_${arch}.tar.gz"
  gh_url="https://github.com/${CORE_REPO}/releases/download/${ver}/${asset}"

  _info "target: ${ver}  abi=${abi}  asset: ${asset}"

  work="$DG_TMP/update-$$"
  rm -rf "$work"
  _mkdir "$work"
  tgz="$work/$asset"

  # 1) try download with optional pre-set proxy, else direct first
  if ! _download_asset "$gh_url" "$tgz" "$proxy"; then
    # prompt for proxy
    printf '下载失败。输入代理域名或 http(s) 链接 (回车默认 %s): ' "$DEFAULT_PROXY"
    read user_proxy
    if [ -z "$user_proxy" ]; then
      proxy="$DEFAULT_PROXY"
    else
      proxy=$(_normalize_proxy "$user_proxy")
    fi
    _info "retry with proxy: $proxy"
    if ! _download_asset "$gh_url" "$tgz" "$proxy"; then
      rm -rf "$work"
      _err "download failed: $gh_url
proxy form example: ghfast.top  or  https://ghfast.top/
final URL like: https://ghfast.top/https://github.com/..."
    fi
  fi

  # extract
  extract="$work/extract"
  _mkdir "$extract"
  if ! _extract_tar_gz "$tgz" "$extract"; then
    rm -rf "$work"
    _err "extract failed (need tar): $tgz"
  fi

  bin=$(_find_extracted_bin "$extract")
  [ -n "$bin" ] && [ -f "$bin" ] || {
    rm -rf "$work"
    _err "ddns-go binary not found in archive"
  }

  # stop if running
  was_running=0
  if _is_running; then
    was_running=1
    cmd_stop
  fi

  cp -f "$bin" "$DG_BIN"
  chmod 755 "$DG_BIN"
  _write_core_version "$ver" "$arch"
  _ok "installed binary: $DG_BIN ($ver $arch)"

  rm -rf "$work"

  if [ "$was_running" = "1" ]; then
    cmd_start
  else
    _info "not auto-started (was stopped). run: sh $DG_HOME/start.sh"
  fi
}

cmd_help() {
  cat <<EOF
ddns-go Magisk manager $SCRIPT_VER
Home:   $DG_HOME
Binary: $DG_BIN
Config: $DG_CFG
Listen: $DG_LISTEN  (override: DG_LISTEN=0.0.0.0:9876)

推荐: 交互菜单
  sh $DG_HOME/menu.sh

用法: sh $DG_HOME/dg.sh <command> [args]

管理:
  start | stop | restart | status
  log | config
  独立脚本: start.sh / stop.sh / restart.sh / update.sh

更新 binary (jeessy2/ddns-go):
  update [version|latest] [proxy]
  arm64: 官方 android_arm64; 优先直连, 失败提示代理 (回车默认 $DEFAULT_PROXY)
  armv7a: 上游无官方包, 需重刷 build-release 产物
  代理可填单 host 或完整 http(s) 链接, 自动识别:
    ghfast.top
    https://ghfast.top/
    https://ghfast.top/https://github.com/...  (脚本会拼 github 完整 URL)

示例:
  sh $DG_HOME/update.sh
  sh $DG_HOME/update.sh latest
  sh $DG_HOME/update.sh v6.17.2
  sh $DG_HOME/update.sh latest ghfast.top
  sh $DG_HOME/update.sh latest https://ghfast.top/
  sh $DG_HOME/start.sh
  sh $DG_HOME/stop.sh
  sh $DG_HOME/restart.sh

Web UI:
  本机: http://127.0.0.1:9876
  配置文件固定: $DG_CFG
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
    update|u) cmd_update "$@" ;;
    help|h|-h|--help|"") cmd_help ;;
    *)
      _warn "未知命令: $cmd"
      cmd_help
      exit 1
      ;;
  esac
}

main "$@"
