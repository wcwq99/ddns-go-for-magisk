# ddns-go Magisk Module (Android arm64 / armv7a)

面向 **Android 6+ / Magisk** 的 [ddns-go](https://github.com/jeessy2/ddns-go) 后台运行模块。  
结构参考 [wcwq99/sing-box](https://github.com/wcwq99/sing-box) 的 Android 模块设计：固定目录 + 管理脚本 + 云端打包内置 binary。

## 特性

- 固定目录：`/data/adb/ddns-go`
- 管理脚本（英文名）：`start.sh` / `stop.sh` / `restart.sh` / `update.sh` / `menu.sh` / `dg.sh`
- 配置目录：`/data/adb/ddns-go/config/`（`ddns_go_config.yaml`）
- 开机自启：`service.sh`（检测到 binary 才启动）
- **双架构包**：`arm64` + `armv7a`（同一 Magisk `id=ddns-go`，只装一个）
- **更新 binary（arm64）**：优先 GitHub 直连；失败提示填代理（回车默认 `https://ghfast.top/`）
- 代理智能识别：单 host 或完整 `http(s)` 链接

## Core 从哪来？

| ABI | 来源 |
|-----|------|
| **arm64** | GitHub 官方 `android_arm64` 资源（bionic / linker64） |
| **armv7a** | 上游 **不发布** `android_arm`；**仅 CI** 用 Android NDK + `GOOS=android GOARCH=arm GOARM=7` 交叉编译 |

> 不要用 `linux_arm64` / `linux_armv7`（glibc），在 Android 上会直接无法启动。

产物（GitHub Releases / Actions Artifact）：

- `ddns-go-android-arm64.zip`
- `ddns-go-android-armv7a.zip`

## 目录结构

```
/data/adb/ddns-go/
  bin/ddns-go                 # 可执行文件
  config/ddns_go_config.yaml  # ddns-go 配置（Web UI 生成）
  log/stdout.log
  tmp/ddns-go.pid
  core.version                # 版本记录
  dg.sh                       # 主管理脚本
  start.sh / stop.sh / restart.sh / update.sh / menu.sh
```

## 安装

**正式包只在云端（GitHub Actions）打包**，仓库内不保留本地 build/pack 脚本。

1. 推送 `main` 后自动触发 `Android Module` workflow；也可在 Actions 里手动 Run workflow  
2. 从 [Releases](../../releases) 或 Actions Artifact 下载：
   - `ddns-go-android-arm64.zip`
   - `ddns-go-android-armv7a.zip`
3. 按 CPU 选一个刷入 → 重启  
4. 使用：

```bash
sh /data/adb/ddns-go/menu.sh
# 或
sh /data/adb/ddns-go/start.sh
```

> **只装一个 ABI 包**。两个 zip 的 Magisk `id` 相同（`ddns-go`），后装覆盖前装。  
> armv7a 无法从 GitHub 在线更新官方 android 包，请刷 CI 产物。

## 使用

### 交互菜单

```bash
sh /data/adb/ddns-go/menu.sh
```

### 启动 / 暂停 / 重启

```bash
sh /data/adb/ddns-go/start.sh
sh /data/adb/ddns-go/stop.sh      # 暂停/停止
sh /data/adb/ddns-go/restart.sh
sh /data/adb/ddns-go/dg.sh status
```

### 更新 binary（arm64）

```bash
# 拉 latest（优先 GitHub；失败再问代理，回车默认 https://ghfast.top/）
sh /data/adb/ddns-go/update.sh

# 指定版本
sh /data/adb/ddns-go/update.sh v6.17.2

# 预指定代理（单 host 或完整 http 链接均可）
sh /data/adb/ddns-go/update.sh latest ghfast.top
sh /data/adb/ddns-go/update.sh latest https://ghfast.top/
```

代理最终拼出的下载地址形如：

```text
https://ghfast.top/https://github.com/jeessy2/ddns-go/releases/download/v6.17.2/ddns-go_6.17.2_android_arm64.tar.gz
```

识别规则：

| 输入 | 规范化结果 |
|------|------------|
| `ghfast.top` | `https://ghfast.top/` |
| `https://ghfast.top` | `https://ghfast.top/` |
| `https://ghfast.top/` | `https://ghfast.top/` |
| 空（提示时回车） | `https://ghfast.top/` |

### Web UI / 配置

- 默认监听：`0.0.0.0:9876`
- 本机访问：`http://127.0.0.1:9876`
- 配置文件：`/data/adb/ddns-go/config/ddns_go_config.yaml`
- 首次启动后用浏览器完成初始化配置

```bash
sh /data/adb/ddns-go/dg.sh config
```

### 环境变量（可选）

| 变量 | 默认 | 说明 |
|------|------|------|
| `DG_HOME` | `/data/adb/ddns-go` | 根目录 |
| `DG_LISTEN` | `0.0.0.0:9876` | 监听地址 |
| `DG_FREQ` | `300` | 同步间隔（秒） |

## 卸载

Magisk 卸载模块时会 **停止进程**，但 **默认保留** `/data/adb/ddns-go`（配置不丢）。  
彻底清理：

```bash
rm -rf /data/adb/ddns-go
```

## 仓库布局

```
ddns-go-for-magisk/
  module.prop
  customize.sh
  service.sh
  uninstall.sh
  META-INF/com/google/android/...
  dg/
    dg.sh menu.sh start.sh stop.sh restart.sh update.sh
  .github/workflows/android-module.yml   # 云端双架构打包 + Release
```

## Credits

- [jeessy2/ddns-go](https://github.com/jeessy2/ddns-go) — binary 与配置格式上游
- [wcwq99/sing-box](https://github.com/wcwq99/sing-box) Android module — 模块结构参考

## License

- 本仓库脚本：按仓库声明
- 内置 / 下载的 ddns-go binary：遵循 [jeessy2/ddns-go](https://github.com/jeessy2/ddns-go) 自身许可证
