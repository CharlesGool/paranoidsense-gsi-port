---
name: project-history-en
description: Historical Records
metadata:
  version: "1.0.0"
  lang: "en"
---

# Historical Records

## Multi-language

[简体中文](../HISTORY.md) | **English** | [Español](../es/HISTORY.md)

## Documentation

- Project overview: [README](README.md)

- Design rationale: [DESIGN](DESIGN.md)

- Project status: [LOG](LOG.md)
- Historical records: [HISTORY](HISTORY.md)
- Version changelog: [CHANGELOG](CHANGELOG.md)

- Third-party notices: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Historical Records

Debugging history of the KSU module stage (on TB321FU, 2026-10-27):

| Version | Result | Cause and fix |
| --- | --- | --- |
| v1 | system_server crash loop | d8 was run with `--no-desugaring`, causing `IncompatibleClassChangeError`; removed the flag |
| v2 | Enrollment page crashed | `USE_BIOMETRIC_INTERNAL` is signature-level; patched 57 checks |
| v3 | Enrollment page still crashed | `MANAGE_BIOMETRIC` is also signature-level and cannot be the pass condition; switched to allowing by identity |
| v4 | Enrollment worked, first few unlocks worked, then the camera was denied | CAMERA is foreground-only; changed the bind flags |
| v5 | All passed | |

Later developments:

- 2026-10-27: Split this repo out of `faceunlock/clean/` in TB321FU_PixelOS_15_Tangorpro.
- 2026-11-05: Package name changed to `com.android.faceunlock` (v2). The image patch for TB321FU was split into [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), where the BP1A and CP3A base images were also adapted; this repo became a generic porting guide and toolset.
