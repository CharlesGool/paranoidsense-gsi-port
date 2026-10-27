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

- [ ] 只在 TB321FU + Pixel Tablet Mystic GSI (AP3A.241005.015) 上验证过
- [ ] 模块 id 从测试时的 `tb321fu_faceunlock` 改成了 `paranoidsense_gsi`, 改名后的模块没有上机安装过; 内容和上机通过的 v5 相同

## 限制

- WEAK (Class 2) 生物识别只能用于解锁和弱校验, 不能授权支付, 也不能解锁要求强生物识别或 StrongBox 的 Keystore 凭据
- 2D 识别, 防照片攻击的能力不如结构光
- 自签名应用拿不到 signature 级权限, 只能在系统侧按身份放行

## 决策

| 日期 | 决策 | 状态 | 原因 |
| --- | --- | --- | --- |
| 2026-10-27 | 按 `co.aospa.sense` 系统 priv-app 身份放行 `USE_BIOMETRIC_INTERNAL` | 接受 | 两个所需权限都是 signature 级, 白名单给不了 |
| 2026-10-27 | SenseService 用 `BIND_FOREGROUND_SERVICE` 和 `BIND_INCLUDE_CAPABILITIES` 绑定 | 接受 | 避开 CAMERA 的 foreground-only 限制, 不需要常驻通知 |
| 2026-10-27 | 应用侧 `startForeground` + `foregroundServiceType=camera` | 拒绝 | 会一直显示通知 |
| 2026-10-27 | 旷视二进制和模型从上游固定 commit 拉取, 不放进仓库 | 接受 | 不再分发第三方专有二进制 |
| 2026-10-27 | 不发布编好的 `services.jar` | 接受 | 它只适用于生成它的那个底包 |

## 交接

- 分支: `main`
- 已完成: 从 TB321FU_PixelOS_15_Tangorpro 的 `faceunlock/clean/` 拆出源码和脚本; 签名密钥改为自动生成; 旷视文件改为从上游拉取; 文档
- 检查: 用新目录结构跑 `scripts/fetch_upstream.sh` 和 `sense/build.sh`, 两个 APK 除签名外每个条目与上机通过的版本一致, `check_dex.py` 0 问题; `services/build.sh` 以 TB321FU_PixelOS_15_Tangorpro V1 镜像为底包, 生成的 `services.jar` 与上机通过的 v5 字节相同(sha256 `eab2443e...`)
- 剩余: 在其他底包上验证
- 临时项目规则: 未发现
