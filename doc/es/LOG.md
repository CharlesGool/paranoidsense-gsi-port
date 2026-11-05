---
name: project-log-es
description: Errores, limitaciones, decisiones y traspaso del proyecto
metadata:
  version: "1.0.0"
  lang: "es"
---

# Registro

## Multilingüe

[简体中文](../LOG.md) | [English](../en/LOG.md) | **Español**

## Documentación

- Descripción general del proyecto: [README](README.md)

- Justificación del diseño: [DESIGN](DESIGN.md)

- Estado del proyecto: [LOG](LOG.md)
- Registros históricos: [HISTORY](HISTORY.md)
- Historial de cambios: [CHANGELOG](CHANGELOG.md)

- Avisos de terceros: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Registros

- [Registros históricos](HISTORY.md)
- [Historial de cambios](CHANGELOG.md)

## Errores

- [ ] Solo verificado en un dispositivo real con TB321FU + GSI Pixel Tablet Mystic (AP3A.241005.015). Las adaptaciones a BP1A y CP3A están en [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch); el código fuente de este repositorio no las incorpora.
- [ ] El módulo (id `faceunlock_gsi`) con el nombre cambiado a `com.android.faceunlock` no se ha instalado en un dispositivo; la aplicación es la misma versión que pasó las pruebas en dispositivo en TB321FU-GSI-Mods.
- [ ] `services/build.sh` no admite el apex de ART comprimido de Android 17 (`.capex`); véase el [tutorial de portado](porting-guide.md#paso-1-obtener-los-archivos-de-la-imagen-base-y-el-upstream).

## Limitaciones

- La biometría WEAK (Clase 2) solo sirve para desbloquear y para verificaciones débiles; no puede autorizar pagos ni desbloquear credenciales de Keystore que exijan biometría fuerte o StrongBox
- Reconocimiento 2D: su resistencia a ataques con fotografías es inferior a la de la luz estructurada
- Una aplicación autofirmada no puede obtener permisos de nivel signature; solo se puede permitir por identidad desde el lado del sistema

## Decisiones

| Fecha | Decisión | Estado | Motivo |
| --- | --- | --- | --- |
| 2026-10-27 | Permitir `USE_BIOMETRIC_INTERNAL` según la identidad de aplicación priv-app del sistema | Aceptada | Los dos permisos necesarios son de nivel signature y la lista blanca no puede concederlos |
| 2026-10-27 | Enlazar SenseService con `BIND_FOREGROUND_SERVICE` y `BIND_INCLUDE_CAPABILITIES` | Aceptada | Evita la restricción foreground-only de CAMERA sin necesitar una notificación permanente |
| 2026-10-27 | `startForeground` + `foregroundServiceType=camera` en la aplicación | Rechazada | Mostraría una notificación todo el tiempo |
| 2026-10-27 | Descargar los binarios y modelos de Megvii de un commit fijo del upstream, sin incluirlos en el repositorio | Aceptada | Dejar de distribuir binarios propietarios de terceros |
| 2026-10-27 | No publicar el `services.jar` compilado | Aceptada | Solo sirve para la imagen base con la que se generó |
| 2026-11-05 | Nombre de paquete de la aplicación cambiado a `com.android.faceunlock`, id del módulo cambiado a `faceunlock_gsi` | Aceptada | Evitar la detección que toma `co.aospa.sense` como rasgo de ROM de terceros |
| 2026-11-05 | Este repositorio es el tutorial de portado y la herramienta genéricos; el parche de imagen del TB321FU se separa en tb321fu-faceunlock-patch | Aceptada | El tutorial sirve para todos los GSI; el parche solo es aplicable al TB321FU |
| 2026-11-05 | Los recursos de las páginas educativas de Ajustes ya no se incluyen en el repositorio; se toman del `overlay/res/raw/` del upstream durante la compilación | Aceptada | Los recursos son de Ajustes de Pixel de Google; los archivos del upstream tienen el mismo SHA-256 que los que estaban en el repositorio |

## Traspaso

Consulte el traspaso vigente en el [LOG.md en chino simplificado](../LOG.md#交接).
