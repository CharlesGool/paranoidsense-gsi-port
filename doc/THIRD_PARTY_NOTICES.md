---
name: project-third-party-notices
description: 第三方署名与合规声明
metadata:
  version: "1.0.0"
  lang: "zh-CN"
---

# 第三方声明

## 多语言

**简体中文** | [English](en/THIRD_PARTY_NOTICES.md) | [Español](es/THIRD_PARTY_NOTICES.md)

## 文档

- 项目概览: [README](../README.md)

- 设计思路: [DESIGN](DESIGN.md)

- 项目状态: [LOG](LOG.md)
- 历史记录: [HISTORY](HISTORY.md)
- 变更日志: [CHANGELOG](CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## 第三方声明

### 组件清单

| 组件名称 | 版本或哈希 | 上游地址 | 许可证类型 | 使用方式 | 版权归属 | 发布合规义务 | 核验日期 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ParanoidSense | `a500478bbb0e2933276d57796d9b410f0f8e90f8`(`fifteen` 分支) | https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense | Apache-2.0 | `sense/` 由其修改而来; 构建时拉取其 `lib/` 和 `res/raw/` 编进 APK | Paranoid Android / PixelOS | 保留版权声明, 附许可证, 标明修改 | 2026-10-27 |
| 旷视人脸 SDK(`libmegface.so` 等 4 个 so, `vendorImplPrebuilt.jar`, `model_file`) | 同上 | 同上(`lib/`, `res/raw/`) | 未知(上游未单独声明) | 不在本仓库; 构建时拉取, 编进本地构建的 APK | Megvii | 未确定 | 2026-10-27 |
| KLC_OS `0009-feat-Add-Face-Unlock-with-ParanoidSense` 补丁 | 补丁内 commit `f78e9bc3` | https://github.com/LoggingNewMemory/KLC_OS | 仓库未声明; 补丁中的源文件头为 Apache-2.0 | `services/src/` 中 15 个类据其适配 | The Android Open Source Project, Paranoid Android | 保留源文件头的版权声明 | 2026-10-27 |
| AOSP frameworks/base | Android 15 | https://android.googlesource.com/platform/frameworks/base | Apache-2.0 | `services/src/` 的类派生自 AOSP 人脸代码 | The Android Open Source Project | 保留版权声明 | 2026-10-27 |

### 许可证文本

Apache License 2.0 全文: [LICENSE](../LICENSE)(取自 ParanoidSense 上游).

### 源代码提供

本仓库不分发二进制文件. 旷视的库和模型以二进制形式由上游提供, 没有源代码.

### 合规审查

暂无 Copyleft 组件. 旷视 SDK 的再分发条款无法确定; 本仓库只提供拉取脚本, 用户自行构建的 APK 包含这些文件.
