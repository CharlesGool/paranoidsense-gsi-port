---
name: project-design-es
description: Arquitectura y restricciones de diseño del proyecto
metadata:
  version: "1.0.0"
  lang: "es"
---

# paranoidsense-gsi-port — Diseño

## Multilingüe

[简体中文](../DESIGN.md) | [English](../en/DESIGN.md) | **Español**

## Documentación

- Descripción general del proyecto: [README](README.md)

- Justificación del diseño: [DESIGN](DESIGN.md)

- Estado del proyecto: [LOG](LOG.md)
- Registros históricos: [HISTORY](HISTORY.md)
- Historial de cambios: [CHANGELOG](CHANGELOG.md)

- Avisos de terceros: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

## Objetivos de diseño

- [x] No necesitar firma de plataforma ni recompilar la ROM
- [x] Relajar los permisos solo para `com.android.faceunlock` instalada en la partición system; las comprobaciones para otros llamantes no cambian
- [x] Sin notificación permanente en primer plano
- [x] El repositorio no contiene los binarios de Megvii ni los recursos de las páginas educativas de Ajustes
- [x] Ofrecer un tutorial para portar a otras imágenes base: [porting-guide](porting-guide.md)
- [ ] Verificar en dispositivos distintos del TB321FU
- [ ] `services/build.sh` admite el apex de ART comprimido de Android 17 (`.capex`)

## Arquitectura

El ParanoidSense original se compila junto con la ROM: la aplicación lleva la firma de plataforma y se ejecuta como `android.uid.system`, y el framework incluye el provider facial Sense correspondiente. En un GSI no se cumple ninguna de estas condiciones. Este proyecto lo resuelve en tres partes:

| Directorio | Responsabilidad |
| --- | --- |
| `services/` | `src/`: código fuente del framework Sense; `apply_hooks.py`: parches smali; `build.sh`: genera un nuevo `services.jar` a partir de la imagen base |
| `sense/` | `app/`: la aplicación ParanoidSense modificada (`com.android.faceunlock`); `overlay/`: overlay de Ajustes, con los recursos de las páginas educativas tomados del upstream durante la compilación; `build.sh`: compila y firma `FaceUnlock.apk` y `FaceUnlockSettingsOverlay.apk` |
| `module/` | Scripts, propiedades y xml de permisos del módulo KernelSU / Magisk |
| `image/` | Archivos que solo se usan al integrar en la imagen del sistema |
| `scripts/` | `fetch_upstream.sh` descarga el upstream, `check_dex.py` comprueba el dex, `pack_module.sh` empaqueta el módulo |
| `third_party/` | El ParanoidSense upstream descargado por `fetch_upstream.sh`, no se sube |
| `out/` | Salida de la compilación, no se sube |
| `doc/` | Documentación del proyecto y [tutorial de portado](porting-guide.md) |

### 1. services.jar: añadir el framework Sense

Siguiendo el parche `0009-feat-Add-Face-Unlock-with-ParanoidSense` de KLC_OS, las 15 clases nuevas que contiene (`SenseProvider`, los distintos `Face*Client`, etc.) se adaptan al `services.jar` de la imagen base de destino y se compilan en `classes4.dex` junto con 3 clases nuevas (`SenseHooks`, `SenseSchedulerFactory`, `SenseCurrentUserRetriever`) y 2 clases generadas por AIDL, que se añade al jar original. Los demás dex y recursos del jar original no se tocan.

El `services.jar` de la imagen base Pixel está optimizado con R8 y difiere del código fuente de AOSP, por lo que en la adaptación se cambió:

- Los genéricos están borrados: las clases base usan raw type y `getFreshDaemon()` lleva una conversión explícita
- Las constantes inlineadas se sustituyen por valores numéricos (`STATE_STARTED=1`, `STATE_STOPPED=4`, `LOCKOUT_NONE/TIMED/PERMANENT=0/1/2`; los tres primeros se comprobaron en el bytecode)
- Muchos métodos pasaron de protected a public y las sobrescrituras se cambian a public en consecuencia; se añaden `scheduleWatchdog`, `scheduleInvalidateAuthenticatorId`, `onAddUnknownTemplate`, `startHalOperation` y `onClientFinished`, que en la imagen base son métodos abstractos
- `BiometricScheduler` no se modifica: se usa el constructor de 5 parámetros que ya existe en la imagen base, con `SenseCurrentUserRetriever`

