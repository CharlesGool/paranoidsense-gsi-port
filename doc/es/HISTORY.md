---
name: project-history-es
description: Registros históricos
metadata:
  version: "1.0.0"
  lang: "es"
---

# Registros históricos

## Multilingüe

[简体中文](../HISTORY.md) | [English](../en/HISTORY.md) | **Español**

## Documentación

- Descripción general del proyecto: [README](README.md)

- Justificación del diseño: [DESIGN](DESIGN.md)

- Estado del proyecto: [LOG](LOG.md)
- Registros históricos: [HISTORY](HISTORY.md)
- Historial de cambios: [CHANGELOG](CHANGELOG.md)

- Avisos de terceros: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Registros históricos

Proceso de depuración de la fase del módulo KSU (en el TB321FU, 2026-10-27):

| Versión | Resultado | Causa y corrección |
| --- | --- | --- |
| v1 | system_server se bloquea en bucle | d8 usó `--no-desugaring`, `IncompatibleClassChangeError`; se quitó ese parámetro |
| v2 | La página de registro se bloquea | `USE_BIOMETRIC_INTERNAL` es de nivel signature; se modificaron 57 comprobaciones |
| v3 | La página de registro sigue bloqueándose | `MANAGE_BIOMETRIC` también es de nivel signature y no sirve como condición de paso; se cambió a permitir por identidad |
| v4 | Se puede registrar, las primeras veces desbloquea, después se rechaza la cámara | CAMERA es foreground-only; se cambiaron los parámetros de enlace |
| v5 | Todo correcto | |

Evolución posterior:

- 2026-10-27: este repositorio se separó de `faceunlock/clean/` de TB321FU_PixelOS_15_Tangorpro.
- 2026-11-05: el nombre de paquete pasó a `com.android.faceunlock` (v2). El parche de imagen para el TB321FU se separó en [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), donde además se adaptaron las imágenes base BP1A y CP3A; este repositorio pasó a ser un tutorial de portado y herramienta genéricos.
