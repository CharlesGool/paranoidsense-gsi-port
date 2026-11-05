---
name: project-third-party-notices-en
description: Third-party attribution and compliance notices
metadata:
  version: "1.0.0"
  lang: "en"
---

# Third-Party Notices

## Multi-language

[简体中文](../THIRD_PARTY_NOTICES.md) | **English** | [Español](../es/THIRD_PARTY_NOTICES.md)

## Documentation

- Project overview: [README](README.md)

- Design rationale: [DESIGN](DESIGN.md)

- Project status: [LOG](LOG.md)
- Historical records: [HISTORY](HISTORY.md)
- Version changelog: [CHANGELOG](CHANGELOG.md)

- Third-party notices: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Third-Party Notices

### Components

| Component | Version or hash | Upstream URL | License | Usage | Copyright holder | Release obligations | Verified on |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ParanoidSense | `a500478bbb0e2933276d57796d9b410f0f8e90f8` (`fifteen` branch) | https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense | Apache-2.0 | `sense/` is modified from it; at build time its `lib/`, `res/raw/` and `overlay/res/raw/` are fetched and built into the APK | Paranoid Android / PixelOS | Keep copyright notices, include the license, mark modifications | 2026-10-27 |
| Megvii face SDK (4 so files including `libmegface.so`, `vendorImplPrebuilt.jar`, `model_file`) | Same as above | Same as above (`lib/`, `res/raw/`) | Unknown (not declared separately upstream) | Not in this repo; fetched at build time and built into the locally built APK | Megvii | Not determined | 2026-10-27 |
| Settings education page assets (`face_education_lottie.json`, `face_settings.mp4`) | Same as above, SHA-256 `7788f9ec...`, `f93fe186...` | Same as above (`overlay/res/raw/`) | Proprietary (Google Pixel Settings resources, not declared separately upstream) | Not in this repo; fetched at build time and built into the locally built `FaceUnlockSettingsOverlay.apk`. Kept in the repo before 2026-11-05 and still present in old commits | Google | Not determined; **MUST NOT** go into the repo | 2026-11-05 |
| KLC_OS patch `0009-feat-Add-Face-Unlock-with-ParanoidSense` | Commit `f78e9bc3` inside the patch | https://github.com/LoggingNewMemory/KLC_OS | Not declared by the repo; source file headers in the patch are Apache-2.0 | 15 classes in `services/src/` are adapted from it | The Android Open Source Project, Paranoid Android | Keep the copyright notices in the source file headers | 2026-10-27 |
| AOSP frameworks/base | Android 15 | https://android.googlesource.com/platform/frameworks/base | Apache-2.0 | The classes in `services/src/` are derived from AOSP face code | The Android Open Source Project | Keep copyright notices | 2026-10-27 |

### License Texts

Full text of the Apache License 2.0: [LICENSE](../../LICENSE) (taken from the ParanoidSense upstream).

### Source Code Offer

This repo does not distribute binary files. The Megvii libraries and models are provided upstream in binary form, without source code.

### Compliance Review

No copyleft components yet. The redistribution terms of the Megvii SDK and the settings education page assets cannot be determined; this repo only provides fetch scripts, and the APK and module a user builds contain these files, so the user **MUST** confirm the licensing themselves before distributing.
