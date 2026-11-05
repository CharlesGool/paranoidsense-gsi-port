---
name: project-log-en
description: Project bugs, limitations, decisions, and handoff
metadata:
  version: "1.0.0"
  lang: "en"
---

# Log

## Multi-language

[简体中文](../LOG.md) | **English** | [Español](../es/LOG.md)

## Documentation

- Project overview: [README](README.md)

- Design rationale: [DESIGN](DESIGN.md)

- Project status: [LOG](LOG.md)
- Historical records: [HISTORY](HISTORY.md)
- Version changelog: [CHANGELOG](CHANGELOG.md)

- Third-party notices: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Records

- [History](HISTORY.md)
- [Changelog](CHANGELOG.md)

## Bugs

- [ ] Verified on a real device only on TB321FU + Pixel Tablet Mystic GSI (AP3A.241005.015). The BP1A and CP3A adaptations are in [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch); the source in this repo does not include them.
- [ ] The module renamed to `com.android.faceunlock` (id `faceunlock_gsi`) has not been installed on a device; the app is the same as the version that passed on-device testing in TB321FU-GSI-Mods.
- [ ] `services/build.sh` does not support the compressed ART apex (`.capex`) of Android 17, see [porting guide](porting-guide.md#step-1-get-the-base-files-and-upstream).

## Limitations

- WEAK (Class 2) biometrics can only be used for unlock and weak verification; they cannot authorize payments and cannot unlock Keystore credentials that require strong biometrics or StrongBox
- 2D recognition; resistance to photo attacks is weaker than structured light
- A self-signed app cannot get signature-level permissions, so they can only be granted by identity on the system side

## Decisions

| Date | Decision | Status | Reason |
| --- | --- | --- | --- |
| 2026-10-27 | Allow `USE_BIOMETRIC_INTERNAL` by system priv-app identity | Accepted | Both required permissions are signature-level; an allowlist cannot grant them |
| 2026-10-27 | SenseService is bound with `BIND_FOREGROUND_SERVICE` and `BIND_INCLUDE_CAPABILITIES` | Accepted | Avoids the CAMERA foreground-only restriction without a persistent notification |
| 2026-10-27 | App-side `startForeground` + `foregroundServiceType=camera` | Rejected | It would show a notification all the time |
| 2026-10-27 | Fetch the Megvii binaries and models from a pinned upstream commit instead of keeping them in the repo | Accepted | No longer distributes third-party proprietary binaries |
| 2026-10-27 | Do not publish a built `services.jar` | Accepted | It only works with the base image it was generated from |
| 2026-11-05 | Change the app package name to `com.android.faceunlock` and the module id to `faceunlock_gsi` | Accepted | Avoids detection that treats `co.aospa.sense` as a third-party ROM signature |
| 2026-11-05 | This repo serves as a generic porting guide and toolset; the TB321FU image patch is split into tb321fu-faceunlock-patch | Accepted | The guide targets all GSIs, while the patch only applies to TB321FU |
| 2026-11-05 | Settings education page assets are no longer kept in the repo; they are taken from upstream `overlay/res/raw/` at build time | Accepted | The assets are Google's Pixel Settings resources; the upstream files have the same SHA-256 as the files previously kept in the repo |

## Handoff

The current handoff is maintained in the [Simplified Chinese LOG.md](../LOG.md#交接).
