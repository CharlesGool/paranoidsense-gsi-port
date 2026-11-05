---
name: project-third-party-notices-es
description: Atribuciones y avisos de cumplimiento de terceros
metadata:
  version: "1.0.0"
  lang: "es"
---

# Avisos de terceros

## Multilingüe

[简体中文](../THIRD_PARTY_NOTICES.md) | [English](../en/THIRD_PARTY_NOTICES.md) | **Español**

## Documentación

- Descripción general del proyecto: [README](README.md)

- Justificación del diseño: [DESIGN](DESIGN.md)

- Estado del proyecto: [LOG](LOG.md)
- Registros históricos: [HISTORY](HISTORY.md)
- Historial de cambios: [CHANGELOG](CHANGELOG.md)

- Avisos de terceros: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Avisos de terceros

### Componentes

| Componente | Versión o hash | URL de origen | Licencia | Uso | Titular de los derechos | Obligaciones de distribución | Verificado el |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ParanoidSense | `a500478bbb0e2933276d57796d9b410f0f8e90f8` (rama `fifteen`) | https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense | Apache-2.0 | `sense/` deriva de él; durante la compilación se descargan sus `lib/`, `res/raw/` y `overlay/res/raw/` y se incluyen en el APK | Paranoid Android / PixelOS | Conservar el aviso de copyright, adjuntar la licencia, indicar las modificaciones | 2026-10-27 |
| SDK de reconocimiento facial de Megvii (4 so como `libmegface.so`, `vendorImplPrebuilt.jar`, `model_file`) | igual que arriba | igual que arriba (`lib/`, `res/raw/`) | Desconocida (el upstream no la declara por separado) | No está en este repositorio; se descarga durante la compilación y se incluye en el APK compilado localmente | Megvii | Sin determinar | 2026-10-27 |
| Recursos de las páginas educativas de Ajustes (`face_education_lottie.json`, `face_settings.mp4`) | igual que arriba, SHA-256 `7788f9ec...`, `f93fe186...` | igual que arriba (`overlay/res/raw/`) | Propietaria (recursos de Ajustes de Google Pixel, el upstream no la declara por separado) | No está en este repositorio; se descarga durante la compilación y se incluye en el `FaceUnlockSettingsOverlay.apk` compilado localmente. Estuvo en el repositorio antes del 2026-11-05 y sigue en commits antiguos | Google | Sin determinar; **MUST NOT** incluirse en el repositorio | 2026-11-05 |
| Parche KLC_OS `0009-feat-Add-Face-Unlock-with-ParanoidSense` | commit `f78e9bc3` dentro del parche | https://github.com/LoggingNewMemory/KLC_OS | No declarada en el repositorio; las cabeceras de los archivos fuente del parche son Apache-2.0 | 15 clases de `services/src/` están adaptadas a partir de él | The Android Open Source Project, Paranoid Android | Conservar el aviso de copyright de las cabeceras de los archivos fuente | 2026-10-27 |
| AOSP frameworks/base | Android 15 | https://android.googlesource.com/platform/frameworks/base | Apache-2.0 | Las clases de `services/src/` derivan del código facial de AOSP | The Android Open Source Project | Conservar el aviso de copyright | 2026-10-27 |

### Textos de licencia

Texto completo de la Apache License 2.0: [LICENSE](../../LICENSE) (tomado del upstream de ParanoidSense).

### Oferta de código fuente

Este repositorio no distribuye archivos binarios. Las bibliotecas y los modelos de Megvii los proporciona el upstream en forma binaria, sin código fuente.

### Revisión de cumplimiento

No hay componentes Copyleft. Los términos de redistribución del SDK de Megvii y de los recursos de las páginas educativas de Ajustes no se pueden determinar; este repositorio solo proporciona el script de descarga, y los APK y módulos que el usuario compila por su cuenta incluyen esos archivos; antes de distribuirlos **MUST** confirmar por su cuenta la autorización.
