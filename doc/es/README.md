# paranoidsense-gsi-port

<!-- Descomenta la siguiente línea cuando el proyecto tenga un icono -->
<!-- <img align="right" src="../resources/logo.png" width="160" alt="paranoidsense-gsi-port"> -->

[简体中文](../../README.md) | [English](../en/README.md) | **Español**

Portar el desbloqueo facial ParanoidSense de PixelOS a GSI de Android 15+ para los que no se puede obtener la firma de plataforma, sin recompilar la ROM. Este proyecto es un tutorial de portado y también la herramienta genérica para hacerlo.

[![License](https://img.shields.io/badge/License-Apache--2.0-orange)](../../LICENSE)

## Documentación

- Descripción general del proyecto: [README](README.md)

- Justificación del diseño: [DESIGN](DESIGN.md)

- Estado del proyecto: [LOG](LOG.md)
- Registros históricos: [HISTORY](HISTORY.md)
- Historial de cambios: [CHANGELOG](CHANGELOG.md)

- Avisos de terceros: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Introducción

- Reconocimiento facial 2D con la cámara frontal, usando el SDK de Megvii; nivel de biometría de Android WEAK (Clase 2). El nombre de paquete de la aplicación es `com.android.faceunlock`.
- El ParanoidSense original depende de la firma de plataforma: los permisos que necesita, `USE_BIOMETRIC_INTERNAL` y `MANAGE_BIOMETRIC`, son de nivel signature y una aplicación autofirmada no puede obtenerlos. Este proyecto modifica 57 comprobaciones de permisos en `services.jar` para permitir solo a `com.android.faceunlock` instalada en `/system/priv-app`, y hace que el sistema enlace su servicio en primer plano para evitar la restricción de la cámara en segundo plano. Para el principio, véase [DESIGN](DESIGN.md#arquitectura).
- La herramienta genera un `services.jar` modificado a partir del `services.jar` del propio GSI de destino, compila la aplicación de desbloqueo facial autofirmada y el overlay de Ajustes, y los empaqueta como módulo KernelSU / Magisk o los integra en la imagen del sistema.
- Para saber qué cambiar al pasar a otro GSI o dispositivo, véase el [tutorial de portado](porting-guide.md).

Estado de verificación: el GSI Pixel Tablet Mystic (Android 15, AP3A.241005.015) pasa en un dispositivo real Legion Y700 de tercera generación (TB321FU): el registro del rostro es correcto, y 10 desbloqueos consecutivos tras bloquear la pantalla y el desbloqueo tras la suspensión funcionan bien. La implementación de referencia para integrarlo en la imagen del sistema del TB321FU es [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch), que además contiene las adaptaciones para el GSI oficial de Android 15 (BP1A) y para Android 17 (CP3A). Para los problemas conocidos, véase [LOG](LOG.md#errores).

## Requisitos

- Dispositivo de destino: GSI de Android 15 o posterior, arm64, con cámara frontal
- Máquina de compilación: Linux, sudo (para montar el apex de ART), JDK 17, python3, git, zip, y además:

| Variable de entorno | Herramienta |
| --- | --- |
| `D2J` | `d2j-dex2jar.sh` de [dex2jar](https://github.com/ThexXTURBOXx/dex2jar) 2.4.38 |
| `R8` | `r8-8.5.35.jar` (incluye d8) |
| `APKTOOL` | el jar de [Apktool](https://github.com/iBotPeaches/Apktool) 2.12.1 |
| `BT` | directorio de Android build-tools 35 (aidl, aapt2, zipalign, apksigner) |
| `KOTLIN_HOME` | directorio de kotlinc 2.0.21 |
| `JAVA_HOME` | opcional, por defecto `/usr/lib/jvm/java-17-openjdk-amd64` |
| `KS` | opcional, keystore PKCS12 para firmar (alias `faceunlock`, contraseña `android`); si no se define, se genera automáticamente `sense/faceunlock.keystore` |

La lista de variables también está en [.env.example](../../.env.example).

- La imagen system original del GSI de destino y, una vez montada, su directorio `system/` (en adelante, "directorio system de la imagen base"). La compilación usa `framework/framework.jar`, `framework/services.jar`, `framework/framework-res.apk` y `apex/com.google.android.art.apex`
- Red: durante la compilación se descargan de [PixelOS ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense) las bibliotecas y los modelos de Megvii y los recursos de las páginas educativas de Ajustes. Estos archivos y los APK compilados **MUST NOT** subirse al repositorio

## Instalación

### Instalación rápida

Instalar como módulo KernelSU / Magisk:

```bash
scripts/fetch_upstream.sh
bash services/build.sh <directorio system de la imagen base> out/services
bash sense/build.sh <directorio system de la imagen base> out/sense
scripts/pack_module.sh out/services out/sense out/faceunlock_gsi.zip
```

Instale `out/faceunlock_gsi.zip` desde KernelSU o Magisk y reinicie.

**`services.jar` debe compilarse con la propia imagen base que se va a flashear**. Con un `services.jar` compilado a partir de otra imagen base, system_server no arrancará.

### Instalación normal

Integrar los archivos en la imagen del sistema, sin necesidad de root:

| Archivo | Destino | Permisos | SELinux |
| --- | --- | --- | --- |
| `out/services/services.jar` | sobrescribe `/system/framework/services.jar` | 0644 | `system_file` |
| `out/sense/FaceUnlock.apk` | `/system/priv-app/FaceUnlock/` (directorio 0755) | 0644 | `system_file` |
| `out/sense/FaceUnlockSettingsOverlay.apk` | `/system/product/overlay/` | 0644 | `system_file` |
| `module/system/etc/permissions/*.xml` | `/system/etc/permissions/` | 0644 | `system_file` |
| `module/system/etc/sysconfig/*.xml` | `/system/etc/sysconfig/` | 0644 | `system_file` |
| `image/default_permissions_com.android.faceunlock.xml` | `/system/product/etc/default-permissions/` | 0644 | `system_file` |
| `ro.face.sense_service=true` | añadir al final de `/system/build.prop` | | |

Elimine también `/system/framework/oat/arm64/services.*`; de lo contrario, el oat obsoleto hará que system_server recompile al arrancar. Tras los cambios hay que volver a añadir el AVB hashtree footer y firmar. La implementación de referencia está en [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch).

## Uso

Ajustes → Seguridad y privacidad → Desbloqueo del dispositivo → Desbloqueo facial → introduzca el PIN → siga las indicaciones para registrar el rostro. Después, en la pantalla de bloqueo basta con mirar a la cámara frontal para desbloquear.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # aparece SenseProvider
adb shell cmd overlay list | grep -i faceunlock    # [x]
```

El registro del método de módulo está en `/data/adb/modules/faceunlock_gsi/mount.log`. Si system_server se inicia 3 veces antes de completarse el arranque, el módulo se desactiva a sí mismo, guarda el registro de crash en el directorio del módulo y reinicia.

Al portar a otra imagen base puede ser necesario modificar `services/src/` y `services/apply_hooks.py`; los pasos están en el [tutorial de portado](porting-guide.md).

## Actualización

Tras cambiar la imagen del sistema (incluida una versión nueva del mismo GSI), **MUST** recompilar `services.jar` con la nueva imagen y volver a instalar. Los datos faciales registrados se guardan en los datos de la aplicación `com.android.faceunlock` y se conservan mientras no se borren los datos.

Si el desbloqueo facial ya está integrado en la imagen, **MUST NOT** instalar además el módulo: los dos `services.jar` entrarían en conflicto.

## Desinstalación

### Desinstalación rápida

Método de módulo: primero elimine el modelo facial en Ajustes, luego desinstale el módulo desde KernelSU o Magisk y reinicie. Si no lo elimina antes, quedará un registro de rostro residual en los ajustes del sistema.

### Desinstalación completa

Con el método de módulo, igual que la desinstalación rápida. `com.android.faceunlock` es una aplicación del sistema: cuando desaparece de la partición system, el sistema la elimina junto con sus datos (incluidas las plantillas faciales) en el siguiente arranque. Con el método de imagen hay que volver a flashear una imagen system sin los archivos de este proyecto.

## Agradecimientos

- [PixelOS-AOSP/packages_apps_ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense): código fuente de la aplicación, bibliotecas y modelos de Megvii y recursos de las páginas educativas de Ajustes
- El parche `0009-feat-Add-Face-Unlock-with-ParanoidSense` de [KLC_OS](https://github.com/LoggingNewMemory/KLC_OS) (Chris Crump, Adithya R, Tobias Merkel, someone5678, aswin7469, Pranav Vashi): referencia para la parte del framework

## Licencia

Este proyecto se publica bajo la Apache License 2.0, identificador SPDX `Apache-2.0`; el texto completo está en [LICENSE](../../LICENSE). Las bibliotecas y los modelos de Megvii y los recursos de las páginas educativas de Ajustes no están en este repositorio: se descargan del upstream durante la compilación; véase [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
