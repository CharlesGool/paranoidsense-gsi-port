---
name: porting-guide
description: "把 ParanoidSense 人脸解锁移植到另一个 GSI 底包或设备上的步骤"
metadata:
  version: "1.0.0"
  updated: "2026-11-05"
  lang: "zh-CN"
---

# 人脸解锁移植教程

本文说明如何把本仓库的人脸解锁移植到另一个 GSI 底包或另一台设备上. 本仓库的源码按 Pixel Tablet Mystic GSI (Android 15, AP3A.241005.015) 适配, 并在拯救者 Y700 三代 (TB321FU) 上真机验证. [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch) 记录了另外两次移植: Android 15 官方 GSI (BP1A.250505.005) 和 Android 17 (CP3A.260905.009), 下文的例子都来自这两次. 其他底包和设备未验证, 文中标为 "需确认" 的地方要在目标设备上实测.

## 原理

原版 ParanoidSense 和 ROM 一起编: 应用用 platform 签名, framework 里有配套的 Sense 人脸 provider. GSI 上这两个条件都不成立, 本项目分三部分补上:

| 部分 | 目录 | 做什么 | 是否随底包变化 |
| --- | --- | --- | --- |
| 框架 | `services/` | 往底包的 `services.jar` 加入 Sense 框架类, 改 57 处权限检查和 3 处 Sense 入口 | 是, 每个底包都要编, 可能要改源码 |
| 应用 | `sense/app/` | 自签名的 `com.android.faceunlock`, 跑旷视 SDK, 开相机做识别 | 一般不用改 |
| 设置入口 | `sense/overlay/` | 让设置的人脸录入流程打开应用的录入界面 | 设置的资源名变了才要改 |

移植工作几乎都在框架部分. Pixel 的 `services.jar` 经过 R8 优化, 类和方法签名随版本变化, 适配类必须对着目标底包的字节码编译.

## 前提

