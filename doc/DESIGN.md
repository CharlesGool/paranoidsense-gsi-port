---
name: project-design
description: 项目架构与设计约束
metadata:
  version: "1.0.0"
  lang: "zh-CN"
---

# paranoidsense-gsi-port — 设计

## 多语言

**简体中文** | [English](en/DESIGN.md) | [Español](es/DESIGN.md)

## 文档

- 项目概览: [README](../README.md)

- 设计思路: [DESIGN](DESIGN.md)

- 项目状态: [LOG](LOG.md)
- 历史记录: [HISTORY](HISTORY.md)
- 变更日志: [CHANGELOG](CHANGELOG.md)

- 第三方声明: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## 设计目标

- [x] 不需要 platform 签名, 不重新编 ROM
- [x] 只对装在 system 分区的 `co.aospa.sense` 放宽权限, 其他调用方的检查不变
- [x] 不常驻前台通知
- [x] 仓库不包含旷视的二进制文件
- [ ] 在 TB321FU 以外的底包上验证

## 架构

原版 ParanoidSense 和 ROM 一起编: 应用用 platform 签名, 以 `android.uid.system` 运行, 框架里有配套的 Sense 人脸 provider. GSI 上这几个条件都不成立. 本项目分三部分补上:

| 目录 | 职责 |
| --- | --- |
| `services/` | `src/`: Sense 框架源码; `apply_hooks.py`: smali 补丁; `build.sh`: 从底包生成新的 `services.jar` |
| `sense/` | `app/`: 改过的 ParanoidSense 应用; `overlay/`: 设置 overlay; `build.sh`: 编译并签名两个 APK |
| `module/` | KernelSU / Magisk 模块的脚本, 属性和权限 xml |
| `image/` | 只在做进 system 镜像时用的文件 |
| `scripts/` | `fetch_upstream.sh` 拉上游, `check_dex.py` 检查 dex, `pack_module.sh` 打模块 |
| `third_party/` | `fetch_upstream.sh` 拉下来的上游 ParanoidSense, 不提交 |
| `out/` | 构建输出, 不提交 |

### 1. services.jar: 加入 Sense 框架

参考 KLC_OS 的 `0009-feat-Add-Face-Unlock-with-ParanoidSense` 补丁, 把其中新增的 15 个类(`SenseProvider`, 各个 `Face*Client` 等)按目标底包的 `services.jar` 适配, 和 3 个新类(`SenseHooks`, `SenseSchedulerFactory`, `SenseCurrentUserRetriever`)及 2 个 AIDL 生成的类一起编成 `classes4.dex`, 加进原 jar. 原 jar 的其他 dex 和资源不动.

Pixel 底包的 `services.jar` 经过 R8 优化, 和 AOSP 源码有出入, 适配时改了:

- 泛型被擦除, 基类改用 raw type, `getFreshDaemon()` 加强制转换
- 被内联的常量换成数值(`STATE_STARTED=1`, `STATE_STOPPED=4`, `LOCKOUT_NONE/TIMED/PERMANENT=0/1/2`, 前三个在字节码里核对过)
- 很多方法从 protected 变成 public, 覆盖方法跟着改成 public; 补上底包里是抽象方法的 `scheduleWatchdog`, `scheduleInvalidateAuthenticatorId`, `onAddUnknownTemplate`, `startHalOperation`, `onClientFinished`
- `BiometricScheduler` 不改, 用底包已有的 5 参数构造函数加 `SenseCurrentUserRetriever`

原补丁对 `FaceService` 和 `AuthService` 的 3 处改动, 在 smali 层改为调用 `SenseHooks`.

### 2. 权限: 按调用方身份放行

`USE_BIOMETRIC_INTERNAL` 和 `MANAGE_BIOMETRIC` 都是 signature 级(不是 `signature|privileged`), privapp 白名单对它们无效. `services/apply_hooks.py` 把生物识别服务里 57 处 `USE_BIOMETRIC_INTERNAL` 检查改走 `SenseHooks.enforceInternal()` / `hasInternal()`:

