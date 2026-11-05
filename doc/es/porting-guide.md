---
name: porting-guide-es
description: "Pasos para portar el desbloqueo facial ParanoidSense a otra imagen base GSI o a otro dispositivo"
metadata:
  version: "1.0.0"
  updated: "2026-11-05"
  lang: "es"
---

# Tutorial de portado del desbloqueo facial

Este documento explica cómo portar el desbloqueo facial de este repositorio a otra imagen base GSI o a otro dispositivo. El código fuente del repositorio está adaptado al GSI Pixel Tablet Mystic (Android 15, AP3A.241005.015) y verificado en un dispositivo real Legion Y700 de tercera generación (TB321FU). [tb321fu-faceunlock-patch](https://github.com/CharlesGool/tb321fu-faceunlock-patch) documenta otros dos portados: el GSI oficial de Android 15 (BP1A.250505.005) y Android 17 (CP3A.260905.009); los ejemplos de abajo proceden de esos dos portados. Otras imágenes base y dispositivos no se han verificado; los puntos marcados como "por confirmar" hay que probarlos en el dispositivo de destino.

## Principio de funcionamiento

El ParanoidSense original se compila junto con la ROM: la aplicación lleva la firma de plataforma y el framework incluye el provider facial Sense correspondiente. En un GSI no se cumple ninguna de estas dos condiciones; este proyecto lo resuelve en tres partes:

| Parte | Directorio | Qué hace | Cambia con la imagen base |
| --- | --- | --- | --- |
| Framework | `services/` | Añade las clases del framework Sense al `services.jar` de la imagen base, modifica 57 comprobaciones de permisos y 3 puntos de entrada de Sense | Sí, hay que compilarlo para cada imagen base y puede requerir cambios en el código fuente |
| Aplicación | `sense/app/` | `com.android.faceunlock` autofirmada, ejecuta el SDK de Megvii y abre la cámara para el reconocimiento | Normalmente no hay que cambiarla |
| Entrada en Ajustes | `sense/overlay/` | Hace que el flujo de registro facial de Ajustes abra la interfaz de registro de la aplicación | Solo si cambian los nombres de recursos de Ajustes |

Casi todo el trabajo de portado está en la parte del framework. El `services.jar` de Pixel está optimizado con R8 y las firmas de clases y métodos cambian entre versiones; las clases adaptadas deben compilarse contra el bytecode de la imagen base de destino.

## Requisitos previos

| Elemento | Requisito | Cómo comprobarlo |
| --- | --- | --- |
| Versión de Android | 15 o posterior (min-api 35) | `getprop ro.build.version.sdk` ≥ 35 |
| Arquitectura | arm64 | Megvii solo ofrece bibliotecas arm64 |
| Cámara frontal | Se puede abrir con la API Camera1 | Por confirmar: `ro.face.sense_service.camera_id` permite indicar la cámara |
| Solución facial existente | La imagen base no tiene HAL facial propio | `dumpsys face` no muestra otros sensores; si los hay, las dos soluciones entrarían en conflicto, por confirmar |
| Nivel de protección de permisos | Conocer el nivel de protección de `USE_BIOMETRIC_INTERNAL` y `MANAGE_BIOMETRIC` | Ver `protectionLevel` en `adb shell pm list permissions -f`; si es `signature`, solo sirve el método de autorización de este proyecto |
| Máquina de compilación | Véanse los [requisitos del README](README.md#requisitos) | |

## Paso 1: obtener los archivos de la imagen base y el upstream

1. Monte la imagen system del GSI de destino para obtener el "directorio system de la imagen base".
2. Ejecute `scripts/fetch_upstream.sh` para descargar el upstream de ParanoidSense en el commit fijado (bibliotecas y modelos de Megvii, recursos de las páginas educativas de Ajustes).

El apex de ART de Android 17 tiene formato comprimido `com.google.android.art.capex`, y el `services/build.sh` de este repositorio solo reconoce `.apex`. Ante un capex, extraiga primero el `original_apex` interno, o consulte el [build_dex.sh de la versión cp3a](https://github.com/CharlesGool/tb321fu-faceunlock-patch/blob/main/patch/tangorpro_cp3a.260905.009/parts/001.services-hooks/src/build_dex.sh).

## Paso 2: compilar las clases del framework Sense

```bash
bash services/build.sh <directorio system de la imagen base> out/services
```

`services/build.sh` convierte `framework.jar`, `services.jar` y `core-libart.jar` de ART de la imagen base en un classpath y compila `services/src/`. Un error de javac indica que la firma de una clase de la imagen base ha cambiado, y hay que corregir el código fuente una a una según el bytecode de la imagen base. Para ver la firma de una clase de la imagen base:

```bash
$D2J -f -o /tmp/services-cp.jar <directorio system de la imagen base>/framework/services.jar
javap -p -cp /tmp/services-cp.jar com.android.server.biometrics.sensors.RemovalClient
```

Cambios de firma encontrados hasta ahora:

| Imagen base | Cambio | Corrección |
| --- | --- | --- |
| BP1A (Android 15 oficial) | El constructor de `HalClientMonitor` tiene un `isMandatoryBiometrics` más | Las 4 subclases de `HalClientMonitor` pasan `false` al final de la llamada a super |
| BP1A | `RemovalClient` tiene un `int reason` más | `FaceRemovalClient` y `FaceInternalCleanupClient.getRemovalClient` lo transmiten; `SenseProvider` pasa `3` |
| BP1A | `handleFailedAttempt` pasa a ser `final` | Se elimina la sobrescritura en `FaceAuthenticationClient` y se usa la versión de la clase base |
| BP1A | La clase base añade el método abstracto `getSensorId()` | Se implementa en `BiometricTestSessionImpl` |
| CP3A (Android 17) | `BiometricLogger.ofUnknown(Context)` y su constructor tienen un parámetro `Handler` más | Las 3 llamadas de `SenseProvider` pasan `mHandler` |

R8 además borra los genéricos, inlinea constantes y cambia métodos protected a public. Para el tratamiento en la adaptación original, véase [DESIGN](DESIGN.md#1-servicesjar-añadir-el-framework-sense).

Que compile no significa que sea correcto: si en la imagen base la llamada a un método de una clase base está inlineada por R8, la sobrescritura de la subclase nueva no tiene efecto en ese punto. Este tipo de problema no se detecta sin conexión; solo se ve en los registros del dispositivo en el paso 6.

## Paso 3: aplicar los parches smali

A continuación `services/build.sh` descompila el `services.jar` de la imagen base con apktool y ejecuta `services/apply_hooks.py`:

- 3 puntos de entrada de Sense: `AuthService.registerFaceSensors`, `FaceService$FaceServiceWrapper.getProviders` y el respaldo `canUseProvider` en `registerAuthenticators`.
- 57 comprobaciones de `USE_BIOMETRIC_INTERNAL` redirigidas a `SenseHooks`.

Al terminar, el script comprueba: si sigue habiendo puntos de llamada a `USE_BIOMETRIC_INTERNAL`, o algún punto de entrada no se ha encontrado, informa `FAIL` y sale. Cómo tratarlo:

1. `java -jar $APKTOOL d -r <imagen base>/framework/services.jar -o /tmp/svc`, y localice el archivo smali al que corresponde el error (por ejemplo `FaceService$FaceServiceWrapper.smali`).
2. Compare con los patrones de coincidencia de `apply_hooks.py` y averigüe qué diferencia de escritura tiene esta versión.
3. Añada una nueva coincidencia a `apply_hooks.py`, conservando las antiguas, de modo que el mismo script sea compatible con varias imágenes base.

Ejemplo: BP1A reestructuró `registerFaceSensors` y movió la etiqueta de registro `"AuthService"` al comienzo del método. El punto de inyección pasa a ser "justo después de la etiqueta al comienzo del método, y `canUseProvider()` lleva un `if-nez`". La estructura de Android 17 es igual que la de BP1A.

La distribución de los `_enforcePermission` puede variar entre imágenes base (CP3A: FaceServiceWrapper 32, BiometricServiceWrapper 20, AuthServiceImpl 5); vale la comprobación de residuos final del script.

## Paso 4: comprobar el dex

Ambos `build.sh` ejecutan `scripts/check_dex.py` y fallan si hay problemas. Comprueba:

- `invoke-custom` residuales: aparecen cuando d8 lleva `--no-desugaring`; ART lanza `IncompatibleClassChangeError` al ejecutarlos y system_server se reinicia en bucle. d8 **MUST NOT** llevar este parámetro.
- Tipo de llamada incorrecto en métodos private y acceso entre clases a miembros private.
- Referencias a clases que no existen en la imagen base.

## Paso 5: compilar la aplicación y el overlay de Ajustes

```bash
bash sense/build.sh <directorio system de la imagen base> out/sense
```

Normalmente no hace falta cambiar la aplicación. El overlay de Ajustes depende de los nombres de recursos de `com.android.settings` de la imagen base (`config_face_enroll`, `config_face_education_use_lottie`, etc.); aapt2 no comprueba esos nombres, y si cambian el overlay deja de aplicarse sin avisar. Al cambiar de versión mayor, compruebe primero en Settings de la imagen base que esos recursos siguen existiendo, por confirmar.

## Paso 6: instalar y verificar en el dispositivo

Verifique primero con el método de módulo (véase [README](README.md#instalación-rápida)); si falla, el módulo se desactiva solo tras 3 inicios de system_server. Una vez verificado, intégrelo en la imagen.

```bash
adb shell getprop ro.face.sense_service            # true
adb shell dumpsys face                             # aparecen SenseProvider y el sensor
adb shell cmd overlay list | grep -i faceunlock    # [x]
adb logcat -s SenseHooks SenseProvider SenseService
```

Registre el rostro en Ajustes, bloquee y desbloquee la pantalla al menos 10 veces seguidas y luego desbloquee tras dejar el dispositivo en suspensión unos minutos. Probar solo una o dos veces pasa por alto el problema de la restricción de la cámara en segundo plano.

## Solución de problemas

| Síntoma | Causa | Qué hacer |
| --- | --- | --- |
| system_server se reinicia en bucle, el registro tiene `IncompatibleClassChangeError` | d8 no hizo desugar | Quite `--no-desugaring` y vuelva a ejecutar `check_dex.py` |
| system_server se reinicia en bucle, el registro tiene `NoSuchMethodError` o `AbstractMethodError` | La firma de las clases adaptadas no coincide con la imagen base | Vuelva al paso 2 y compruebe con `javap` |
| La página de registro se bloquea al abrirla, el registro tiene `USE_BIOMETRIC_INTERNAL` o `MANAGE_BIOMETRIC` | Alguna comprobación de permisos no se ha permitido, o la aplicación no está en `/system/priv-app` | Revise la comprobación de residuos de `apply_hooks.py`; confirme dónde está instalada la aplicación |
| Las primeras veces desbloquea y luego no; CameraService informa `has been restricted` | La aplicación se trata como proceso en segundo plano; CAMERA es foreground-only | Confirme que `SenseProvider` enlaza con `BIND_FOREGROUND_SERVICE` y `BIND_INCLUDE_CAPABILITIES` |
| No hay entrada de rostro en Ajustes, o no responde al pulsarla | El overlay no se aplica, o no se ha registrado el sensor facial | `cmd overlay list`; `dumpsys face` |
| Al arrancar, system_server tarda mucho compilando services | La imagen conserva un oat de services obsoleto | Elimine `framework/oat/arm64/services.*` |

Para el proceso de depuración más antiguo, véase [HISTORY](HISTORY.md).

## Licencias

- El código de este repositorio se publica bajo Apache-2.0.
- Las bibliotecas y los modelos de Megvii y los recursos de las páginas educativas de Ajustes (recursos de Ajustes de Google Pixel) proceden del upstream de ParanoidSense y sus términos de redistribución no se pueden determinar. Los APK, módulos y paquetes de flasheo compilados incluyen esos archivos; antes de distribuirlos **MUST** confirmar por su cuenta la autorización. Véase [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
- El reconocimiento facial WEAK (Clase 2) **MUST NOT** usarse para proteger aplicaciones de pagos y banca.
