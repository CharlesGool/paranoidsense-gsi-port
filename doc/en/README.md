# paranoidsense-gsi-port

<!-- Uncomment the next line when the project has an icon -->
<!-- <img align="right" src="../resources/logo.png" width="160" alt="paranoidsense-gsi-port"> -->

[简体中文](../../README.md) | **English** | [Español](../es/README.md)

Port PixelOS's ParanoidSense face unlock to Android 15+ GSIs that cannot get the platform signature, without rebuilding the ROM. This project is both a porting guide and a general-purpose toolset for doing so.

[![License](https://img.shields.io/badge/License-Apache--2.0-orange)](../../LICENSE)

## Documentation

- Project overview: [README](README.md)

- Design rationale: [DESIGN](DESIGN.md)

- Project status: [LOG](LOG.md)
- Historical records: [HISTORY](HISTORY.md)
- Version changelog: [CHANGELOG](CHANGELOG.md)

- Third-party notices: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Introduction

- 2D face recognition with the front camera, using the Megvii SDK, at Android biometric class WEAK (Class 2). The app package name is `com.android.faceunlock`.
- The original ParanoidSense depends on the platform signature: the `USE_BIOMETRIC_INTERNAL` and `MANAGE_BIOMETRIC` permissions it needs are both signature-level and cannot be obtained by a self-signed app. This project patches 57 permission checks in `services.jar` so that only `com.android.faceunlock` installed in `/system/priv-app` is allowed, and makes the system bind its service in the foreground to get around the camera's background restriction. For the principle see [DESIGN](DESIGN.md#architecture).
- The tools generate a patched `services.jar` from the target GSI's own `services.jar`, build a self-signed face unlock app and a settings overlay, and then package them as a KernelSU / Magisk module or build them into the system image.
- For what to change when moving to another GSI or device, see the [porting guide](porting-guide.md).

Verification: Pixel Tablet Mystic GSI (Android 15, AP3A.241005.015) passed on a real Lenovo Legion Y700 Gen 3 (TB321FU): enrollment works, and 10 consecutive lock-screen unlocks and unlock after standby all work. The reference implementation for building it into the system image on TB321FU is [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), which also has adaptations for the official Android 15 GSI (BP1A) and Android 17 (CP3A). For known issues see [LOG](LOG.md#bugs).

## Requirements

- Target device: Android 15 or newer GSI, arm64, with a front camera
- Build machine: Linux, sudo (to mount the ART apex), JDK 17, python3, git, zip, and:

| Environment variable | Tool |
| --- | --- |
| `D2J` | `d2j-dex2jar.sh` from [dex2jar](https://github.com/ThexXTURBOXx/dex2jar) 2.4.38 |
| `R8` | `r8-8.5.35.jar` (includes d8) |
| `APKTOOL` | The jar of [Apktool](https://github.com/iBotPeaches/Apktool) 2.12.1 |
| `BT` | Android build-tools 35 directory (aidl, aapt2, zipalign, apksigner) |
| `KOTLIN_HOME` | kotlinc 2.0.21 directory |
| `JAVA_HOME` | Optional, defaults to `/usr/lib/jvm/java-17-openjdk-amd64` |
| `KS` | Optional, PKCS12 keystore for signing (alias `faceunlock`, password `android`); when unset, `sense/faceunlock.keystore` is generated automatically |

The variable list is also in [.env.example](../../.env.example).

- The stock system image of the target GSI, and its `system/` directory after mounting (called the "base system directory" below). The build needs `framework/framework.jar`, `framework/services.jar`, `framework/framework-res.apk`, `apex/com.google.android.art.apex`
- Network: at build time, Megvii's libraries, models and the settings education page assets are fetched from [PixelOS ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense). These files and the built APKs **MUST NOT** be committed to the repo

## Install

### Quick Install

Install as a KernelSU / Magisk module:

```bash
scripts/fetch_upstream.sh
bash services/build.sh <base system directory> out/services
bash sense/build.sh <base system directory> out/sense
scripts/pack_module.sh out/services out/sense out/faceunlock_gsi.zip
```

Install `out/faceunlock_gsi.zip` in KernelSU or Magisk and reboot.

**`services.jar` must be built from the very base image you are going to flash**. With a `services.jar` built from a different base image, system_server will not start.

### Normal Install

Build the files into the system image; no root needed:

| File | Put it at | Permissions | SELinux |
| --- | --- | --- | --- |
| `out/services/services.jar` | Overwrite `/system/framework/services.jar` | 0644 | `system_file` |
| `out/sense/FaceUnlock.apk` | `/system/priv-app/FaceUnlock/` (directory 0755) | 0644 | `system_file` |
| `out/sense/FaceUnlockSettingsOverlay.apk` | `/system/product/overlay/` | 0644 | `system_file` |
| `module/system/etc/permissions/*.xml` | `/system/etc/permissions/` | 0644 | `system_file` |
| `module/system/etc/sysconfig/*.xml` | `/system/etc/sysconfig/` | 0644 | `system_file` |
| `image/default_permissions_com.android.faceunlock.xml` | `/system/product/etc/default-permissions/` | 0644 | `system_file` |
| `ro.face.sense_service=true` | Append to `/system/build.prop` | | |

Also delete `/system/framework/oat/arm64/services.*`, otherwise the stale oat makes system_server recompile at boot. After the changes, re-add the AVB hashtree footer and sign. For a reference implementation see [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch).

## Usage

Settings > Security & privacy > Device unlock > Face unlock > enter PIN > enroll as prompted. After that, face the front camera on the lock screen to unlock.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # has SenseProvider
adb shell cmd overlay list | grep -i faceunlock    # [x]
```

For the module method, the log is at `/data/adb/modules/faceunlock_gsi/mount.log`. If system_server starts 3 times before boot completes, the module disables itself, saves the crash log in the module directory, and then reboots.

When porting to another base image, `services/src/` and `services/apply_hooks.py` may need changes; for the steps see the [porting guide](porting-guide.md).

## Upgrade

After changing the system image (including a new version of the same GSI), you **MUST** rebuild `services.jar` with the new image and reinstall. The enrolled face data is stored in the app data of `com.android.faceunlock` and is kept as long as the data is not cleared.

When face unlock is already built into the image, you **MUST NOT** install the module as well; the two `services.jar` copies would conflict.

## Uninstall

### Quick Uninstall

Module method: first delete the face model in Settings, then uninstall the module in KernelSU or Magisk and reboot. If you do not delete it first, a face enrollment record remains in system settings.

### Full Uninstall

For the module method, same as quick uninstall. `com.android.faceunlock` is a system app; after it disappears from the system partition, the system deletes it and its data (including face templates) at the next boot. For the image method, flash back a system image that does not contain this project's files.

## Acknowledgements

- [PixelOS-AOSP/packages_apps_ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense): app source, Megvii libraries, models and settings education page assets
- The `0009-feat-Add-Face-Unlock-with-ParanoidSense` patch of [KLC_OS](https://github.com/LoggingNewMemory/KLC_OS) (Chris Crump, Adithya R, Tobias Merkel, someone5678, aswin7469, Pranav Vashi): reference for the framework part

## License

This project is licensed under the Apache License 2.0, SPDX identifier `Apache-2.0`; full text in [LICENSE](../../LICENSE). Megvii's libraries and models, and the settings education page assets, are not in this repo; they are fetched from upstream at build time, see [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