Los 3 cambios que el parche original hace en `FaceService` y `AuthService` se convierten, a nivel smali, en llamadas a `SenseHooks`.

### 2. Permisos: permitir según la identidad del llamante

`USE_BIOMETRIC_INTERNAL` y `MANAGE_BIOMETRIC` son ambos de nivel signature (no `signature|privileged`), por lo que la lista blanca privapp no les afecta. `services/apply_hooks.py` redirige 57 comprobaciones de `USE_BIOMETRIC_INTERNAL` del servicio de biometría a `SenseHooks.enforceInternal()` / `hasInternal()`:

| Ubicación | Cantidad |
| --- | --- |
| `*_enforcePermission()` generados por `@EnforcePermission` de AIDL: FaceServiceWrapper 32, BiometricServiceWrapper 17, AuthServiceImpl 3 | 52 |
| Comprobaciones directas: `FaceServiceWrapper.addAuthenticatorsRegisteredCallback` 1, `AuthService.checkInternalPermission` 1, `AuthServiceImpl.setActiveUser` 1, `FingerprintService$1.getSensorPropertiesInternal` 2 | 5 |
| El cuerpo de `Utils.hasInternalPermission(Context)` | 1 método adicional |

`SenseHooks` permite el paso si se cumple cualquiera de estas condiciones:

1. El llamante es system, root o el propio system_server
2. El llamante tiene `USE_BIOMETRIC_INTERNAL` o `MANAGE_BIOMETRIC` (comportamiento original)
3. Bajo el uid del llamante existe `com.android.faceunlock`, con `FLAG_SYSTEM` y `isPrivilegedApp()`. La consulta de la información del paquete se envuelve con `Binder.clearCallingIdentity()`

La condición 3 exige que la aplicación esté instalada en `/system/priv-app/`; una aplicación homónima instalada por el usuario no la cumple.

`apply_hooks.py` se puede ejecutar repetidamente; tras ejecutarlo se revisa todo el smali y no se permite que vuelva a aparecer el literal `USE_BIOMETRIC_INTERNAL`.

### 3. Cámara: enlace en primer plano

El permiso CAMERA de `com.android.faceunlock` es foreground-only a nivel de appops. Si system_server enlaza SenseService solo con `BIND_AUTO_CREATE`, pasado el periodo de gracia posterior al arranque el proceso se cuenta como segundo plano, CameraService rechaza abrir la cámara con `has been restricted` y el síntoma es que las primeras veces desbloquea y después no.

`SenseProvider` se cambió para enlazar con `BIND_AUTO_CREATE | BIND_FOREGROUND_SERVICE | BIND_INCLUDE_CAPABILITIES`: el segundo eleva el proceso enlazado a nivel de primer plano y el tercero le transmite la capacidad de cámara de system_server. La aplicación no llama a `startForeground`, por lo que no hay notificación permanente.

### 4. Aplicación

- Se quita `sharedUserId="android.uid.system"` y las dependencias setupdesign / setupcompat; la interfaz de registro usa componentes estándar
- El classpath del proceso de la aplicación no contiene kotlin-stdlib ni `services.jar`; la biblioteca estándar de Kotlin, los stubs AIDL y `vendorImplPrebuilt.jar` se compilan en el dex del APK
- Las aplicaciones en `/system/priv-app` no descomprimen los so: los 4 so de Megvii se incluyen en el APK sin comprimir y alineados a página, con `extractNativeLibs="false"`, y se cargan directamente desde el APK
- La entrada de desbloqueo facial en Ajustes y la animación las proporciona `FaceUnlockSettingsOverlay` (objetivo `com.android.settings`)
- El nombre de paquete es `com.android.faceunlock`, para evitar la detección que toma `co.aospa.sense` como rasgo de ROM de terceros. El manifest sigue declarando `co.aospa.sense` y aapt2 link lo renombra con `--rename-manifest-package`; las dos clases bajo `co.aospa.sense.util` conservan el nombre de paquete original

