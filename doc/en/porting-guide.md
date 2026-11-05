---
name: porting-guide-en
description: "Steps to port ParanoidSense face unlock to another GSI base image or device"
metadata:
  version: "1.0.0"
  updated: "2026-11-05"
  lang: "en"
---

# Face Unlock Porting Guide

This document explains how to port this repo's face unlock to another GSI base image or another device. The source in this repo is adapted to the Pixel Tablet Mystic GSI (Android 15, AP3A.241005.015) and verified on a real Lenovo Legion Y700 Gen 3 (TB321FU). [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch) records two other ports: the official Android 15 GSI (BP1A.250505.005) and Android 17 (CP3A.260905.009); the examples below all come from these two. Other base images and devices are unverified, and the places marked "to be confirmed" must be tested on the target device.

## Principle

The original ParanoidSense is built together with the ROM: the app is signed with the platform key, and the framework has a matching Sense face provider. On a GSI neither condition holds, and this project fills them in with three parts:

| Part | Directory | What it does | Changes with the base image |
| --- | --- | --- | --- |
| Framework | `services/` | Adds the Sense framework classes to the base image's `services.jar`, patches 57 permission checks and 3 Sense entry points | Yes, must be built for every base image, source may need changes |
| App | `sense/app/` | Self-signed `com.android.faceunlock`, runs the Megvii SDK, opens the camera for recognition | Usually no change needed |
| Settings entry | `sense/overlay/` | Makes Settings' face enrollment flow open the app's enrollment UI | Only when Settings resource names change |

Almost all porting work is in the framework part. Pixel's `services.jar` is optimized by R8, and class and method signatures change between versions; the adaptation classes must be compiled against the target base image's bytecode.

## Prerequisites

