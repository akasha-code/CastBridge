# CastAggregator

Aplicacion experimental para usar un Chromecast como pantalla extendida temporal en Windows 11 x64. Crea un monitor de 1280 x 720, transmite su contenido y recupera la configuracion fisica al desconectar normalmente.

## Descargar e instalar

Descarga el ZIP de una release de este repositorio, extraelo completo en una carpeta local con permiso de escritura y abri `Install-CastAggregator.cmd`. El asistente comprueba los requisitos antes de crear el entorno Python o instalar dependencias. Si falta algo, bloquea Instalar y muestra instrucciones y enlaces de descarga.

Lee [INSTALL.md](INSTALL.md) para preparar el driver y conocer las limitaciones. El paquete requiere Python 3.12 x64, FFmpeg con gdigrab/libx264/HLS y Virtual Display Driver compatible, firmado y preparado por separado. No cambia el firewall, certificados ni politicas de Windows.

## Uso

Abri `CastAggregator.lnk` o `CastAggregator.cmd` y acepta la elevacion de Windows para activar el dispositivo temporal. Desde la bandeja elegi el Chromecast, conecta y mueve tus ventanas al monitor virtual. Desconecta y espera la limpieza antes de salir.

La seleccion, el nombre y la posicion del monitor se recuerdan localmente por dispositivo. Los perfiles de latencia son Estable, Reducido y Minimo (experimental). Actualizar al vivo permite repetir la sincronizacion. Las pruebas manuales obtuvieron aproximadamente 2,8 a 3,8 segundos en algunas sesiones; no es una garantia para otra red o dispositivo.

## Desarrollo y paquete

Las dependencias estan fijadas en `requirements-prototype.lock.txt`. Para desarrollar usa Python 3.12 x64 en un entorno virtual. El helper requiere GCC x64 al compilar; el ZIP incluye su DLL.

```powershell
.\scripts\Build-NativeHelper.ps1
.\scripts\Setup-Local.ps1 -CheckOnly
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
.\scripts\Build-Portable.ps1
```

El paquete excluye preferencias, posiciones de monitores, logs, entornos virtuales y datos del equipo de desarrollo. Los informes historicos locales no forman parte del repositorio distribuido.

## Limites actuales

Probado en el equipo de desarrollo con Windows 11 x64; falta validar una instalacion limpia en otra PC. Es un instalador basado en ZIP y PowerShell, no un MSI o ejecutable firmado. La conectividad del Chromecast se verifica al usar la aplicacion, no durante la instalacion. Ambas maquinas deben estar en la misma LAN.

El transporte usa HTTP local con token y restriccion al receptor seleccionado; el video permanece en memoria. Todavia hay pruebas pendientes de suspension, cortes de red y cierre forzado. Desconecta y sali normalmente antes de retirar la carpeta. Los requisitos externos se desinstalan por separado.
