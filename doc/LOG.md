---
name: project-log
description: 项目缺陷, 限制, 决策和交接
metadata:
  version: "1.0.0"
  lang: "zh-CN"
---

# 日志

## 多语言

**简体中文** | [English](en/LOG.md) | [Español](es/LOG.md)

## 文档

- 项目概览: [README](../README.md)

- 设计思路: [DESIGN](DESIGN.md)

- 项目状态: [LOG](LOG.md)
- 历史记录: [HISTORY](HISTORY.md)
- 变更日志: [CHANGELOG](CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## 记录

- [历史记录](HISTORY.md)
- [变更日志](CHANGELOG.md)

## 缺陷

- [ ] 只在 TB321FU + Pixel Tablet Mystic GSI (AP3A.241005.015) 上真机验证过. BP1A 和 CP3A 的适配见 [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), 本仓库的源码没有合入这些适配.
- [ ] 改名为 `com.android.faceunlock` 后的模块 (id `faceunlock_gsi`) 没有上机安装过; 应用和 TB321FU-GSI-Mods 中上机通过的版本相同.
- [ ] `services/build.sh` 不支持 Android 17 的压缩 ART apex (`.capex`), 见[移植教程](porting-guide.md#步骤-1-取底包文件和上游).

## 限制

- WEAK (Class 2) 生物识别只能用于解锁和弱校验, 不能授权支付, 也不能解锁要求强生物识别或 StrongBox 的 Keystore 凭据
- 2D 识别, 防照片攻击的能力不如结构光
- 自签名应用拿不到 signature 级权限, 只能在系统侧按身份放行

## 决策

| 日期 | 决策 | 状态 | 原因 |
| --- | --- | --- | --- |
| 2026-10-27 | 按系统 priv-app 身份放行 `USE_BIOMETRIC_INTERNAL` | 接受 | 两个所需权限都是 signature 级, 白名单给不了 |
| 2026-10-27 | SenseService 用 `BIND_FOREGROUND_SERVICE` 和 `BIND_INCLUDE_CAPABILITIES` 绑定 | 接受 | 避开 CAMERA 的 foreground-only 限制, 不需要常驻通知 |
| 2026-10-27 | 应用侧 `startForeground` + `foregroundServiceType=camera` | 拒绝 | 会一直显示通知 |
| 2026-10-27 | 旷视二进制和模型从上游固定 commit 拉取, 不放进仓库 | 接受 | 不再分发第三方专有二进制 |
| 2026-10-27 | 不发布编好的 `services.jar` | 接受 | 它只适用于生成它的那个底包 |
| 2026-11-05 | 应用包名改为 `com.android.faceunlock`, 模块 id 改为 `faceunlock_gsi` | 接受 | 避开把 `co.aospa.sense` 当作第三方 ROM 特征的检测 |
| 2026-11-05 | 本仓库作为通用移植教程和工具; TB321FU 的镜像补丁拆到 tb321fu-faceunlock-patch | 接受 | 教程面向所有 GSI, 补丁只适用于 TB321FU |
| 2026-11-05 | 设置教育页素材不再入库, 构建时从上游 `overlay/res/raw/` 取 | 接受 | 素材是 Google 的 Pixel 设置资源; 上游文件与原入库文件 SHA-256 相同 |

## 交接

- 分支: `main`.
- 已完成: 合入 v2 分支 (包名改为 `com.android.faceunlock`); 设置教育页素材改为构建时从上游取, 不再入库; 新增[移植教程](porting-guide.md); 文档按现行模板重写并完整翻译为英文和西班牙语; TB321FU 的镜像补丁拆到 tb321fu-faceunlock-patch.
- 检查: shell 脚本 `bash -n`, Python `py_compile` 通过; 文档链接检查通过. 设置 overlay 的同一构建逻辑在 tb321fu-faceunlock-patch 中用 AP3A 的 framework-res 重编, 除签名外与原 APK 内容相同. 本次未重新构建 `services.jar` 和 `FaceUnlock.apk`, 也未上机.
- 剩余步骤:
  - [ ] 上机安装改名后的模块 `faceunlock_gsi` 并验证.
  - [ ] 把 BP1A 和 CP3A 的适配合入 `services/`, 或保持只在补丁仓库中维护.
  - [ ] `services/build.sh` 支持 `.capex`.
- 阻碍: 无.
- 临时项目规则: 未发现.
