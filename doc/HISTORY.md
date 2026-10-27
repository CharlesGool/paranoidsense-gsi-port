---
name: project-history
description: 历史记录
metadata:
  version: "1.0.0"
  lang: "zh-CN"
---

# 历史记录

## 多语言

**简体中文** | [English](en/HISTORY.md) | [Español](es/HISTORY.md)

## 文档

- 项目概览: [README](../README.md)

- 设计思路: [DESIGN](DESIGN.md)

- 项目状态: [LOG](LOG.md)
- 历史记录: [HISTORY](HISTORY.md)
- 变更日志: [CHANGELOG](CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## 历史记录

KSU 模块阶段的调试过程(在 TB321FU 上, 2026-10-27):

| 版本 | 结果 | 原因和修复 |
| --- | --- | --- |
| v1 | system_server 循环崩溃 | d8 用了 `--no-desugaring`, `IncompatibleClassChangeError`; 去掉该参数 |
| v2 | 录入页崩溃 | `USE_BIOMETRIC_INTERNAL` 是 signature 级; 改 57 处检查 |
| v3 | 录入页仍崩溃 | `MANAGE_BIOMETRIC` 也是 signature 级, 不能作为放行条件; 改为按身份放行 |
| v4 | 能录入, 头几次能解锁, 之后相机被拒 | CAMERA foreground-only; 改绑定参数 |
| v5 | 全部通过 | |
