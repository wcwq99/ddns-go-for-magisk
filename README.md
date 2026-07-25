# ddns-go Magisk Module (Android arm64 / armv7a)

面向 **Android 6+ / Magisk** 的 [ddns-go](https://github.com/jeessy2/ddns-go) 后台运行模块。  
固定目录 + 启停脚本；**binary 由 CI 打进 zip**，设备端不联网下载。

## 特性

- 固定目录：`/data/adb/ddns-go`
- 脚本：`start.sh` / `stop.sh` / `restart.sh` / `dg.sh`
- 配置：`/data/adb/ddns-go/config/ddns_go_config.yaml`
- 开机自启：`service.sh`（有 binary 才启动）
- 双架构：`arm64` + `armv7a`（同一 `id=ddns-go`，只装一个）

## Core 从哪来？

| ABI | 来源 |
|-----|------|
| **arm64** | GitHub 官方 `android_arm64`，CI 下载后打进 zip |
| **armv7a** | 上游无 `android_arm`；CI 用 NDK 交叉编译后打进 zip |

产物（[Releases](../../releases)）：

- `ddns-go-android-arm64.zip`
- `ddns-go-android-armv7a.zip`

## 安装

1. 下载对应 ABI 的 zip  
2. Magisk → 模块 → 本地安装 → 重启  
3. 使用：

```bash
sh /data/adb/ddns-go/start.sh
sh /data/adb/ddns-go/stop.sh
sh /data/adb/ddns-go/restart.sh
sh /data/adb/ddns-go/dg.sh status
```

> 只装一个 ABI 包。升级 binary = 重刷新 zip。

## 目录

```
/data/adb/ddns-go/
  bin/ddns-go
  config/ddns_go_config.yaml
  log/stdout.log
  tmp/ddns-go.pid
  core.version
  dg.sh start.sh stop.sh restart.sh
```

## Web UI / 配置

- 默认：`0.0.0.0:9876`
- 本机：`http://127.0.0.1:9876`
- 配置：`/data/adb/ddns-go/config/ddns_go_config.yaml`

可选环境变量：`DG_LISTEN`（默认 `0.0.0.0:9876`）、`DG_FREQ`（默认 `300`）。

## 卸载

卸载模块会停进程，**默认保留** `/data/adb/ddns-go`。彻底清理：

```bash
rm -rf /data/adb/ddns-go
```

## 仓库

```
module.prop customize.sh service.sh uninstall.sh
META-INF/...
dg/  dg.sh start.sh stop.sh restart.sh
.github/workflows/android-module.yml   # 云端打 zip + 内置 binary
```

## Credits

- [jeessy2/ddns-go](https://github.com/jeessy2/ddns-go)
- [wcwq99/sing-box](https://github.com/wcwq99/sing-box) Android module 结构参考
