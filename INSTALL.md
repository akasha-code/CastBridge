# Llevar CastBridge a otra PC

**Una producción de MateKraft.**

El ZIP incluye un asistente de instalación con comprobación previa de dependencias externas. No es un MSI ni un ejecutable firmado. La compatibilidad real se verificó sólo en el equipo de desarrollo con Windows 11 x64. Requiere permisos de administrador para activar el monitor.

1. Extraé todo el ZIP en una carpeta local con permiso de escritura. No copies la `.venv` de otra PC.
2. Instalá Python 3.12 x64 con el lanzador `py` y FFmpeg. Podés colocar `ffmpeg.exe` en una subcarpeta `bin` del paquete o tenerlo en PATH. No se redistribuyen esas herramientas en el ZIP.
3. Descargá el paquete de controlador firmado Virtual Display Driver 25.7.23 desde su [release oficial](https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/tag/25.7.23). Comprobá las firmas CAT/DLL: deben ser válidas. Para esta aplicación se agrega el INF al Driver Store con `pnputil /add-driver "RUTA_AL_PAQUETE\MttVDD.inf"` en PowerShell elevado, **sin `/install` y sin crear un dispositivo ROOT adicional**. El coordinador crea su propio dispositivo temporal. Si ya instalaste un monitor persistente del mismo driver, la aplicación lo rechazará: revisá esa instalación antes de seguir. No uses los scripts históricos del proyecto ni desactives protecciones para aceptar un paquete inválido.
4. Copiá la plantilla `driver\vdd_settings.xml` del ZIP a `C:\VirtualDisplayDriver\vdd_settings.xml`, creando esa carpeta en PowerShell elevado si no existe. No sobrescribas una configuración ajena: conservá una copia y revisala primero. La plantilla configura un monitor de 1280×720 a 60 Hz y cursor por software. La existencia del XML no demuestra que el driver esté instalado correctamente.
5. Abrí `Install-CastBridge.cmd`. Primero verifica todos los requisitos y bloquea Instalar si falta alguno; seleccioná una fila para obtener ayuda y enlaces. Una vez resueltos, pulsá Comprobar e Instalar. Como alternativa de consola, ejecutá `powershell -NoProfile -File .\scripts\Setup-Local.ps1`; `-CheckOnly` comprueba sin instalar. Crea la `.venv` local e instala las dependencias Python fijadas. Necesita Internet para descargar paquetes; no modifica firewall ni instala el driver.
6. Abrí `CastBridge.lnk` (creado localmente con el icono propio) o `CastBridge.cmd`, aceptá la elevación de Windows y elegí el Chromecast. Ambas máquinas deben estar en la misma LAN. La red y el firewall deben permitir descubrimiento y acceso al flujo; la aplicación no abre reglas automáticamente. El atajo contiene rutas de esa PC: si movés la carpeta, volvé a ejecutar `scripts/New-Shortcut.ps1`.

El helper x64 ya está compilado en el ZIP; no necesitás GCC para usarlo. No se incluyen preferencias, posiciones de monitores, logs, direcciones de dispositivos ni grabaciones del equipo de desarrollo. La PC nueva genera sus propias preferencias y ubicación.

Probá conectar y desconectar antes de usar contenido importante. Este paquete no fue validado todavía en una segunda PC. Conserva los límites del prototipo: latencia variable, HTTP sin cifrado y pruebas pendientes de suspensión/cortes de red.

Para retirar la aplicación: desconectá, salí desde la bandeja y eliminá su carpeta. Python, FFmpeg y el driver se desinstalan por separado con sus procedimientos oficiales; borrar la carpeta no los desinstala. No reutilices un número `oemXX.inf` de otra PC.

Si Windows bloquea scripts descargados, revisá el origen y el contenido del paquete antes de usar la opción Desbloquear en sus propiedades. El asistente no cambia la política de ejecución ni desactiva protecciones. La instalación descarga dependencias: una interrupción puede dejar un entorno parcial; no anuncia éxito ni crea el atajo hasta que pip check termina correctamente. Podés corregir el problema y repetir el asistente.