| 位置 | 处数 |
| --- | --- |
| AIDL `@EnforcePermission` 生成的 `*_enforcePermission()`: FaceServiceWrapper 32, BiometricServiceWrapper 17, AuthServiceImpl 3 | 52 |
| 直接检查: `FaceServiceWrapper.addAuthenticatorsRegisteredCallback` 1, `AuthService.checkInternalPermission` 1, `AuthServiceImpl.setActiveUser` 1, `FingerprintService$1.getSensorPropertiesInternal` 2 | 5 |
| `Utils.hasInternalPermission(Context)` 的方法体 | 另外 1 个方法 |

`SenseHooks` 满足任一条件即放行:

1. 调用方是 system, root 或 system_server 自己
2. 调用方持有 `USE_BIOMETRIC_INTERNAL` 或 `MANAGE_BIOMETRIC`(原有行为)
3. 调用方 uid 下有 `co.aospa.sense`, 且它带 `FLAG_SYSTEM` 并且 `isPrivilegedApp()`. 查询包信息时用 `Binder.clearCallingIdentity()` 包住

条件 3 要求应用装在 `/system/priv-app/`, 用户自行安装的同名应用不满足.

`apply_hooks.py` 可重复运行; 运行后检查整棵 smali, 不允许再出现 `USE_BIOMETRIC_INTERNAL` 字面值.

### 3. 相机: 前台绑定

`co.aospa.sense` 的 CAMERA 权限在 appops 层面是 foreground-only. system_server 只用 `BIND_AUTO_CREATE` 绑定 SenseService 时, 过了启动后的缓冲期进程就被算作后台, CameraService 报 `has been restricted` 拒绝打开相机, 表现是头几次能解锁, 之后不行.

`SenseProvider` 改为用 `BIND_AUTO_CREATE | BIND_FOREGROUND_SERVICE | BIND_INCLUDE_CAPABILITIES` 绑定: 前者把被绑定的进程提到前台级, 后者把 system_server 的相机能力传给它. 应用不调用 `startForeground`, 所以没有常驻通知.

### 4. 应用

- 去掉 `sharedUserId="android.uid.system"` 和 setupdesign / setupcompat 依赖, 录入界面改用标准组件
- 应用进程的 classpath 里没有 kotlin-stdlib 和 `services.jar`, Kotlin 标准库, AIDL stub 和 `vendorImplPrebuilt.jar` 都编进 APK 的 dex
- `/system/priv-app` 下的应用不解压 so: 4 个旷视 so 不压缩并页对齐放进 APK, `extractNativeLibs="false"`, 直接从 APK 加载
- 设置里的人脸解锁入口和动画由 `SenseSettingsOverlay`(目标 `com.android.settings`)提供

### 5. 构建检查

d8 **禁止**加 `--no-desugaring`: javac 17 把 private 方法的方法引用(如 `this::getDaemon`)编成 invokedynamic, 不 desugar 时 dex 里留下 `invoke-custom ... invoke-instance@private`, ART 执行到就抛 `IncompatibleClassChangeError`, system_server 循环重启. `scripts/check_dex.py` 检查残留的 invoke-custom, private 方法的 invoke 类型, 跨类访问 private 成员和引用不存在的类; 两个 `build.sh` 都会运行它, 有问题就失败. 它查不出 R8 内联导致的问题, 见下面的约束.

### 6. 模块

`module/post-fs-data.sh` 单独 bind mount `services.jar`; 需要新增文件的目录(`priv-app`, `etc/permissions`, `etc/sysconfig`, `product/overlay`)先复制到 tmpfs, 再用 overlayfs 叠到 system 上(overlayfs 不接受 `/data` 上的 f2fs 做 lowerdir). 不依赖 meta-overlayfs.
`module/service.sh` 在开机完成前发现 system_server 启动了 3 次时停用模块并重启; 开机后等 pm 可用, 再给 `co.aospa.sense` 授予 CAMERA(模块方式下 default-permissions 目录不一定存在).

## 设计约束

- `services.jar` 只能从要刷的那个底包生成, 不同底包之间**禁止**混用
- `services/src/` 是按 Pixel Tablet AP3A.241005.015 的 `services.jar` 适配的. 换底包时 javac 报错要按底包的字节码修改; 编译通过也不代表正确: R8 可能把某些基类方法的调用内联掉, 新子类的覆盖在那些地方不生效, 只能上机看日志
- 权限放行**禁止**扩大到 `co.aospa.sense` 系统 priv-app 以外的调用方
- 仓库**禁止**包含旷视的 so, jar 和模型文件, 以及签名密钥
- 要求 Android 15 (min-api 35), arm64