| 项目 | 要求 | 检查方法 |
| --- | --- | --- |
| Android 版本 | 15 或更新 (min-api 35) | `getprop ro.build.version.sdk` ≥ 35 |
| 架构 | arm64 | 旷视只提供 arm64 库 |
| 前置摄像头 | 能用 Camera1 API 打开 | 需确认: `ro.face.sense_service.camera_id` 可指定相机 |
| 现有人脸方案 | 底包没有自己的人脸 HAL | `dumpsys face` 没有其他传感器; 有的话两套会冲突, 需确认 |
| 权限级别 | 了解 `USE_BIOMETRIC_INTERNAL`, `MANAGE_BIOMETRIC` 的保护级别 | `adb shell pm list permissions -f` 中查看 `protectionLevel`; 是 `signature` 时只能走本项目的放行方式 |
| 构建机 | 见 [README 的要求](../README.md#要求) | |

## 步骤 1: 取底包文件和上游

1. 挂载目标 GSI 的 system 镜像, 得到"底包 system 目录".
2. 运行 `scripts/fetch_upstream.sh`, 拉取固定 commit 的 ParanoidSense 上游 (旷视库, 模型, 设置教育页素材).

Android 17 的 ART apex 是压缩格式 `com.google.android.art.capex`, 本仓库的 `services/build.sh` 只认 `.apex`. 遇到 capex 时先解出内层 `original_apex`, 或参照 [cp3a 版的 build_dex.sh](https://github.com/CharlesGool/tb321fu-faceunlock-patch/blob/main/patch/tangorpro_cp3a.260905.009/parts/001.services-hooks/src/build_dex.sh).

## 步骤 2: 编译 Sense 框架类

```bash
bash services/build.sh <底包 system 目录> out/services
```

`services/build.sh` 把底包的 `framework.jar`, `services.jar` 和 ART 的 `core-libart.jar` 转成 classpath, 编译 `services/src/`. javac 报错说明底包的类签名变了, 要逐个对着底包字节码改源码. 查看底包里某个类的签名:

```bash
$D2J -f -o /tmp/services-cp.jar <底包 system 目录>/framework/services.jar
javap -p -cp /tmp/services-cp.jar com.android.server.biometrics.sensors.RemovalClient
```

已遇到的签名变化:

| 底包 | 变化 | 改法 |
| --- | --- | --- |
| BP1A (Android 15 官方) | `HalClientMonitor` 构造器多了 `isMandatoryBiometrics` | 4 个 `HalClientMonitor` 子类在 super 调用末尾传 `false` |
| BP1A | `RemovalClient` 多了 `int reason` | `FaceRemovalClient`, `FaceInternalCleanupClient.getRemovalClient` 透传; `SenseProvider` 传 `3` |
| BP1A | `handleFailedAttempt` 变成 `final` | 删掉 `FaceAuthenticationClient` 里的覆盖, 用基类版本 |
| BP1A | 基类新增抽象方法 `getSensorId()` | 在 `BiometricTestSessionImpl` 实现 |
| CP3A (Android 17) | `BiometricLogger.ofUnknown(Context)` 和构造器多了 `Handler` 参数 | `SenseProvider` 的 3 处调用传 `mHandler` |

R8 还会擦除泛型, 内联常量, 把 protected 方法改成 public. 原版适配时的处理见 [DESIGN](DESIGN.md#1-servicesjar-加入-sense-框架).

编译通过不代表正确: 如果底包里某个基类方法的调用点被 R8 内联, 新子类的覆盖在那里不生效. 这种问题离线查不出, 只能在步骤 6 上机看日志.

## 步骤 3: 打 smali 补丁

`services/build.sh` 接着用 apktool 反编译底包的 `services.jar`, 运行 `services/apply_hooks.py`:

- 3 处 Sense 入口: `AuthService.registerFaceSensors`, `FaceService$FaceServiceWrapper.getProviders`, `registerAuthenticators` 中的 `canUseProvider` 兜底.
- 57 处 `USE_BIOMETRIC_INTERNAL` 检查改走 `SenseHooks`.

脚本打完会检查: 仍有 `USE_BIOMETRIC_INTERNAL` 调用点, 或某个入口没命中, 就报 `FAIL` 并退出. 处理方法:

1. `java -jar $APKTOOL d -r <底包>/framework/services.jar -o /tmp/svc`, 找到报错对应的 smali 文件 (如 `FaceService$FaceServiceWrapper.smali`).
2. 对照 `apply_hooks.py` 里的匹配模式, 找出这一版的写法差异.
3. 给 `apply_hooks.py` 加新的匹配, 保留旧的, 让同一个脚本兼容多个底包.

例: BP1A 重构了 `registerFaceSensors`, 把 `"AuthService"` 日志 tag 提到了方法开头. 注入点改为 "方法开头的 tag 之后, `canUseProvider()` 加 `if-nez`". Android 17 的结构与 BP1A 相同.

各个底包的 `_enforcePermission` 分布可能不同 (CP3A: FaceServiceWrapper 32, BiometricServiceWrapper 20, AuthServiceImpl 5), 以脚本最后的残留检查为准.

## 步骤 4: 检查 dex

两个 `build.sh` 都会运行 `scripts/check_dex.py`, 有问题就失败. 它检查:

- 残留的 `invoke-custom`: d8 加了 `--no-desugaring` 时出现, ART 执行到就抛 `IncompatibleClassChangeError`, system_server 循环重启. d8 **禁止**加这个参数.
- private 方法的调用类型错误, 跨类访问 private 成员.
- 引用了底包里不存在的类.

## 步骤 5: 编应用和设置 overlay

```bash
bash sense/build.sh <底包 system 目录> out/sense
```

应用一般不用改. 设置 overlay 依赖底包 `com.android.settings` 的资源名 (`config_face_enroll`, `config_face_education_use_lottie` 等); aapt2 不检查这些名字, 名字变了 overlay 会静默不生效. 换大版本时先在底包的 Settings 里确认这些资源还在, 需确认.

## 步骤 6: 安装和上机验证

先用模块方式验证 (见 [README](../README.md#快速安装)), 失败时模块会在 system_server 启动 3 次后自动停用. 验证通过后再做进镜像.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # 有 SenseProvider 和传感器
adb shell cmd overlay list | grep -i faceunlock    # [x]
adb logcat -s SenseHooks SenseProvider SenseService
```

在设置里录入人脸, 然后连续锁屏解锁至少 10 次, 再待机几分钟后解锁. 只测一两次会漏掉相机后台限制的问题.

## 排错

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| system_server 循环重启, 日志有 `IncompatibleClassChangeError` | d8 没有 desugar | 去掉 `--no-desugaring`, 重跑 `check_dex.py` |
| system_server 循环重启, 日志有 `NoSuchMethodError` 或 `AbstractMethodError` | 适配类的签名和底包不一致 | 回到步骤 2, 用 `javap` 核对 |
| 录入页打开就崩, 日志有 `USE_BIOMETRIC_INTERNAL` 或 `MANAGE_BIOMETRIC` | 有权限检查没被放行, 或应用不在 `/system/priv-app` | 检查 `apply_hooks.py` 的残留检查; 确认应用的安装位置 |
| 头几次能解锁, 之后不行, CameraService 报 `has been restricted` | 应用被当作后台进程, CAMERA 是 foreground-only | 确认 `SenseProvider` 用 `BIND_FOREGROUND_SERVICE` 和 `BIND_INCLUDE_CAPABILITIES` 绑定 |
| 设置里没有人脸入口, 或点了没反应 | overlay 没生效, 或没有注册人脸传感器 | `cmd overlay list`; `dumpsys face` |
| 开机时 system_server 编译 services 很久 | 镜像里留着过期的 services oat | 删除 `framework/oat/arm64/services.*` |

更早的调试过程见 [HISTORY](HISTORY.md).

## 授权

- 本仓库的代码以 Apache-2.0 授权.
- 旷视的库和模型, 以及设置教育页素材 (Google 的 Pixel 设置资源) 来自 ParanoidSense 上游, 再分发条款无法确定. 编出的 APK, 模块和刷机包都含这些文件, 分发前**必须**自行确认授权. 见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
- WEAK (Class 2) 人脸识别**禁止**用于保护支付和银行类应用.