| Item | Requirement | How to check |
| --- | --- | --- |
| Android version | 15 or newer (min-api 35) | `getprop ro.build.version.sdk` >= 35 |
| Architecture | arm64 | Megvii only provides arm64 libraries |
| Front camera | Can be opened with the Camera1 API | To be confirmed: `ro.face.sense_service.camera_id` can specify the camera |
| Existing face solution | The base image has no face HAL of its own | `dumpsys face` shows no other sensor; if there is one the two would conflict, to be confirmed |
| Permission level | Know the protection level of `USE_BIOMETRIC_INTERNAL` and `MANAGE_BIOMETRIC` | Check `protectionLevel` in `adb shell pm list permissions -f`; if it is `signature`, only this project's allowance method works |
| Build machine | See [README requirements](README.md#requirements) | |

## Step 1: Get the base files and upstream

1. Mount the target GSI's system image to get the "base system directory".
2. Run `scripts/fetch_upstream.sh` to fetch the pinned commit of the ParanoidSense upstream (Megvii libraries, models, settings education page assets).

Android 17's ART apex is the compressed format `com.google.android.art.capex`, while this repo's `services/build.sh` only recognizes `.apex`. When you hit a capex, first extract the inner `original_apex`, or follow the [build_dex.sh of the cp3a version](https://github.com/CharlesGool/tb321fu-faceunlock-patch/blob/main/patch/tangorpro_cp3a.260905.009/parts/001.services-hooks/src/build_dex.sh).

## Step 2: Compile the Sense framework classes

```bash
bash services/build.sh <base system directory> out/services
```

`services/build.sh` converts the base image's `framework.jar`, `services.jar` and ART's `core-libart.jar` into a classpath and compiles `services/src/`. A javac error means the base image's class signatures changed, and the source must be fixed one by one against the base image's bytecode. To see the signature of a class in the base image:

```bash
$D2J -f -o /tmp/services-cp.jar <base system directory>/framework/services.jar
javap -p -cp /tmp/services-cp.jar com.android.server.biometrics.sensors.RemovalClient
```

Signature changes encountered so far:

| Base image | Change | Fix |
| --- | --- | --- |
| BP1A (official Android 15) | `HalClientMonitor` constructor gained `isMandatoryBiometrics` | The 4 `HalClientMonitor` subclasses pass `false` at the end of the super call |
| BP1A | `RemovalClient` gained `int reason` | `FaceRemovalClient` and `FaceInternalCleanupClient.getRemovalClient` pass it through; `SenseProvider` passes `3` |
| BP1A | `handleFailedAttempt` became `final` | Delete the override in `FaceAuthenticationClient` and use the base class version |
| BP1A | Base class gained abstract method `getSensorId()` | Implemented in `BiometricTestSessionImpl` |
| CP3A (Android 17) | `BiometricLogger.ofUnknown(Context)` and the constructor gained a `Handler` parameter | The 3 calls in `SenseProvider` pass `mHandler` |

R8 also erases generics, inlines constants and turns protected methods into public. For how the original adaptation handled this see [DESIGN](DESIGN.md#1-servicesjar-add-the-sense-framework).

Compiling successfully does not mean it is correct: if a call site of some base-class method in the base image is inlined by R8, the new subclass's override does not take effect there. This kind of problem cannot be found offline and can only be seen in the logs on a device in Step 6.

## Step 3: Apply the smali patches

`services/build.sh` then decompiles the base image's `services.jar` with apktool and runs `services/apply_hooks.py`:

- 3 Sense entry points: `AuthService.registerFaceSensors`, `FaceService$FaceServiceWrapper.getProviders`, and the `canUseProvider` fallback in `registerAuthenticators`.
- 57 `USE_BIOMETRIC_INTERNAL` checks rerouted to `SenseHooks`.

After patching, the script checks: if a `USE_BIOMETRIC_INTERNAL` call site remains or an entry point was not matched, it reports `FAIL` and exits. How to handle it:

1. `java -jar $APKTOOL d -r <base image>/framework/services.jar -o /tmp/svc`, and find the smali file the error refers to (such as `FaceService$FaceServiceWrapper.smali`).
2. Compare with the matching patterns in `apply_hooks.py` and find how this version is written differently.
3. Add a new match to `apply_hooks.py`, keeping the old ones, so that the same script works with multiple base images.

Example: BP1A refactored `registerFaceSensors` and moved the `"AuthService"` log tag to the start of the method. The injection point became "after the tag at the start of the method, add `if-nez` on `canUseProvider()`". Android 17 has the same structure as BP1A.

The distribution of `_enforcePermission` may differ between base images (CP3A: FaceServiceWrapper 32, BiometricServiceWrapper 20, AuthServiceImpl 5); go by the residual check at the end of the script.

## Step 4: Check the dex

Both `build.sh` scripts run `scripts/check_dex.py` and fail on any problem. It checks:

- Leftover `invoke-custom`: appears when d8 is given `--no-desugaring`; ART throws `IncompatibleClassChangeError` when it reaches it, and system_server restarts in a loop. d8 **MUST NOT** be given this flag.
- Wrong invoke types for private methods, and cross-class access to private members.
- References to classes that do not exist in the base image.

## Step 5: Build the app and the settings overlay

```bash
bash sense/build.sh <base system directory> out/sense
```

The app usually needs no changes. The settings overlay depends on resource names in the base image's `com.android.settings` (`config_face_enroll`, `config_face_education_use_lottie`, etc.); aapt2 does not check these names, and if a name changed the overlay silently does not take effect. When changing major version, first confirm in the base image's Settings that these resources are still there, to be confirmed.

## Step 6: Install and verify on a device

First verify with the module method (see [README](README.md#quick-install)); on failure the module disables itself after system_server starts 3 times. Build it into the image only after verification passes.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # has SenseProvider and a sensor
adb shell cmd overlay list | grep -i faceunlock    # [x]
adb logcat -s SenseHooks SenseProvider SenseService
```

Enroll a face in Settings, then lock and unlock at least 10 times in a row, and unlock again after a few minutes of standby. Testing only once or twice misses the camera background restriction problem.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| system_server restarts in a loop, log has `IncompatibleClassChangeError` | d8 did not desugar | Remove `--no-desugaring`, rerun `check_dex.py` |
| system_server restarts in a loop, log has `NoSuchMethodError` or `AbstractMethodError` | Adaptation class signatures do not match the base image | Go back to Step 2 and verify with `javap` |
| Enrollment page crashes on open, log has `USE_BIOMETRIC_INTERNAL` or `MANAGE_BIOMETRIC` | A permission check was not allowed, or the app is not in `/system/priv-app` | Check the residual check of `apply_hooks.py`; confirm the app's install location |
| First few unlocks work, then they stop, CameraService reports `has been restricted` | The app is treated as a background process, CAMERA is foreground-only | Confirm `SenseProvider` binds with `BIND_FOREGROUND_SERVICE` and `BIND_INCLUDE_CAPABILITIES` |
| No face entry in Settings, or tapping it does nothing | The overlay did not take effect, or no face sensor is registered | `cmd overlay list`; `dumpsys face` |
| system_server compiles services for a long time at boot | The image still has a stale services oat | Delete `framework/oat/arm64/services.*` |

For the earlier debugging history see [HISTORY](HISTORY.md).

## Licensing

- The code in this repo is licensed under Apache-2.0.
- Megvii's libraries and models, and the settings education page assets (Google's Pixel Settings resources), come from the ParanoidSense upstream, and their redistribution terms cannot be determined. The built APKs, modules and flashable packages all contain these files, so you **MUST** confirm the licensing yourself before distributing. See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
- WEAK (Class 2) face recognition **MUST NOT** be used to protect payment and banking apps.
