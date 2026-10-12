<div align="center">

[English](README.md) · **Español** · [Norsk](README.no.md)

![CastBridge — Una producción de MateKraft](assets/castbridge-banner.svg)

# CastBridge

### Más espacio para el trabajo que importa.

Extendé tu escritorio de Windows a un Chromecast.<br />
**Una producción de [MateKraft](https://matekraft.tech).**

[Descargar versión preliminar](https://github.com/akasha-code/CastBridge/releases) · [Guía de instalación en inglés](INSTALL.md) · [Informar un problema](https://github.com/akasha-code/CastBridge/issues)

</div>

## Qué hace

CastBridge crea un monitor temporal de 1280 × 720 y transmite ese escritorio al Chromecast que elijas mediante la red local. Mové una ventana a la pantalla adicional y controlala con el mouse y el teclado de tu PC. Al desconectar normalmente, se retira el monitor temporal y se restaura la configuración de las pantallas físicas.

- Elegí el receptor y el nombre que aparece en la TV.
- Conservá la posición del monitor virtual para cada receptor.
- Elegí español, inglés o noruego bokmål; el idioma queda guardado.
- Usá los perfiles de latencia Estable, Reducido o Mínimo experimental.
- Encontrá la versión, el proyecto y el sitio de MateKraft en **Acerca de CastBridge**.

## Instalación

1. Descargá **CastBridge-Setup.exe** desde la última versión preliminar.
2. Abrilo, elegí el idioma y revisá los requisitos.
3. Seleccioná cada requisito faltante para ver instrucciones y su enlace oficial. Prepará las herramientas externas y volvé a comprobar.
4. Cuando se cumplan todos los requisitos, instalá y abrí **CastBridge** desde Inicio.

El instalador y la interfaz son ejecutables compilados de Windows. El paquete instalado no contiene scripts de PowerShell. Usa el motor de transmisión existente en Python y un helper nativo para el monitor temporal.

Necesitás **Windows 11 x64**, **Python 3.12 x64 con lanzador py**, **FFmpeg con gdigrab, libx264 y HLS**, **Virtual Display Driver 25.7.23** compatible y firmado, agregado al Driver Store, la configuración del monitor y acceso HTTPS para descargar dependencias Python. Todo se comprueba antes de copiar archivos de la aplicación. Las herramientas externas se preparan por separado; el asistente explica cómo hacerlo.

**Versión preliminar:** los ejecutables todavía no tienen firma digital. Un archivo compilado no reemplaza la verificación del editor. Las descargas siguen privadas durante la validación y requieren acceso a GitHub.

## Uso

Elegí el receptor y conectá. Windows solicita permisos de administrador para activar el monitor temporal. Mové las ventanas a la pantalla adicional como en cualquier escritorio extendido. Cerrar la ventana mantiene CastBridge disponible en la bandeja.

Cambiá el perfil de latencia estando desconectado. **Actualizar al vivo** repite la sincronización durante una sesión. Usá **Desconectar** y esperá la limpieza antes de salir.

## Límites actuales

Es una extensión de escritorio experimental. Varias pruebas manuales mostraron unos 2,8–3,8 segundos de retraso; el resultado depende del receptor y la red. Quedan pendientes una instalación limpia en otra PC y las pruebas de suspensión y recuperación ante cortes de red.

El video permanece en memoria y se sirve mediante HTTP local con token y restricción al receptor elegido. El transporte no está cifrado. CastBridge no cambia automáticamente firewall, certificados, PATH ni políticas de seguridad. La conectividad del receptor se comprueba al conectar, no durante la instalación.

Desinstalá desde **Aplicaciones instaladas** de Windows. Las herramientas externas, preferencias y registros se conservan. No cierres la aplicación por la fuerza durante una sesión.

## Desarrollo y verificación

La interfaz C# usa .NET Framework disponible en Windows 11 compatible. El proceso de compilación usa el compilador C# de Windows y GCC x64 para el helper nativo.

```powershell
.\scripts\Build-NativeHelper.ps1
.\scripts\Build-Icon.ps1
.\scripts\Build-Portable.ps1
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Los scripts de desarrollo usan PowerShell; los ejecutables distribuidos no lo invocan. La interfaz y el instalador están en `native/`, el motor en `prototype/` y las traducciones en `assets/languages.json`. Los identificadores internos se conservan para mantener compatibilidad con las preferencias existentes.

## Empecemos con una conversación que tenga sentido

Las herramientas útiles nacen de un problema real. Si CastBridge te ayuda o tenés una idea concreta para mejorarlo, conversemos.

Un mensaje corto alcanza. Seguimos desde ahí.

[Iniciar la conversación](https://tally.so/r/J929pK) · [Visitar MateKraft](https://matekraft.tech) · [Abrir un issue](https://github.com/akasha-code/CastBridge/issues)

[![Apoyar a MateKraft — Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-MateKraft-D4AF37?style=for-the-badge&logo=buymeacoffee&logoColor=0a1412)](https://www.buymeacoffee.com/matekraft)

El apoyo es opcional y no cambia las funciones de la aplicación.
