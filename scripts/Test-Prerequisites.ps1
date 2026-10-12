param([string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$checks=[Collections.Generic.List[object]]::new()
function Add-Check($Name,$Ready,$Help,$Url='') {
    $checks.Add([pscustomobject]@{Name=$Name;Ready=[bool]$Ready;Help=$Help;Url=$Url})
}
Add-Check 'Windows 11 x64' ([Environment]::Is64BitOperatingSystem -and [Environment]::OSVersion.Version.Build -ge 22000) 'La plataforma probada es Windows 11 de 64 bits.'
$pythonOk=$false
$launcher=Get-Command py.exe -ErrorAction SilentlyContinue
if ($launcher) {
    try {
        & $launcher.Source -3.12 -c "import struct,sys; sys.exit(0 if struct.calcsize('P') == 8 else 1)" 2>$null | Out-Null
        $pythonOk=$LASTEXITCODE -eq 0
    } catch { $pythonOk=$false }
}
Add-Check 'Python 3.12 x64 y lanzador py' $pythonOk 'Instala Python 3.12 de 64 bits incluyendo el lanzador py; despues reabre el asistente.' 'https://www.python.org/downloads/windows/'
$ffmpeg=Join-Path $Root 'bin\ffmpeg.exe'
if (-not (Test-Path -LiteralPath $ffmpeg)) {
    $command=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    $ffmpeg=if ($command) {$command.Source} else {$null}
}
$ffmpegOk=$false
if ($ffmpeg) {
    $devices=(& $ffmpeg -hide_banner -devices 2>&1 | Out-String); $devicesExit=$LASTEXITCODE
    $encoders=(& $ffmpeg -hide_banner -encoders 2>&1 | Out-String); $encodersExit=$LASTEXITCODE
    $formats=(& $ffmpeg -hide_banner -formats 2>&1 | Out-String); $formatsExit=$LASTEXITCODE
    $ffmpegOk=$devicesExit -eq 0 -and $encodersExit -eq 0 -and $formatsExit -eq 0 -and $devices -match '\bgdigrab\b' -and $encoders -match '\blibx264\b' -and $formats -match '\bhls\b'
}
Add-Check 'FFmpeg con gdigrab, libx264 y HLS' $ffmpegOk 'Descarga una compilacion Windows con esas funciones. Agrega ffmpeg.exe al PATH o a bin dentro de esta carpeta.' 'https://ffmpeg.org/download.html'
$driverOk=$false
$store=Join-Path $env:SystemRoot 'System32\DriverStore\FileRepository'
foreach ($directory in @(Get-ChildItem -LiteralPath $store -Directory -Filter 'mttvdd.inf_amd64_*' -ErrorAction SilentlyContinue)) {
    $inf=Join-Path $directory.FullName 'MttVDD.inf'
    $catalog=Join-Path $directory.FullName 'MttVDD.cat'
    $dll=Join-Path $directory.FullName 'MttVDD.dll'
    if ((Test-Path $inf) -and (Test-Path $catalog) -and (Test-Path $dll)) {
        $contents=Get-Content -LiteralPath $inf -Raw
        if ($contents -match '11\.30\.4\.434' -and $contents -match 'Standard\.NTamd64' -and $contents -match 'Root\\MttVDD' -and
            (Get-AuthenticodeSignature -LiteralPath $catalog).Status -eq 'Valid' -and
            (Get-AuthenticodeSignature -LiteralPath $dll).Status -eq 'Valid') { $driverOk=$true }
    }
}
Add-Check 'Virtual Display Driver compatible y firmado en Driver Store' $driverOk 'Descarga 25.7.23. Verifica firmas validas y agrega MttVDD.inf con pnputil /add-driver en PowerShell administrador, sin /install. Lee INSTALL.md.' 'https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/tag/25.7.23'
$configOk=$false
try {
    [xml]$config=Get-Content -LiteralPath 'C:\VirtualDisplayDriver\vdd_settings.xml' -Raw
    $resolutions=@($config.vdd_settings.resolutions.resolution)
    $configOk=[string]$config.vdd_settings.monitors.count -eq '1' -and $resolutions.Count -eq 1 -and
        [string]$resolutions[0].width -eq '1280' -and [string]$resolutions[0].height -eq '720' -and
        [string]$resolutions[0].refresh_rate -eq '60' -and [string]$config.vdd_settings.options.HardwareCursor -eq 'false'
} catch { $configOk=$false }
Add-Check 'Configuracion del monitor 1280 x 720, 60 Hz' $configOk 'Copia driver\vdd_settings.xml a C:\VirtualDisplayDriver\vdd_settings.xml con permisos de administrador. No sobrescribas configuraciones ajenas; revisa INSTALL.md.'
Add-Check 'Helper nativo incluido' (Test-Path -LiteralPath (Join-Path $Root 'artifacts\castaggregator-device.dll')) 'Usa el ZIP de distribucion completo. Desde el codigo fuente, compila con scripts\Build-NativeHelper.ps1.'
Add-Check 'Lista de dependencias incluida' (Test-Path -LiteralPath (Join-Path $Root 'requirements-prototype.lock.txt')) 'Extrae el ZIP completo antes de instalar.'
$networkOk=$false
try {
    $index=Invoke-WebRequest -Uri 'https://pypi.org/simple/pychromecast/' -Method Head -UseBasicParsing -TimeoutSec 8
    $package=Invoke-RestMethod -Uri 'https://pypi.org/pypi/PyChromecast/14.0.10/json' -TimeoutSec 8
    $downloadUri=[uri]$package.urls[0].url
    if ($downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ne 'files.pythonhosted.org') { throw 'Unexpected package download host.' }
    $files=Invoke-WebRequest -Uri $downloadUri.AbsoluteUri -Method Head -UseBasicParsing -TimeoutSec 8
    $networkOk=$index.StatusCode -eq 200 -and $files.StatusCode -eq 200
} catch { $networkOk=$false }
Add-Check 'Acceso HTTPS a las descargas de Python' $networkOk 'Necesitas Internet y acceso a pypi.org y files.pythonhosted.org. Revisa conexion y proxy; el asistente no cambia esas opciones. La descarga concreta aun puede fallar y se informara sin anunciar instalacion completa.'
[pscustomobject]@{Ready=(@($checks | Where-Object {-not $_.Ready}).Count -eq 0); Checks=$checks.ToArray()}
