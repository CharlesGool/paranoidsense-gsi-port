# paranoidsense-gsi-port

**简体中文** | [English](doc/en/README.md) | [Español](doc/es/README.md)

把 PixelOS 的 ParanoidSense 人脸解锁移植到拿不到 platform 签名的 Android 15 GSI 上, 不用重新编 ROM.

[![License](https://img.shields.io/badge/License-Apache--2.0-orange)](LICENSE)

## 文档

- 项目概览: [README](README.md)

- 设计思路: [DESIGN](doc/DESIGN.md)

- 项目状态: [LOG](doc/LOG.md)
- 历史记录: [HISTORY](doc/HISTORY.md)
- 变更日志: [CHANGELOG](doc/CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](doc/THIRD_PARTY_NOTICES.md)

## 简介

- 前置摄像头 2D 人脸识别, 用旷视 (Megvii) SDK, Android 生物识别等级 WEAK (Class 2)
- 从 GSI 底包现成的 `services.jar` 生成改过的 `services.jar`, 加上自签名的 ParanoidSense priv-app 和设置 overlay
- 两种装法: 做进 system 镜像, 或者装成 KernelSU / Magisk 模块

原版 ParanoidSense 依赖 platform 签名, 它要的 `USE_BIOMETRIC_INTERNAL` 和 `MANAGE_BIOMETRIC` 都是 signature 级权限, 自签名应用拿不到. 本项目在 `services.jar` 里改了 57 处权限检查, 对装在 system 分区的 `co.aospa.sense` 放行, 并让系统以前台方式绑定它的服务, 避开相机的后台限制. 每一步的原因和改法见 [DESIGN](doc/DESIGN.md#架构).

在拯救者 Y700 三代 (TB321FU) + Pixel Tablet Mystic GSI (Android 15, AP3A.241005.015) 上实测通过: 录入正常, 连续 10 次锁屏解锁和待机后解锁都正常. 成品 ROM 是 [TB321FU_PixelOS_15_Tangorpro](https://github.com/CharlesGool/TB321FU_PixelOS_15_Tangorpro) 的 `faceunlock` 分支. 其他底包没有测过, 已知问题和限制见 [LOG](doc/LOG.md#缺陷).

## 要求

- 目标设备: Android 15 GSI, arm64, 有前置摄像头
- 构建机: Linux, sudo(挂载 ART apex), JDK 17, python3, git, zip, 以及:

| 环境变量 | 工具 |
| --- | --- |
| `D2J` | [dex2jar](https://github.com/ThexXTURBOXx/dex2jar) 2.4.38 的 `d2j-dex2jar.sh` |
| `R8` | `r8-8.5.35.jar`(含 d8) |
| `APKTOOL` | [Apktool](https://github.com/iBotPeaches/Apktool) 2.12.1 的 jar |
| `BT` | Android build-tools 35 目录(aidl, aapt2, zipalign, apksigner) |
| `KOTLIN_HOME` | kotlinc 2.0.21 目录 |
| `JAVA_HOME` | 可选, 默认 `/usr/lib/jvm/java-17-openjdk-amd64` |
| `KS` | 可选, 签名用的 PKCS12 keystore(别名 `sense`, 口令 `android`); 不设时自动生成 `sense/sense.keystore` |

- 目标 GSI 的原版 system 镜像, 挂载后其中的 `system/` 目录(下文叫"底包 system 目录"). 构建要用 `framework/framework.jar`, `framework/services.jar`, `framework/framework-res.apk`, `apex/com.google.android.art.apex`

## 安装

### 快速安装

```bash
scripts/fetch_upstream.sh
bash services/build.sh <底包 system 目录> out/services
bash sense/build.sh <底包 system 目录> out/sense
scripts/pack_module.sh out/services out/sense out/paranoidsense_gsi.zip
```

在 KernelSU 或 Magisk 里安装 `out/paranoidsense_gsi.zip`, 重启.

**`services.jar` 必须用要刷的那个底包自己编**. 换个底包用别人编好的 `services.jar`, system_server 会起不来.

### 常规安装

把文件做进 system 镜像, 不需要 root:

| 文件 | 放到 | 权限 | SELinux |
| --- | --- | --- | --- |
| `out/services/services.jar` | 覆盖 `/system/framework/services.jar` | 0644 | `system_file` |
| `out/sense/ParanoidSense.apk` | `/system/priv-app/ParanoidSense/`(目录 0755) | 0644 | `system_file` |
| `out/sense/SenseSettingsOverlay.apk` | `/system/product/overlay/` | 0644 | `system_file` |
| `module/system/etc/permissions/*.xml` | `/system/etc/permissions/` | 0644 | `system_file` |
| `module/system/etc/sysconfig/*.xml` | `/system/etc/sysconfig/` | 0644 | `system_file` |
| `image/default_permissions_co.aospa.sense.xml` | `/system/product/etc/default-permissions/` | 0644 | `system_file` |
| `ro.face.sense_service=true` | 追加到 `/system/build.prop` | | |

改完要重新加 AVB hashtree footer 并签名. 参考实现是 TB321FU_PixelOS_15_Tangorpro 的 `gsi/make_gsi.sh`(`FACEUNLOCK=1`).

## 指南

设置 → 安全与隐私 → 设备解锁 → 人脸解锁 → 输入 PIN → 按提示录入. 之后锁屏时对着前置摄像头即可解锁.

模块方式的日志在 `/data/adb/modules/paranoidsense_gsi/mount.log`. 开机完成前 system_server 启动了 3 次时, 模块会自动停用自己, 把 crash 日志存到模块目录, 然后重启.

移植到别的底包时 `services/src/` 可能要改, 见 [DESIGN](doc/DESIGN.md#设计约束).

## 升级

换了 system 镜像(包括同一 GSI 的新版本)后, 必须用新镜像重新编 `services.jar` 并重新安装. 已录入的人脸数据存在 ParanoidSense 的应用数据里, 只要不清数据就会保留.

已经把人脸解锁做进镜像时**禁止**再装模块, 两份 `services.jar` 会冲突.

## 卸载

### 快速卸载

模块方式: 先在设置里删除人脸模型, 再在 KernelSU 或 Magisk 里卸载模块, 重启. 不先删除的话, 系统设置里会残留一条人脸登记记录.

### 完全卸载

模块方式同快速卸载. `co.aospa.sense` 是系统应用, 它从 system 分区消失后, 系统在下次开机时会删除它和它的数据(含人脸模板). 镜像方式需要刷回不含本项目文件的 system 镜像.

## 致谢

- [PixelOS-AOSP/packages_apps_ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense): 应用源码, 旷视库和模型
- [KLC_OS](https://github.com/LoggingNewMemory/KLC_OS) 的 `0009-feat-Add-Face-Unlock-with-ParanoidSense` 补丁(Chris Crump, Adithya R, Tobias Merkel, someone5678, aswin7469, Pranav Vashi): 框架部分的参考

## 许可证

Apache License 2.0(`Apache-2.0`), 全文见 [LICENSE](LICENSE). 旷视的库和模型不在本仓库中, 构建时从上游拉取, 见 [THIRD_PARTY_NOTICES](doc/THIRD_PARTY_NOTICES.md).