### 5. Comprobaciones de compilación

d8 **MUST NOT** llevar `--no-desugaring`: javac 17 compila las referencias a métodos private (como `this::getDaemon`) como invokedynamic; sin desugar, en el dex queda `invoke-custom ... invoke-instance@private`, y ART lanza `IncompatibleClassChangeError` al ejecutarlo, con lo que system_server se reinicia en bucle. `scripts/check_dex.py` comprueba los invoke-custom residuales, el tipo de invoke de los métodos private, el acceso entre clases a miembros private y las referencias a clases inexistentes; ambos `build.sh` lo ejecutan y fallan si hay problemas. No detecta los problemas causados por el inlining de R8; véanse las restricciones más abajo.

### 6. Módulo

`module/post-fs-data.sh` hace bind mount de `services.jar` por separado; los directorios donde hay que añadir archivos nuevos (`priv-app`, `etc/permissions`, `etc/sysconfig`, `product/overlay`) se copian primero a tmpfs y luego se superponen sobre system con overlayfs (overlayfs no acepta f2fs de `/data` como lowerdir). No depende de meta-overlayfs.
`module/service.sh` desactiva el módulo y reinicia si detecta que system_server se inició 3 veces antes de completarse el arranque; tras el arranque espera a que pm esté disponible y concede CAMERA a `com.android.faceunlock` (con el método de módulo, el directorio default-permissions no siempre existe).

## Restricciones de diseño

- `services.jar` solo se puede generar a partir de la imagen base que se va a flashear; **MUST NOT** mezclarse entre imágenes base distintas
- `services/src/` está adaptado al `services.jar` de Pixel Tablet AP3A.241005.015. Al cambiar de imagen base, los errores de javac se corrigen según el bytecode de esa imagen, con los pasos en [porting-guide](porting-guide.md); que compile tampoco garantiza que sea correcto: R8 puede inlinear llamadas a ciertos métodos de la clase base, y en esos puntos las sobrescrituras de las subclases nuevas no tienen efecto; solo se detecta mirando los registros en un dispositivo
- La autorización de permisos **MUST NOT** ampliarse a llamantes distintos de la aplicación priv-app del sistema `com.android.faceunlock`
- El repositorio **MUST NOT** contener los so, jar y modelos de Megvii, los recursos de las páginas educativas de Ajustes, los APK compilados ni claves de firma
- Requiere Android 15 (min-api 35), arm64

## Diseño de datos

Datos de ejecución en el dispositivo, que no están en el repositorio:

| Ubicación | Contenido |
| --- | --- |
| Datos de la aplicación `com.android.faceunlock` | Plantillas faciales y estado del registro. Borrar los datos de la aplicación elimina los rostros |
| `/data/adb/modules/faceunlock_gsi/mount.log` | Registro de montaje y de protección de arranque del método de módulo; cuando se desactiva automáticamente, el registro de crash también se guarda en el directorio del módulo |
| `ro.face.sense_service=true` | system_server registra `SenseProvider` según esta propiedad |
| `ro.face.sense_service.camera_id` | Opcional, indica la cámara que se usa para el reconocimiento |

## Interfaces externas

| Interfaz | Proveedor | Uso |
| --- | --- | --- |
| `framework.jar`, `services.jar`, `framework-res.apk` y apex de ART de la imagen base | GSI de destino | classpath de compilación, entrada de los parches smali, enlace de recursos |
| Bibliotecas y modelos de Megvii y recursos de las páginas educativas de Ajustes | [PixelOS ParanoidSense](https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense), commit fijo | Compilar los dos APK |
| `vendor.aospa.biometrics.face.ISenseService` | Este proyecto (AIDL) | Interfaz de reconocimiento entre system_server y la aplicación |
| Formato de módulo KernelSU / Magisk (`post-fs-data.sh`, `service.sh`, `system.prop`) | KernelSU, Magisk | Instalación con el método de módulo |
