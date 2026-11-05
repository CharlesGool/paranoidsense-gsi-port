# paranoidsense-gsi-port

**简体中文** | [English](doc/en/README.md) | [Español](doc/es/README.md)

把 PixelOS 的 ParanoidSense 人脸解锁移植到拿不到 platform 签名的 Android 15+ GSI 上, 不用重新编 ROM. 本项目是移植教程, 也是做这件事的通用工具.

[![License](https://img.shields.io/badge/License-Apache--2.0-orange)](LICENSE)

## 文档

- 项目概览: [README](README.md)

- 设计思路: [DESIGN](doc/DESIGN.md)

- 项目状态: [LOG](doc/LOG.md)
- 历史记录: [HISTORY](doc/HISTORY.md)
- 变更日志: [CHANGELOG](doc/CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](doc/THIRD_PARTY_NOTICES.md)

## 简介

- 前置摄像头 2D 人脸识别, 用旷视 (Megvii) SDK, Android 生物识别等级 WEAK (Class 2). 应用包名是 `com.android.faceunlock`.
- 原版 ParanoidSense 依赖 platform 签名: 它要的 `USE_BIOMETRIC_INTERNAL` 和 `MANAGE_BIOMETRIC` 都是 signature 级权限, 自签名应用拿不到. 本项目在 `services.jar` 里改了 57 处权限检查, 只对装在 `/system/priv-app` 的 `com.android.faceunlock` 放行, 并让系统以前台方式绑定它的服务, 避开相机的后台限制. 原理见 [DESIGN](doc/DESIGN.md#架构).
- 工具从目标 GSI 自己的 `services.jar` 生成改过的 `services.jar`, 编出自签名的人脸应用和设置 overlay, 再打成 KernelSU / Magisk 模块, 或者做进 system 镜像.
- 换到别的 GSI 或设备时怎么改, 见[移植教程](doc/porting-guide.md).

验证情况: Pixel Tablet Mystic GSI (Android 15, AP3A.241005.015) 在拯救者 Y700 三代 (TB321FU) 上真机通过, 录入正常, 连续 10 次锁屏解锁和待机后解锁都正常. 在 TB321FU 上做进 system 镜像的参考实现是 [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), 那里还有 Android 15 官方 GSI (BP1A) 和 Android 17 (CP3A) 的适配. 已知问题见 [LOG](doc/LOG.md#缺陷).

## 要求

- 目标设备: Android 15 或更新的 GSI, arm64, 有前置摄像头
- 构建机: Linux, sudo (挂载 ART apex), JDK 17, python3, git, zip, 以及:

| 环境变量 | 工具 |
| --- | --- |
| `D2J` | [dex2jar](https://github.com/ThexXTURBOXx/dex2jar) 2.4.38 的 `d2j-dex2jar.sh` |
| `R8` | `r8-8.5.35.jar` (含 d8) |
| `APKTOOL` | [Apktool](https://github.com/iBotPeaches/Apktool) 2.12.1 的 jar |
| `BT` | Android build-tools 35 目录 (aidl, aapt2, zipalign, apksigner) |
| `KOTLIN_HOME` | kotlinc 2.0.21 目录 |
| `JAVA_HOME` | 可选, 默认 `/usr/lib/jvm/java-17-openjdk-amd64` |
| `KS` | 可选, 签名用的 PKCS12 keystore (别名 `faceunlock`, 口令 `android`); 不设时自动生成 `sense/faceunlock.keystore` |

变量列表也见 [.env.example](.env.example).

- 目标 GSI 的原版 system 镜像, 挂载后其中的 `system/` 目录 (下文叫"底包 system 目录"). 构建要用 `framework/framework.jar`, `framework/services.jar`, `framework/framework-res.apk`, `apex/com.google.android.art.apex`
- 网络: 构建时从 [PixelOS ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense) 拉取旷视的库, 模型和设置教育页素材. 这些文件和编出的 APK **禁止**提交到仓库

## 安装

### 快速安装

装成 KernelSU / Magisk 模块:

```bash
scripts/fetch_upstream.sh
bash services/build.sh <底包 system 目录> out/services
bash sense/build.sh <底包 system 目录> out/sense
scripts/pack_module.sh out/services out/sense out/faceunlock_gsi.zip
```

在 KernelSU 或 Magisk 里安装 `out/faceunlock_gsi.zip`, 重启.

**`services.jar` 必须用要刷的那个底包自己编**. 用别的底包编的 `services.jar`, system_server 会起不来.

### 常规安装

把文件做进 system 镜像, 不需要 root:

| 文件 | 放到 | 权限 | SELinux |
| --- | --- | --- | --- |
| `out/services/services.jar` | 覆盖 `/system/framework/services.jar` | 0644 | `system_file` |
| `out/sense/FaceUnlock.apk` | `/system/priv-app/FaceUnlock/` (目录 0755) | 0644 | `system_file` |
| `out/sense/FaceUnlockSettingsOverlay.apk` | `/system/product/overlay/` | 0644 | `system_file` |
| `module/system/etc/permissions/*.xml` | `/system/etc/permissions/` | 0644 | `system_file` |
| `module/system/etc/sysconfig/*.xml` | `/system/etc/sysconfig/` | 0644 | `system_file` |
| `image/default_permissions_com.android.faceunlock.xml` | `/system/product/etc/default-permissions/` | 0644 | `system_file` |
| `ro.face.sense_service=true` | 追加到 `/system/build.prop` | | |

同时删除 `/system/framework/oat/arm64/services.*`, 否则过期的 oat 会让 system_server 开机时重新编译. 改完要重新加 AVB hashtree footer 并签名. 参考实现见 [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch).

## 指南

设置 → 安全与隐私 → 设备解锁 → 人脸解锁 → 输入 PIN → 按提示录入. 之后锁屏时对着前置摄像头即可解锁.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # 有 SenseProvider
adb shell cmd overlay list | grep -i faceunlock    # [x]
```

模块方式的日志在 `/data/adb/modules/faceunlock_gsi/mount.log`. 开机完成前 system_server 启动了 3 次时, 模块会自动停用自己, 把 crash 日志存到模块目录, 然后重启.

移植到别的底包时 `services/src/` 和 `services/apply_hooks.py` 可能要改, 步骤见[移植教程](doc/porting-guide.md).

## 升级

换了 system 镜像 (包括同一 GSI 的新版本) 后, **必须**用新镜像重新编 `services.jar` 并重新安装. 已录入的人脸数据存在 `com.android.faceunlock` 的应用数据里, 只要不清数据就会保留.

已经把人脸解锁做进镜像时**禁止**再装模块, 两份 `services.jar` 会冲突.

## 卸载

### 快速卸载

模块方式: 先在设置里删除人脸模型, 再在 KernelSU 或 Magisk 里卸载模块, 重启. 不先删除的话, 系统设置里会残留一条人脸登记记录.

### 完全卸载

模块方式同快速卸载. `com.android.faceunlock` 是系统应用, 它从 system 分区消失后, 系统在下次开机时会删除它和它的数据 (含人脸模板). 镜像方式需要刷回不含本项目文件的 system 镜像.

## 致谢

- [PixelOS-AOSP/packages_apps_ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense): 应用源码, 旷视库, 模型和设置教育页素材
- [KLC_OS](https://github.com/LoggingNewMemory/KLC_OS) 的 `0009-feat-Add-Face-Unlock-with-ParanoidSense` 补丁 (Chris Crump, Adithya R, Tobias Merkel, someone5678, aswin7469, Pranav Vashi): 框架部分的参考

## 许可证

本项目以 Apache License 2.0 授权, SPDX 标识符 `Apache-2.0`, 全文见 [LICENSE](LICENSE). 旷视的库和模型, 以及设置教育页素材不在本仓库中, 构建时从上游拉取, 见 [THIRD_PARTY_NOTICES](doc/THIRD_PARTY_NOTICES.md).
